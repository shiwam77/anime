import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:admob_flutter/admob_flutter.dart';
import 'package:anime/utils/routes.dart';
import 'package:anime/utils/utils.dart';
import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_facebook_keyhash/flutter_facebook_keyhash.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../bindings/managers_binding.dart';
import '../services/request_service.dart';
import '../theme/tako_theme.dart';
import '../utils/anime_route.dart';

void main() {
  mainDelegate();
}

void mainDelegate() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await FlutterDownloader.initialize(
      debug:
          true, // optional: set to false to disable printing logs to console (default: true)
      ignoreSsl:
          true // option: set to false to disable working with http links (default: false)
      );
  Admob.initialize();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  /// register global error handler
  FlutterError.onError = (FlutterErrorDetails details) async {
    if (kDebugMode) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // FirebaseCrashlytics.instance.recordFlutterError;
      Zone.current
          .handleUncaughtError(details.exception, details.stack as StackTrace);
    }
  };

  /// errors that happen outside of the Flutter context, install an error listener on the current Isolate
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final List<dynamic> errorAndStacktrace = pair;
    await FirebaseCrashlytics.instance.recordError(
      errorAndStacktrace.first,
      errorAndStacktrace.last,
    );
  }).sendPort);
  bool isSignedUser = false;

  getUUID().then((value) {
    if (value == null) {
      isSignedUser = false;
    } else {
      isSignedUser = true;
    }
  });

  runZonedGuarded<Future<void>>(() async {
    runApp(MyApp(
      isSignIn: isSignedUser,
    ));
    // runApp(MyMaterialApp());
  }, (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });

  _setUpLogging();
}

Future<String?> getUUID() async {
  return readPrefsString("uuid");
}

void _setUpLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((rec) {
    // ignore: avoid_print
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

class MyApp extends StatelessWidget {
  final bool? isSignIn;
  const MyApp({Key? key, this.isSignIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          Provider(
            create: (_) => RequestService.create(),
            dispose: (_, RequestService service) => service.client.dispose(),
          ),
        ],
        child: !isSignIn!
            ? StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.active) {
                    User? user = snapshot.data;
                    if (user == null) {
                      _signInAnonymously().then((value) {
                        setPrefsString("uuid", value?.user?.uid as String);
                        return GetMaterialApp(
                          debugShowCheckedModeBanner: false,
                          title: 'TakoPlay',
                          theme: TakoTheme.dark(),
                          initialRoute: Routes.mainScreen,
                          initialBinding: ManagerBinding(),
                          getPages: AnimeRoute.pages,
                        );
                      });
                      return const MaterialApp(
                        home: Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }
                    return GetMaterialApp(
                      debugShowCheckedModeBanner: false,
                      title: 'TakoPlay',
                      theme: TakoTheme.dark(),
                      initialRoute: Routes.mainScreen,
                      initialBinding: ManagerBinding(),
                      getPages: AnimeRoute.pages,
                    );
                  } else {
                    return const MaterialApp(
                      home: Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }
                })
            : GetMaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'TakoPlay',
                theme: TakoTheme.dark(),
                initialRoute: Routes.mainScreen,
                initialBinding: ManagerBinding(),
                getPages: AnimeRoute.pages,
              ));
  }

  Future<UserCredential?> _signInAnonymously() async {
    try {
      return await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      return null; // TODO: show dialog with error
    }
  }
}

class AdsPage extends StatefulWidget {
  final String idfa;

  const AdsPage({Key? key, this.idfa = ''}) : super(key: key);

  @override
  AdsPageState createState() => AdsPageState();
}

class AdsPageState extends State<AdsPage> {
  bool _isInterstitialAdLoaded = false;
  bool _isRewardedAdLoaded = false;

  /// All widget ads are stored in this variable. When a button is pressed, its
  /// respective ad widget is set to this variable and the view is rebuilt using
  /// setState().
  Widget _currentAd = SizedBox(
    width: 0.0,
    height: 0.0,
  );

  @override
  void initState() {
    super.initState();

    /// please add your own device testingId
    /// (testingId will print in console if you don't provide  )
    FacebookAudienceNetwork.init(
      testingId: "b741b125-5a37-46b8-aef8-f27170837ce9",
      iOSAdvertiserTrackingEnabled: true,
    );
    _showNativeBannerAd();
    printKeyHash();
  }

  void printKeyHash() async {
    String? key = await FlutterFacebookKeyhash.getFaceBookKeyHash ??
        'Unknown platform version';
    print(" key $key" ?? "");
  }

