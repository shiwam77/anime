import 'dart:ui';

import 'package:admob_flutter/admob_flutter.dart';
import 'package:anime/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../helpers/bookmark_manager.dart';
import '../helpers/recent_watch_manager.dart';
import '../models/anime.dart';
import '../models/bookmark.dart';
import '../models/recent_anime.dart';
import '../services/anime_service.dart';
import '../theme/tako_theme.dart';
import '../utils/constants.dart';
import '../utils/routes.dart';
import '../utils/tako_helper.dart';
import '../widgets/anime_detail_header.dart';
import '../widgets/anime_scaffold.dart';
import '../widgets/cache_image_with_cachemanager.dart';
import '../widgets/plot_summary.dart';

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({Key? key}) : super(key: key);

  @override
  _VideoListScreenState createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final RecentWatchManager recentWatchManager = Get.find();
  final BookMarkManager bookMarkManager = Get.find();
  final getRecentEpi = Get.arguments['episode'];
  var selectedIndex = 9999999.obs;
  var isExpanded = false.obs;
  final name = Get.arguments['anime'].name.toString();
  final imageUrl = Get.arguments['anime'].imageUrl.toString();
  final animeUrl = Get.arguments['anime'].animeUrl.toString();
  bool hasRemainingEp = false;
  int remainingEp = 0;
  int totalChipCount = 0;
  RxList<Episode> epChunkList = <Episode>[].obs;
  String start = '';
  String end = '';
  int finalChipCount = 0;
  var selectedChipIndex = 0.obs;
  late AdmobInterstitial interstitialAd;
  GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
  AdmobBannerSize? bannerSize;

  @override
  void initState() {
    super.initState();
    selectedIndex.value = getRecentEpi - 1;
    bannerSize = AdmobBannerSize.BANNER;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    interstitialAd = AdmobInterstitial(
      adUnitId: getInterstitialAdUnitId()!,
      listener: (AdmobAdEvent event, Map<String, dynamic>? args) {
        if (event == AdmobAdEvent.closed) interstitialAd.load();
        handleEvent(event, args, 'Interstitial');
      },
    );
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
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithBackButton(
      appBarTitle: 'Player',
      body: FutureBuilder<Anime>(
          future: AnimeService().fetchAnimeDetails(animeUrl),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'An Error ccurred',
                  style: TakoTheme.darkTextTheme.headline3,
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.done) {
              final anime = snapshot.data;
              if ((anime!.episodes!.length % 50).floor() < 50) {
                hasRemainingEp = true;
                remainingEp = (anime.episodes!.length % 50).floor();
              }
              totalChipCount = (anime.episodes!.length / 50).floor();
              epChunkList.value = anime.episodes!.sublist(
                  0,
                  (hasRemainingEp == true && anime.episodes!.length < 50)
                      ? remainingEp
                      : 50);
              finalChipCount = totalChipCount + (hasRemainingEp ? 1 : 0);

              print('Ep Chunk List ${epChunkList.length}+ $remainingEp');
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: NetworkImageWithCacheManager(
                      imageUrl: imageUrl,
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 8,
                      sigmaY: 8,
                    ),
                    child: Container(
                      color: Colors.black87,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: ListView(
                          children: [
                            AnimeDetailHeader(
                              anime: anime,
                              name: name,
                              imageUrl: imageUrl,
                            ),
                            SizedBox(
                              height: 40,
                            ),
                            PlotSummary(
                              summary: anime.summary.toString(),
                            ),
                            Container(
                              margin: EdgeInsets.only(
                                top: 40,
                                left: 10,
                                right: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Episodes',
                                    style: TakoTheme.darkTextTheme.headline5,
                                  ),
                                  GetBuilder<BookMarkManager>(
                                    builder: (_) => TextButton.icon(
                                        onPressed: () {
                                          final item = BookMark(
                                            id: anime.id!,
                                            imageUrl: imageUrl,
                                            name: name,
                                            animeUrl: animeUrl,
                                          );
                                          if (bookMarkManager.ids
                                              .contains(anime.id.toString())) {
                                            bookMarkManager
                                                .removeFromBookMarks(item);
                                            //Removed
                                            Get.snackbar(name,
                                                'Removed from bookmark successfully!',
                                                backgroundColor: Colors.black38,
                                                duration: const Duration(
                                                    milliseconds: 1300),
                                                snackPosition:
                                                    SnackPosition.BOTTOM);
                                          } else {
                                            bookMarkManager
                                                .addToBookMarks(item);
                                            //Add
                                            Get.snackbar(name,
                                                'Added to bookmark successfully!',
                                                backgroundColor: Colors.black38,
                                                duration: const Duration(
                                                    milliseconds: 1300),
                                                snackPosition:
                                                    SnackPosition.BOTTOM);
                                          }
                                        },
                                        icon: Icon(
                                          bookMarkManager.ids.contains(anime.id)
                                              ? Icons.bookmark
                                              : Icons.bookmark_border_outlined,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          'BookMark',
                                          style: TakoTheme
                                              .darkTextTheme.bodyText1!
                                              .copyWith(color: Colors.white),
                                        )),
                                  )
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 5),
                              child: const Divider(),
                            ),
                            anime.episodes!.length > 50
                                ? SizedBox(
                                    height: 70,
                                    child: ListView.builder(
                                      itemCount: finalChipCount,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 20, left: 8, right: 8),
                                          child: InkWell(
                                            onTap: () {
                                              selectedChipIndex.value = index;
                                              selectedIndex.value = 99999999;
                                              getEpisodeRange(index);
                                              if (finalChipCount ==
                                                  (index + 1)) {
                                                takoDebugPrint('last chip');
                                                epChunkList.value =
                                                    anime.episodes!.sublist(
                                                  int.parse(start) - 1,
                                                );
                                              } else {
                                                epChunkList.value =
                                                    anime.episodes!.sublist(
                                                        int.parse(start) - 1,
                                                        int.parse(end));
                                              }
                                            },
                                            child: Obx(
                                              () => Chip(
                                                backgroundColor:
                                                    selectedChipIndex.value ==
                                                            index
                                                        ? tkGradientBlue
                                                        : Color.fromARGB(
                                                                255, 19, 18, 18)
                                                            .withOpacity(.8),
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 10),
                                                label: Text(
                                                    getEpisodeRange(index),
                                                    style: TakoTheme
                                                        .darkTextTheme
                                                        .subtitle1!),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      scrollDirection: Axis.horizontal,
                                    ))
                                : SizedBox(),
                            // Episodes Grid View
                            anime.episodes!.isNotEmpty
                                ? Obx(
                                    () => GridView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                        mainAxisSpacing: 20,
                                        crossAxisSpacing: 20,
                                        maxCrossAxisExtent: 50,
                                      ),
                                      itemCount: epChunkList.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return Material(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: selectedIndex.value == index
                                              ? tkGradientBlue
                                              : Colors.white,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () async {
                                              setState(() {
                                                selectedIndex.value = index;
                                              });
                                              final recentAnime = RecentAnime(
                                                id: anime.id.toString(),
                                                name: name,
                                                currentEp:
                                                    'Episode ${epChunkList[index].number}',
                                                imageUrl: imageUrl,
                                                epUrl: epChunkList[index]
                                                    .link
                                                    .toString(),
                                                animeUrl: animeUrl,
                                              );
                                              // Add to Recent Anime List
                                              recentWatchManager
                                                  .addAnimeToRecent(
                                                      recentAnime);

                                              await Get.toNamed(
                                                  Routes.mediaFetchScreen,
                                                  arguments: {
                                                    'animeUrl':
                                                        epChunkList[index]
                                                            .link
                                                            .toString()
                                                  });
                                            },
                                            splashColor: Colors.white,
                                            child: Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black12,
                                                      spreadRadius: 2,
                                                      blurRadius: 7,
                                                      offset: Offset(0, 5),
                                                    ),
                                                  ],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Text(
                                                epChunkList[index].number,
                                                style: TakoTheme
                                                    .darkTextTheme.headline6!
                                                    .copyWith(
                                                        color: selectedIndex
                                                                    .value ==
                                                                index
                                                            ? Colors.white
                                                            : Colors.black),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text(
                                      'Coming Soon ..',
                                      style: TakoTheme.darkTextTheme.subtitle2,
                                    ),
                                  ),

                            SizedBox(
                              height: 150,
                            ),
                          ],
                        ),
                      )),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 20.0),
                      child: AdmobBanner(
                        adUnitId: getBannerAdUnitId()!,
                        adSize: bannerSize!,
                        listener:
                            (AdmobAdEvent event, Map<String, dynamic>? args) {
                          handleEvent(event, args, 'Banner');
                        },
                        onBannerCreated: (AdmobBannerController controller) {
                          // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
                          // Normally you don't need to worry about disposing this yourself, it's handled.
                          // If you need direct access to dispose, this is your guy!
                          // controller.dispose();
                        },
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    right: 0,
                    child: NetworkImageWithCacheManager(
                      imageUrl: imageUrl,
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 8,
                      sigmaY: 8,
                    ),
                    child: Container(
                      color: Colors.black87,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ],
              );
            }
          }),
    );
  }

  String getEpisodeRange(int index) {
    start = ((index * 50) + 1).toString();
    end = ((50 * (index + 1))).toString();
    if (index == totalChipCount && hasRemainingEp) {
      end = ((50 * index) + remainingEp).toString();
    }
    // startVal = start;
    // endVal = (int.parse(end) + 1).toString();
    return ('$start - $end');
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
