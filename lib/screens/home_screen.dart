import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info/package_info.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/network_manager.dart';
import '../models/anime.dart';
import '../services/anime_service.dart';
import '../services/request_service.dart';
import '../theme/tako_theme.dart';
import '../utils/constants.dart';
import '../widgets/anime_animation.dart';
import '../widgets/movie_card.dart';
import '../widgets/popular_anime_card.dart';
import '../widgets/recently_added_anime_card.dart';
import '../widgets/website_error_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final networkManager = Get.find<NetworkManager>();
  late AnimationController animationController;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    animationController = AnimationController(
        duration: Duration(milliseconds: takoAnimationDuration), vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      versionCheck(context);
    });
  }

  versionCheck(context) async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    String getVersion =
        "${info.version.trim().replaceAll(".", "")}${info.buildNumber.trim().replaceAll(".", "")}";
    double currentVersion = double.parse(getVersion);
    final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

    try {
      // Using default duration to force fetching from remote server.
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      await remoteConfig.fetchAndActivate();

      String getUpdatedVersion =
          remoteConfig.getString('force_update_current_version');
      print(getUpdatedVersion);

      double newVersion = double.parse(
          getUpdatedVersion.trim().replaceAll(".", "").replaceAll("+", ""));

      if (newVersion > currentVersion) {
        showVersionDialog(context);
      }
    } on PlatformException catch (exception) {
      // Fetch throttled.
      print(exception);
    } catch (exception) {
      print(
          'Unable to fetch remote config. Cached or default values will be used');
    }
  }

  showVersionDialog(context) async {
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String title = "New Update Available";
        String message =
            "There is a newer version of app available please update it now.";
        String btnLabel = "Update Now";
        String btnLabelCancel = "Later";
        return WillPopScope(
          onWillPop: () async {
            return false;
          },
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                child: Text(btnLabel),
                onPressed: () {
                  launchUrl(
                      Uri.parse("https://github.com/shiwam77/anime/releases"),
                      mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestService = Provider.of<RequestService>(context, listen: false);
    // final itemHeight = (screenHeight * .26).h;
    // final itemWidth = (screenWidth / 2).w;
    return GetBuilder<NetworkManager>(
        builder: (_) => FutureBuilder<List<AnimeResults>>(
            future: Future.wait([
              AnimeService().getAnimes(requestService.requestPopularResponse()),
              AnimeService().getRecentlyAddedAnimes(),
              AnimeService().getAnimes(requestService.requestMoviesResponse()),
            ]),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const WebsiteErrorWidget();
              }

              if (snapshot.connectionState == ConnectionState.done) {
                final popularList = snapshot.data![0].animeList;
                final recentlyAdded = snapshot.data![1].animeList;
                final movieList = snapshot.data![2].animeList;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        child: Text(
                          'Popular',
                          style: TakoTheme.darkTextTheme.headline4!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          scrollDirection: Axis.horizontal,
                          itemCount: popularList!.length,
                          itemBuilder: (BuildContext context, int index) {
                            return AnimatedBuilder(
                              animation: animationController,
                              child: PopularAnimeCard(
                                anime: popularList[index],
                              ),
                              builder: (context, child) {
                                return Transform(
                                  transform: Matrix4.translationValues(
                                      -200 *
                                          (1.0 -
                                              CurveAnimation(
                                                      animationController,
                                                      index,
                                                      popularList.length)
                                                  .value),
                                      0,
                                      0),
                                  child: child,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        child: Text(
                          'Recently Added',
                          style: TakoTheme.darkTextTheme.headline4!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          scrollDirection: Axis.horizontal,
                          itemCount: recentlyAdded!.length,
                          itemBuilder: (BuildContext context, int index) {
                            animationController.forward();
                            return AnimatedBuilder(
                              animation: animationController,
                              child: RecentlyAddedAnimeCard(
                                  anime: recentlyAdded[index]),
                              builder: (context, child) {
                                return Transform(
                                  transform: Matrix4.translationValues(
                                      -200 *
                                          (1.0 -
                                              CurveAnimation(
                                                      animationController,
                                                      index,
                                                      recentlyAdded.length)
                                                  .value),
                                      0,
                                      0),
                                  child: child,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        child: Text(
                          'Movie',
                          style: TakoTheme.darkTextTheme.headline4!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Column(
                        children: movieList!.map((anime) {
                          return MovieCard(
                            anime: anime,
                          );
                        }).toList(),
                      )
                    ],
                  ),
                );
              } else {
                return const Center(
                  child: loadingIndicator,
                );
              }
            }));
  }
}