  void _loadInterstitialAd() {
    FacebookInterstitialAd.loadInterstitialAd(
      // placementId: "YOUR_PLACEMENT_ID",
      placementId: "IMG_16_9_APP_INSTALL#2312433698835503_2650502525028617",
      listener: (result, value) {
        print(">> FAN > Interstitial Ad: $result --> $value");
        if (result == InterstitialAdResult.LOADED)
          _isInterstitialAdLoaded = true;

        /// Once an Interstitial Ad has been dismissed and becomes invalidated,
        /// load a fresh Ad by calling this function.
        if (result == InterstitialAdResult.DISMISSED &&
            value["invalidated"] == true) {
          _isInterstitialAdLoaded = false;
          _loadInterstitialAd();
        }
      },
    );
  }

  void _loadRewardedVideoAd() {
    FacebookRewardedVideoAd.loadRewardedVideoAd(
      placementId: "YOUR_PLACEMENT_ID",
      listener: (result, value) {
        print("Rewarded Ad: $result --> $value");
        if (result == RewardedVideoAdResult.LOADED) _isRewardedAdLoaded = true;
        if (result == RewardedVideoAdResult.VIDEO_COMPLETE)

        /// Once a Rewarded Ad has been closed and becomes invalidated,
        /// load a fresh Ad by calling this function.
        if (result == RewardedVideoAdResult.VIDEO_CLOSED &&
            (value == true || value["invalidated"] == true)) {
          _isRewardedAdLoaded = false;
          _loadRewardedVideoAd();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Align(
            alignment: Alignment(0, 1),
            child: _currentAd,
          ),
          fit: FlexFit.tight,
          flex: 2,
        ),
      ],
    );
  }

  Widget _getAllButtons() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 3,
      children: <Widget>[
        _getRaisedButton(title: "Banner Ad", onPressed: _showBannerAd),
        _getRaisedButton(title: "Native Ad", onPressed: _showNativeAd),
        _getRaisedButton(
            title: "Native Banner Ad", onPressed: _showNativeBannerAd),
        _getRaisedButton(
            title: "Intestitial Ad", onPressed: _showInterstitialAd),
        _getRaisedButton(title: "Rewarded Ad", onPressed: _showRewardedAd),
      ],
    );
  }

  Widget _getRaisedButton({required String title, void Function()? onPressed}) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          title,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  _showInterstitialAd() {
    if (_isInterstitialAdLoaded == true)
      FacebookInterstitialAd.showInterstitialAd();
    else
      print("Interstial Ad not yet loaded!");
  }

  _showRewardedAd() {
    if (_isRewardedAdLoaded == true)
      FacebookRewardedVideoAd.showRewardedVideoAd();
    else
      print("Rewarded Ad not yet loaded!");
  }

  _showBannerAd() {
    setState(() {
      _currentAd = FacebookBannerAd(
        placementId:
            "IMG_16_9_APP_INSTALL#2312433698835503_2964944860251047", //testid
        bannerSize: BannerSize.STANDARD,
        listener: (result, value) {
          print("Banner Ad: $result -->  $value");
        },
      );
    });
  }

  _showNativeBannerAd() {
    setState(() {
      _currentAd = _nativeBannerAd();
    });
  }

  Widget _nativeBannerAd() {
    return FacebookNativeAd(
      // placementId: "YOUR_PLACEMENT_ID",
      placementId: "IMG_16_9_APP_INSTALL#2312433698835503_2964953543583512",
      adType: NativeAdType.NATIVE_BANNER_AD,
      bannerAdSize: NativeBannerAdSize.HEIGHT_100,
      width: double.infinity,
      backgroundColor: Colors.blue,
      titleColor: Colors.white,
      descriptionColor: Colors.white,
      buttonColor: Colors.deepPurple,
      buttonTitleColor: Colors.white,
      buttonBorderColor: Colors.white,
      listener: (result, value) {
        print("Native Banner Ad: $result --> $value");
      },
    );
  }

  _showNativeAd() {
    setState(() {
      _currentAd = _nativeAd();
    });
  }

  Widget _nativeAd() {
    return FacebookNativeAd(
      placementId: "IMG_16_9_APP_INSTALL#2312433698835503_2964952163583650",
      adType: NativeAdType.NATIVE_AD_VERTICAL,
      width: double.infinity,
      height: 300,
      backgroundColor: Colors.blue,
      titleColor: Colors.white,
      descriptionColor: Colors.white,
      buttonColor: Colors.deepPurple,
      buttonTitleColor: Colors.white,
      buttonBorderColor: Colors.white,
      listener: (result, value) {
        print("Native Ad: $result --> $value");
      },
      keepExpandedWhileLoading: true,
      expandAnimationDuraion: 1000,
    );
  }
}

