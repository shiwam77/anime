import 'dart:async';
import 'dart:isolate';

import 'package:anime/utils/routes.dart';
import 'package:anime/utils/utils.dart';
import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_keyhash/flutter_facebook_keyhash.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../bindings/managers_binding.dart';
import '../services/request_service.dart';
import '../theme/tako_theme.dart';
import '../utils/anime_route.dart';
void main()  {
  mainDelegate();
}

void mainDelegate() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FacebookAudienceNetwork.init(
    testingId: "b741b125-5a37-46b8-aef8-f27170837ce9",
    iOSAdvertiserTrackingEnabled: true,
  );
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
      Zone.current.handleUncaughtError(details.exception, details.stack as StackTrace);
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
    if(value == null){
      isSignedUser = false;
    }else{
      isSignedUser = true;
    }
  });

  runZonedGuarded<Future<void>>(() async {

    runApp( MyApp(isSignIn: isSignedUser,));
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
      child: !isSignIn! ? StreamBuilder<User? >(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              User? user = snapshot.data;
              if (user == null) {
                _signInAnonymously().then((value) {
                  setPrefsString("uuid",value?.user?.uid as String);
                  return GetMaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'TakoPlay',
                    theme: TakoTheme.dark(),
                    initialRoute:Routes.mainScreen ,
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
                initialRoute:Routes.mainScreen ,
                initialBinding: ManagerBinding(),
                getPages: AnimeRoute.pages,
              );
            }else{
              return const MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
          }
      ) : GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TakoPlay',
        theme: TakoTheme.dark(),
        initialRoute:Routes.mainScreen ,
        initialBinding: ManagerBinding(),
        getPages: AnimeRoute.pages,
      )
    );

      
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

  void printKeyHash() async{

    String? key = await FlutterFacebookKeyhash.getFaceBookKeyHash ??
        'Unknown platform version';
    print( " key $key"??"");

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