class MyMaterialApp extends StatefulWidget {
  @override
  _MyMaterialAppState createState() => _MyMaterialAppState();
}

class _MyMaterialAppState extends State<MyMaterialApp> {
  GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
  AdmobBannerSize? bannerSize;
  late AdmobInterstitial interstitialAd;
  late AdmobReward rewardAd;

  @override
  void initState() {
    super.initState();

    // You should execute `Admob.requestTrackingAuthorization()` here before showing any ad.

    bannerSize = AdmobBannerSize.BANNER;

    interstitialAd = AdmobInterstitial(
      adUnitId: getInterstitialAdUnitId()!,
      listener: (AdmobAdEvent event, Map<String, dynamic>? args) {
        if (event == AdmobAdEvent.closed) interstitialAd.load();
        handleEvent(event, args, 'Interstitial');
      },
    );

    rewardAd = AdmobReward(
      adUnitId: getRewardBasedVideoAdUnitId()!,
      listener: (AdmobAdEvent event, Map<String, dynamic>? args) {
        if (event == AdmobAdEvent.closed) rewardAd.load();
        handleEvent(event, args, 'Reward');
      },
    );

    interstitialAd.load();
    rewardAd.load();
  }

  void handleEvent(
      AdmobAdEvent event, Map<String, dynamic>? args, String adType) {
    switch (event) {
      case AdmobAdEvent.loaded:
        showSnackBar('New Admob $adType Ad loaded!');
        break;
      case AdmobAdEvent.opened:
        showSnackBar('Admob $adType Ad opened!');
        break;
      case AdmobAdEvent.closed:
        showSnackBar('Admob $adType Ad closed!');
        break;
      case AdmobAdEvent.failedToLoad:
        showSnackBar('Admob $adType failed to load. :(');
        break;
      case AdmobAdEvent.rewarded:
        showDialog(
          context: scaffoldState.currentContext!,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                return true;
              },
              child: AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Reward callback fired. Thanks Andrew!'),
                    Text('Type: ${args!['type']}'),
                    Text('Amount: ${args['amount']}'),
                  ],
                ),
              ),
            );
          },
        );
        break;
      default:
    }
  }

  void showSnackBar(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          key: scaffoldState,
          appBar: AppBar(
            title: const Text('AdmobFlutter'),
            actions: [
              TextButton(
                onPressed: () {},
                child: Text(
                  'FullscreenDialog',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              )
            ],
          ), // .withBottomAdmobBanner(context),
          bottomNavigationBar: Builder(
            builder: (BuildContext context) {
              return Container(
                color: Colors.blueGrey,
                child: SafeArea(
                  child: SizedBox(
                    height: 60,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final isLoaded = await interstitialAd.isLoaded;
                              if (isLoaded ?? false) {
                                interstitialAd.show();
                              } else {
                                showSnackBar(
                                    'Interstitial ad is still loading...');
                              }
                            },
                            child: Text(
                              'Show Interstitial',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              if (await rewardAd.isLoaded) {
                                rewardAd.show();
                              } else {
                                showSnackBar('Reward ad is still loading...');
                              }
                            },
                            child: Text(
                              'Show Reward',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PopupMenuButton(
                            initialValue: bannerSize,
                            offset: Offset(0, 20),
                            onSelected: (AdmobBannerSize newSize) {
                              setState(() {
                                bannerSize = newSize;
                              });
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<AdmobBannerSize>>[
                              PopupMenuItem(
                                value: AdmobBannerSize.BANNER,
                                child: Text('BANNER'),
                              ),
                              PopupMenuItem(
                                value: AdmobBannerSize.LARGE_BANNER,
                                child: Text('LARGE_BANNER'),
                              ),
                              PopupMenuItem(
                                value: AdmobBannerSize.MEDIUM_RECTANGLE,
                                child: Text('MEDIUM_RECTANGLE'),
                              ),
                              PopupMenuItem(
                                value: AdmobBannerSize.FULL_BANNER,
                                child: Text('FULL_BANNER'),
                              ),
                              PopupMenuItem(
                                value: AdmobBannerSize.LEADERBOARD,
                                child: Text('LEADERBOARD'),
                              ),
                              PopupMenuItem(
                                value: AdmobBannerSize.SMART_BANNER(context),
                                child: Text('SMART_BANNER'),
                              ),
                              PopupMenuItem(
                                value: AdmobBannerSize.ADAPTIVE_BANNER(
                                  width: MediaQuery.of(context)
                                          .size
                                          .width
                                          .toInt() -
                                      40, // considering EdgeInsets.all(20.0)
                                ),
                                child: Text('ADAPTIVE_BANNER'),
                              ),
                            ],
                            child: Center(
                              child: Text(
                                'Banner size',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () {},
                            child: Text(
                              'Push Page',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          body: Column(
            children: [
              Expanded(
                child: Scrollbar(
                  child: ListView.builder(
                    padding: EdgeInsets.all(20.0),
                    itemCount: 1000,
                    itemBuilder: (BuildContext context, int index) {
                      if (index != 0 && index % 6 == 0) {
                        return Column(
                          children: <Widget>[
                            Container(
                              margin: EdgeInsets.only(bottom: 20.0),
                              child: AdmobBanner(
                                adUnitId: getBannerAdUnitId()!,
                                adSize: bannerSize!,
                                listener: (AdmobAdEvent event,
                                    Map<String, dynamic>? args) {
                                  handleEvent(event, args, 'Banner');
                                },
                                onBannerCreated:
                                    (AdmobBannerController controller) {
                                  // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
                                  // Normally you don't need to worry about disposing this yourself, it's handled.
                                  // If you need direct access to dispose, this is your guy!
                                  // controller.dispose();
                                },
                              ),
                            ),
                            Container(
                              height: 100.0,
                              margin: EdgeInsets.only(bottom: 20.0),
                              color: Colors.cyan,
                            ),
                          ],
                        );
                      }
                      return Container(
                        height: 100.0,
                        margin: EdgeInsets.only(bottom: 20.0),
                        color: Colors.cyan,
                      );
                    },
                  ),
                ),
              ),
              // Another option is to fix a banner ad to the top or bottom of your content.
              // Notice that banners are not scrolling, which is a violation of admob policy.
              //
              // See: https://github.com/kmcgill88/admob_flutter/issues/194
              // "banner ads should not move as a user scrolls, as users may try to
              // click on the menu but end up clicking on the ad accidentally instead.
              // This specific implementation is against policy and we reserve the right
              // to disable ad serving to your app."

              // Builder(
              //   builder: (BuildContext context) {
              //     final size = MediaQuery.of(context).size;
              //     final height = max(size.height * .05, 50.0);
              //     return Container(
              //       width: size.width,
              //       height: height,
              //       child: AdmobBanner(
              //         adUnitId: getBannerAdUnitId(),
              //         adSize: AdmobBannerSize.ADAPTIVE_BANNER(
              //           width: size.width.toInt(),
              //         ),
              //         listener: (AdmobAdEvent event, Map<String, dynamic> args) {
              //           handleEvent(event, args, 'Banner');
              //         },
              //       ),
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ),
    );
    // .withBottomAdmobBanner(context);
  }

  @override
  void dispose() {
    interstitialAd.dispose();
    rewardAd.dispose();
    super.dispose();
  }
}

/*
Test Id's from:
https://developers.google.com/admob/ios/banner
https://developers.google.com/admob/android/banner

App Id - See README where these Id's go
Android: ca-app-pub-3940256099942544~3347511713
iOS: ca-app-pub-3940256099942544~1458002511

Banner
Android: ca-app-pub-3940256099942544/6300978111
iOS: ca-app-pub-3940256099942544/2934735716

Interstitial
Android: ca-app-pub-3940256099942544/1033173712
iOS: ca-app-pub-3940256099942544/4411468910

Reward Video
Android: ca-app-pub-3940256099942544/5224354917
iOS: ca-app-pub-3940256099942544/1712485313
*/

String? getBannerAdUnitId() {
  if (Platform.isIOS) {
    return 'ca-app-pub-3940256099942544/2934735716';
  } else if (Platform.isAndroid) {
    return 'ca-app-pub-3940256099942544/6300978111';
  }
  return null;
}

String? getInterstitialAdUnitId() {
  if (Platform.isIOS) {
    return 'ca-app-pub-3940256099942544/4411468910';
  } else if (Platform.isAndroid) {
    return 'ca-app-pub-3940256099942544/1033173712';
  }
  return null;
}

String? getRewardBasedVideoAdUnitId() {
  if (Platform.isIOS) {
    return 'ca-app-pub-3940256099942544/1712485313';
  } else if (Platform.isAndroid) {
    return 'ca-app-pub-3940256099942544/5224354917';
  }
  return null;
}
