import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/main.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/selected_posts.dart';
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/pages/wiki_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/util/asset_management.dart' as util_a;
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dt;
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:fuzzy/widgets/w_comments_pane.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
import 'package:fuzzy/widget_lib.dart' as w_;
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/j_util_widgets.dart' as w;
import 'package:progressive_image/progressive_image.dart' show ProgressiveImage;
import 'package:url_launcher/url_launcher.dart';

import '../web/e621/e621.dart';
import '../widgets/w_fab_builder.dart';

/* abstract interface class IReturnsTags {
  // List<String>? get tagsToAdd;
} */

bool overrideQuality = true;
const descriptionTheme = TextStyle(fontWeight: FontWeight.bold, fontSize: 18);
const headerStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 18,
  // color: Colors.amber,
  // decorationStyle: TextDecorationStyle.solid,
  decoration: TextDecoration.underline,
);

class PostViewPage extends StatefulWidget with IRoute<PostViewPage> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("PostViewPage").logger;
  // #region Routing
  static const routeNameConst = "/posts",
      routeSegmentsConst = ["posts", IRoute.idPathParameter],
      routePathConst = "/posts/${IRoute.idPathParameter}",
      hasStaticPathConst = false;

  @override
  get routeName => routeNameConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get hasStaticPath => false;
  @override
  get routeSegmentsFolded => routePathConst;
  static getPathParameterParser(int i) =>
      IRoute.pathParametersMethod[routeSegmentsConst[i]];
  // static int? getPathParameterParser(int i, String uriPathSegAt) =>
  //     IRoute.pathParametersMethod[routeSegmentsConst[i]]!.call(uriPathSegAt);
  static bool acceptsRoutePath(RouteSettings settings) {
    parsePathParam(int i, String e) =>
        IRoute.pathParametersMethod[routeSegmentsConst[i]]?.call(e);
    final Uri? uri;
    if ((uri = IRoute.retrieveValidUri(
            settings, routeSegmentsConst, hasStaticPathConst)) ==
        null) {
      return false;
    }
    final id = uri!.pathSegments.foldTo<int?>(null, (p, e, i, _) {
      if (e == routeSegmentsConst[i]) return p;
      if (p != null) {
        routeLogger.warning(
            "[PostViewPage.acceptsRoutePath] Shouldn't be able to have more"
            " than 1 id params in path. Preserving prior id.\n\t"
            "settings.name: ${settings.name}");
        return p;
      }
      return parsePathParam(i, e)! as int;
    },
            breakIfTrue: (_, e, i, __) => !(e != routeSegmentsConst[i] &&
                parsePathParam(i, e) ==
                    null)) /*  ??
        RouteParameters.retrieveIdFromArguments(settings) */
        ;
    return id != null;
  }

  @override
  bool acceptsRoute(RouteSettings settings) => acceptsRoutePath(settings);
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);

  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final id = Uri.parse(settings.name!).pathSegments.foldTo<int?>(null,
            (p, e, i, _) {
          if (e == routeSegmentsConst[i]) return p;
          if (p != null) {
            routeLogger.warning(
                "[PostViewPage.acceptsRoutePath] Shouldn't be able to have "
                "2 id param slots in path.\n\t"
                "settings.name: ${settings.name}");
          }
          return getPathParameterParser(i)?.call(e)!;
        },
            breakIfTrue: (_, e, i, __) => !(e != routeSegmentsConst[i] &&
                getPathParameterParser(i)?.call(e) == null)) ??
        RouteParameters.retrieveIdFromArguments(settings)!;
    final post = RouteParameters.retrievePostFromArguments(settings);
    return post == null || post is! PostListing
        ? PostViewPageLoader(postId: id)
        : PostViewPage(
            postListing: post is! PostListing
                ? E6PostResponse.fromBaseInstance(post)
                : post as PostListing);
  }

  @override
  Widget? tryGenerateWidgetForRoute(RouteSettings settings) =>
      tryGenerateWidgetForRouteStatic(settings);

  static Widget? tryGenerateWidgetForRouteStatic(RouteSettings settings) {
    final Uri? uri;
    if ((uri = IRoute.retrieveValidUri(
            settings, routeSegmentsConst, hasStaticPathConst)) ==
        null) {
      return null;
    }
    final id = uri!.pathSegments.foldTo<int?>(null, (p, e, i, _) {
          if (e == routeSegmentsConst[i]) return p;
          if (p != null) {
            routeLogger.warning(
                "[PostViewPage.acceptsRoutePath] Shouldn't be able to have "
                "2 id param slots in path.\n\t"
                "settings.name: ${settings.name}");
          }
          return getPathParameterParser(i)?.call(e)!;
        },
            breakIfTrue: (_, e, i, __) => !(e != routeSegmentsConst[i] &&
                getPathParameterParser(i)?.call(e) == null)) ??
        RouteParameters.retrieveIdFromArguments(settings);
    if (id == null) return null;
    final post = RouteParameters.retrievePostFromArguments(settings);
    return post == null || post is! PostListing
        ? PostViewPageLoader(postId: id)
        : PostViewPage(
            postListing: post is! PostListing
                ? E6PostResponse.fromBaseInstance(post)
                : post as PostListing);
  }

  static Widget? legacyBuilder(RouteSettings settings, int? id, Uri url,
      Map<String, String> parameters) {
    try {
      try {
        final v = (settings.arguments as dynamic).post!;
        return PostViewPage(postListing: v);
      } catch (e) {
        id ??= (settings.arguments as PostViewParameters?)?.id ??
            int.tryParse(parameters["postId"] ?? "");
        if (id != null) {
          return PostViewPageLoader(postId: id);
        } else {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
          );
          return null;
        }
      }
    } catch (e, s) {
      routeLogger.severe(
        "Routing failure\n"
        "\tRoute: ${settings.name}\n"
        "\tId: $id\n"
        "\tArgs: ${settings.arguments}",
        e,
        s,
      );
      return null;
    }
  }

  // #endregion Routing
  final PostListing postListing;
  final void Function(String addition)? onAddToSearch;
  final void Function()? onPop;
  final bool? startFullscreen;
  final bool Function()? getFullscreen;
  final void Function(bool)? setFullscreen;
  final List<Widget>? extraActions;
  final List<E6PostResponse>? selectedPosts;
  final SelectedPosts? srn;
  const PostViewPage({
    super.key,
    required this.postListing,
    this.onAddToSearch,
    this.onPop,
    bool this.startFullscreen = false,
    this.extraActions,
    this.selectedPosts,
    this.srn,
  })  : getFullscreen = null,
        setFullscreen = null;
  const PostViewPage.overrideFullscreen({
    super.key,
    required this.postListing,
    this.onAddToSearch,
    this.onPop,
    this.startFullscreen,
    this.extraActions,
    this.selectedPosts,
    required bool Function() this.getFullscreen,
    required void Function(bool) this.setFullscreen,
    this.srn,
  });

  @override
  State<PostViewPage> createState() => _PostViewPageState();
}

class _PostViewPageState
    extends State<PostViewPage> /* implements IReturnsTags */ {
  static lm.FileLogger get logger => PostViewPage.logger;
  // @override
  // // List<String>? get tagsToAdd => widget.tagsToAdd;
  E6PostResponse get e6Post => widget.postListing as E6PostResponse;

  PostView get pvs => AppSettings.i!.postView;

  /// First, tries to get the asset data based on settings.
  /// Then, optimizes based on settings.
  ///
  /// If it has more horizontal resolution than the display,
  /// then try to find the next highest resolution asset IF:
  /// 1. It isn't fullscreen (need extra res for zooming)
  /// 1. We aren't forcing high quality in settings
  /// 1. It's not an animated gif (the only animated gif asset
  /// is the original, no alternates)
  IImageInfo getImageInfo(double screenWidth) {
    IImageInfo? i = widget.postListing.file.isAVideo
        ? switch (PostView.i.videoQuality) {
            FilterQuality.low => e6Post.sample.alternates?.alternates["480p"] ??
                e6Post.sample.alternates?.alternates["720p"] ??
                e6Post.sample.alternates?.alternates["original"],
            FilterQuality.medium =>
              e6Post.sample.alternates?.alternates["720p"] ??
                  e6Post.sample.alternates?.alternates["original"],
            FilterQuality.high =>
              e6Post.sample.alternates?.alternates["original"],
            FilterQuality.none =>
              e6Post.sample.alternates?.alternates["original"],
          }
        : e6Post.isAnimatedGif
            ? e6Post.file
            : switch (PostView.i.imageQuality) {
                FilterQuality.low => e6Post.preview,
                FilterQuality.medium => e6Post.sample,
                FilterQuality.high => e6Post.file,
                FilterQuality.none => e6Post.file,
              };
    if (i == null) return e6Post.file;
    if (i.width > screenWidth &&
        !isFullScreen &&
        !pvs.forceHighQualityImage &&
        !e6Post.isAnimatedGif) {
      if (!widget.postListing.file.isAVideo) {
        if (e6Post.preview.width >= screenWidth) {
          i = widget.postListing.preview;
        } else if (e6Post.sample.width >= screenWidth) {
          i = widget.postListing.sample;
        }
      } else {
        try {
          if ((e6Post
                      .sample
                      .alternates
                      ?.alternates[e621.AlternateResolution.$480p.toString()]
                      ?.width ??
                  (screenWidth - 10)) >=
              screenWidth) {
            i = e6Post.sample.alternates!
                .alternates[e621.AlternateResolution.$480p.toString()]!;
          } else if ((e6Post
                      .sample
                      .alternates
                      ?.alternates[e621.AlternateResolution.$720p.toString()]
                      ?.width ??
                  (screenWidth - 10)) >=
              screenWidth) {
            i = e6Post.sample.alternates!
                .alternates[e621.AlternateResolution.$720p.toString()]!;
          }
        } catch (e, s) {
          logger.severe(
            "Null somewhere\n\te6Post.sample.alternates: "
            "${e6Post.sample.alternates?.toJson().toString()}",
            e,
            s,
          );
        }
      }
    }
    return i!;
  }

  bool _isFullScreen = false;
  bool get isFullScreen =>
      isFullscreenOverridden ? widget.getFullscreen!() : _isFullScreen;
  set isFullScreen(bool v) => setState(() {
        isFullscreenOverridden
            ? widget.setFullscreen!(_isFullScreen = v)
            : _isFullScreen = v;
      });
  @override
  void initState() {
    super.initState();
    _isFullScreen = widget.startFullscreen ?? widget.getFullscreen!();
  }

  bool get isFullscreenOverridden => widget.getFullscreen != null;

  void toggleFullscreen() => isFullScreen = !isFullScreen;

  bool get treatAsFullscreen => isFullScreen && !e6Post.file.isAVideo;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width,
        dpr = MediaQuery.devicePixelRatioOf(context),
        screenWidth = width * dpr;
    logger.log(
      lm.LogLevel.FINE,
      "sizeOf.width: $width\n"
      "devicePixelRatioOf: $dpr\n"
      "Calculated pixel width (w * dpr): $screenWidth",
    );
    // var IImageInfo(width: w, height: h, url: url) = getImageInfo(screenWidth);
    var info = getImageInfo(screenWidth);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (!treatAsFullscreen)
              _buildBody(
                // w: w,
                // h: h,
                // url: url,
                info: info,
                screenWidth: screenWidth,
              ),
            if (treatAsFullscreen)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                ),
              ),
            if (treatAsFullscreen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: toggleFullscreen,
                  child: InteractiveViewer(
                    child: _buildImageContent(
                      // url: url,
                      // w: w,
                      // h: h,
                      info: info,
                      screenWidth: screenWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            WPostViewBackButton(
              onPop: !treatAsFullscreen
                  ? widget.onPop ?? () => Navigator.pop(context, this)
                  : toggleFullscreen,
            ),
            // Positioned.fill(
            //   bottom: 0,
            //   child: _buildBottomRow(context),
            // ),
          ],
        ),
      ),
      floatingActionButton: WFabBuilder.singlePost(
        post: e6Post,
        customActions: widget.extraActions,
        selectedPosts: widget.selectedPosts,
        onClearSelections: () => widget.selectedPosts?.clear(),
        selectedPostIds: widget.srn?.selectedPostIds,
      ),
      /* MediaQuery.sizeOf(context).height / 32 */
      // bottomNavigationBar: ConstrainedBox(
      //   constraints: const BoxConstraints(maxHeight: 56),
      //   child: _buildBottomRow(context),
      // ),
    );
  }

  // Opacity _buildBottomRow(BuildContext context) {
  //   return Opacity(
  //     opacity: .75,
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.end,
  //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //       children: [
  //         if (e6Post.voteState != null)
  //           if (!e6Post.voteState!)
  //             Padding(
  //               padding: const EdgeInsets.all(8),
  //               child: WFabBuilder.getSinglePostUpvoteAction(
  //                 context,
  //                 e6Post,
  //               ),
  //             )
  //           else
  //             Padding(
  //                 padding: const EdgeInsets.all(8),
  //                 child: WFabBuilder.getSinglePostDownvoteAction(
  //                   context,
  //                   e6Post,
  //                 ))
  //         else ...[
  //           Padding(
  //             padding: const EdgeInsets.all(8),
  //             child: WFabBuilder.getSinglePostUpvoteAction(
  //               context,
  //               e6Post,
  //             ),
  //           ),
  //           Padding(
  //               padding: const EdgeInsets.all(8),
  //               child: WFabBuilder.getSinglePostDownvoteAction(
  //                 context,
  //                 e6Post,
  //               )),
  //         ],
  //         WPullTab(
  //           anchorAlignment: AnchorAlignment.bottom,
  //           openIcon: const Icon(Icons.edit),
  //           distance: 200,
  //           color: Theme.of(context).buttonTheme.colorScheme?.onPrimary,
  //           children: [
  //             WFabBuilder.getSinglePostAddToSetAction(context, e6Post),
  //             WFabBuilder.getSinglePostRemoveFromSetAction(context, e6Post),
  //           ],
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.all(8),
  //           child: e6Post.isFavorited
  //               ? WFabBuilder.getSinglePostRemoveFavAction(context, e6Post)
  //               : WFabBuilder.getSinglePostAddFavAction(context, e6Post),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildBody({
    // required int w,
    // required int h,
    // required String url,
    required IImageInfo info,
    double? screenWidth,
  }) {
    final IImageInfo(width: w, height: h, url: url) = info;
    final mqWidth = MediaQuery.sizeOf(context).width,
        maxWidth =
            screenWidth ?? mqWidth * MediaQuery.devicePixelRatioOf(context);
    final maxHeight = (h / w) * maxWidth;
    final ar = w / h;
    logger.log(
      lm.LogLevel.FINE,
      "Content: w $w h $h ratio $ar",
    );
    logger.log(
      lm.LogLevel.FINE,
      "Constraints: maxWidth $maxWidth maxHeight $maxHeight ratio ${maxWidth / maxHeight}",
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: AspectRatio(
              aspectRatio: ar,
              child: _buildMainContent(/* url, w, h */ info),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              SelectableText("ID: ${e6Post.id}, W: $w, H: $h"),
              // SelectableText(
              //     "ID: ${e6Post.id}, W: $w, H: $h, screenWidth: ${maxWidth.toStringAsPrecision(5)}, MQWidth: ${mqWidth.toStringAsPrecision(5)}"),
            ],
          ),
          if (e6Post.relationships.hasParent ||
              e6Post.relationships.hasChildren /* hasActiveChildren */)
            // TODO: Render a sliver
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text.rich(TextSpan(children: [
                if (e6Post.relationships.hasParent)
                  const TextSpan(text: "Parent: "),
                if (e6Post.relationships.hasParent)
                  WidgetSpan(
                      child: _buildSinglePostViewButton(
                          context, e6Post.relationships.parentId!)),
                if (e6Post.relationships.hasChildren /* hasActiveChildren */)
                  const TextSpan(text: "Children: "),
                if (e6Post.relationships.hasChildren /* hasActiveChildren */)
                  ...e6Post.relationships.children.map(
                    (e) => WidgetSpan(
                        child: _buildSinglePostViewButton(context, e)),
                  ),
              ])),
              // child: Row(children: [
              //   if (e6Post.relationships.hasParent) const Text("Parent: "),
              //   if (e6Post.relationships.hasParent)
              //     _buildSinglePostViewButton(
              //         context, e6Post.relationships.parentId!),
              //   if (e6Post.relationships.hasChildren/* hasActiveChildren */)
              //     const Text("Children: "),
              //   if (e6Post.relationships.hasChildren/* hasActiveChildren */)
              //     ...e6Post.relationships.children.map(
              //       (e) => _buildSinglePostViewButton(context, e),
              //     ),
              // ]),
            ),
          if (e6Post.pools.firstOrNull != null)
            Row(children: [
              const Text("Pools: "),
              ...e6Post.pools.map((e) => TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      "${PoolViewPageLoader.routeNameConst}?id=$e",
                    );
                  },
                  child: Text(e.toString()))),
            ]),
          if (e6Post.description.isNotEmpty)
            // ExpansionTile(
            //   title: const ListTile(
            //     title: Text("Description", style: descriptionTheme),
            //   ),
            //   initiallyExpanded: PostView.i.startWithDescriptionExpanded,
            //   children: [
            //     SelectableText.rich(
            //       ErrorPage.errorWrapper(
            //             () => dt.parse(e6Post.description, context) as TextSpan,
            //             logger: logger,
            //           ).value ??
            //           TextSpan(text: e6Post.description),
            //     )
            //   ],
            // ),
            if (PostView.i.startWithDescriptionExpanded)
              ExpansionTile(
                title: const ListTile(
                  title: Text("Description", style: descriptionTheme),
                ),
                initiallyExpanded: PostView.i.startWithDescriptionExpanded,
                children: [
                  SelectableText.rich(
                    ErrorPage.errorWrapper(
                          () =>
                              dt.parse(e6Post.description, context) as TextSpan,
                          logger: logger,
                        ).value ??
                        TextSpan(text: e6Post.description),
                  )
                ],
              )
            else
              w_.ExpansionTileAsync.delayLoading(
                debugName: "Description ${e6Post.id}",
                title: const ListTile(
                  title: Text("Description", style: descriptionTheme),
                ),
                childrenBuilder: (context, setState) => compute(
                    (d) => [
                          SelectableText.rich(
                            ErrorPage.errorWrapper(
                                  () => dt.parse(d, context) as TextSpan,
                                  logger: logger,
                                ).value ??
                                TextSpan(text: d),
                          )
                        ],
                    e6Post.description),
              ),
          ..._buildTagsDisplay(context),
          _buildSourcesDisplay(),
          WCommentsLoader(postId: e6Post.id),
        ],
      ),
    );
  }

  TextButton _buildSinglePostViewButton(BuildContext context, int e) =>
      TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FutureBuilder(
                  future: e621
                      .sendRequest(e621.initPostGet(e))
                      .then((v) => jsonDecode(v.body)),
                  builder: (_, snapshot) {
                    return snapshot.hasData
                        ? ErrorPage.errorWidgetWrapper(() {
                            final accessor = snapshot.data["post"] != null
                                ? "post"
                                : "posts";
                            return WarnPage.withChild(
                                p: E6PostResponse.fromJson(
                                  snapshot.data[accessor],
                                ),
                                child: PostViewPage(
                                  postListing: E6PostResponse.fromJson(
                                    snapshot.data[accessor],
                                  ),
                                  onPop: widget.onPop,
                                  selectedPosts: widget.selectedPosts,
                                  onAddToSearch: widget.onAddToSearch,
                                ));
                          }, logger: PostViewPage.logger)
                            .value
                        : snapshot.hasError
                            ? ErrorPage.logError(
                                error: snapshot.error,
                                stackTrace: snapshot.stackTrace,
                                logger: PostViewPage.logger,
                                message: "Failed: ${snapshot.data}",
                              )
                            : util.fullPageSpinner;
                  },
                ),
              ),
            );
          },
          child: Text(e.toString()));
  @widgetFactory
  Widget _buildMainContent(
    // final String url,
    // final int w,
    // final int h, {
    final IImageInfo info, {
    double? screenWidth,
    BuildContext? context,
  }) {
    final IImageInfo(width: w, height: h, url: url) = info;
    context ??= this.context;
    if (url == deletedUrl) {
      return Image(image: (info as RetrieveImageProvider).createResizeImage());
    }
    if (widget.postListing.file.isAVideo) {
      return ErrorPage.errorWidgetWrapper(
        () => WVideoPlayerScreen(
            resourceUri: Uri.tryParse(url) ?? widget.postListing.file.address),
        logger: logger,
      ).value;
    } else {
      return Stack(
        children: [
          Positioned.fill(
              child: _buildImageContent(
            // url: url,
            // w: w,
            // h: h,
            info: info,
            screenWidth: screenWidth,
          )),
          _buildFullscreenToggle(),
        ],
      );
    }
  }

  Positioned _buildFullscreenToggle() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: toggleFullscreen),
      ),
    );
  }

  static const progressiveImageBlur = 10.0;
  @widgetFactory
  Widget _buildImageContent({
    // required final String url,
    // required final int w,
    // required final int h,
    required IImageInfo info,
    double? screenWidth,
    final BoxFit fit = BoxFit.fitWidth,
  }) {
    final IImageInfo(width: w, height: h, url: url) = info;
    screenWidth ??= MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    if (!pvs.useProgressiveImages) {
      return Image.network(
        url,
        errorBuilder: (context, error, stackTrace) => throw error,
        fit: fit,
        width: w.toDouble(),
        height: h.toDouble(),
        cacheWidth:
            !pvs.forceHighQualityImage ? min(w, screenWidth.toInt()) : w,
        // cacheHeight: h,
        filterQuality: pvs.imageFilterQuality,
      );
    }
    var cWidth = min(w, screenWidth.toInt());
    var iFinal = ResizeImage.resizeIfNeeded(
      cWidth,
      null,
      NetworkImage(url, scale: w / cWidth),
    );
    if (url == e6Post.preview.url) {
      return ProgressiveImage(
        blur: progressiveImageBlur,
        placeholder: util_a.placeholder,
        thumbnail: iFinal,
        image: iFinal,
        width: screenWidth, //cWidth.toDouble(),
        height: double.infinity,
        fit: fit,
        fadeDuration: const Duration(milliseconds: 250),
      );
    } else {
      var iPreview = ResizeImage.resizeIfNeeded(
        cWidth,
        null,
        NetworkImage(e6Post.preview.url, scale: e6Post.preview.width / cWidth),
      );
      if (e6Post.sample.has && url != e6Post.sample.url) {
        var iSample = ResizeImage.resizeIfNeeded(
          cWidth,
          null,
          NetworkImage(e6Post.sample.url, scale: e6Post.sample.width / cWidth),
        );
        return ProgressiveImage(
          blur: progressiveImageBlur,
          // placeholder: placeholder,
          placeholder: iPreview,
          thumbnail: iSample,
          image: iFinal,
          width: screenWidth, //cWidth.toDouble(),
          height: double.infinity,
          fit: fit,
          fadeDuration: const Duration(milliseconds: 250),
        );
      } else {
        return ProgressiveImage(
          blur: progressiveImageBlur,
          placeholder: util_a.placeholder,
          thumbnail: iPreview,
          image: iFinal,
          width: screenWidth, //cWidth.toDouble(),
          height: double.infinity,
          fit: fit,
          fadeDuration: const Duration(milliseconds: 250),
        );
      }
    }
  }

  @widgetFactory
  Iterable<Widget> _buildTagsDisplay(BuildContext context) {
    var tagOrder = pvs.tagOrder;
    return [
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(0)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(0)],
          ),
          tagOrder.elementAtOrNull(0),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(1)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(1)],
          ),
          tagOrder.elementAtOrNull(1),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(2)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(2)],
          ),
          tagOrder.elementAtOrNull(2),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(3)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(3)],
          ),
          tagOrder.elementAtOrNull(3),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(4)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(4)],
          ),
          tagOrder.elementAtOrNull(4),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(5)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(5)],
          ),
          tagOrder.elementAtOrNull(5),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(6)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(6)],
          ),
          tagOrder.elementAtOrNull(6),
        )!,
    ];
  }

  bool _willTagDisplayBeNonNull(e621.TagCategory? category) =>
      category != null && e6Post.tags.getByCategory(category).isNotEmpty;

  @widgetFactory
  Widget? _buildTagDisplayFoldout(
    BuildContext context,
    TextStyle headerStyle,
    e621.TagCategory? category,
  ) {
    return _willTagDisplayBeNonNull(category)
        // ? ExpansionTile(
        //     initiallyExpanded: PostView.i.startWithTagsExpanded,
        //     title: _buildTagDisplayHeader(context, headerStyle, category!),
        //     dense: true,
        //     visualDensity: VisualDensity.compact,
        //     expandedAlignment: Alignment.centerLeft,
        //     expandedCrossAxisAlignment: CrossAxisAlignment.start,
        //     children: _buildTagDisplayList(
        //       context,
        //       headerStyle,
        //       category,
        //     ).toList(growable: false),
        //   )
        ? PostView.i.startWithTagsExpanded
            ? ExpansionTile(
                initiallyExpanded: true,
                title: _buildTagDisplayHeader(context, headerStyle, category!),
                dense: true,
                visualDensity: VisualDensity.compact,
                expandedAlignment: Alignment.centerLeft,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: _buildTagDisplayList(
                  context,
                  headerStyle,
                  category,
                ).toList(growable: false),
              )
            : w_.ExpansionTileAsync.delayLoading(
                debugName:
                    "${category?.name} _buildTagDisplayFoldout ${e6Post.id}",
                title: _buildTagDisplayHeader(context, headerStyle, category!),
                dense: true,
                visualDensity: VisualDensity.compact,
                expandedAlignment: Alignment.centerLeft,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenBuilder: (context, setState) => compute(
                    ((BuildContext, TextStyle, e621.TagCategory) v) =>
                        _buildTagDisplayList(v.$1, v.$2, v.$3)
                            .toList(growable: false),
                    (context, headerStyle, category)),
              )
        : null;
  }

  @widgetFactory
  Widget _buildTagDisplayHeader(
    BuildContext context,
    TextStyle headerStyle,
    e621.TagCategory category,
  ) {
    if (!pvs.colorTagHeaders) headerStyle.copyWith(color: null);
    return Text(
      "${category.name[0].toUpperCase()}${category.name.substring(1)}",
      style: headerStyle,
    );
  }

  @widgetFactory
  Iterable<Widget> _buildTagDisplayList(
    BuildContext context,
    TextStyle headerStyle,
    e621.TagCategory category,
  ) {
    if (!pvs.colorTags) headerStyle.copyWith(color: null);
    return e6Post.tags.getByCategory(category).map((e) => Align(
          widthFactor: 1,
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => showTagDialog(tag: e, category: category),
            child: Text(e),
          ),
        ));
  }

  /// TODO: Pull some of these into e6actions
  void showTagDialog({
    required String tag,
    required e621.TagCategory category,
  }) {
    SavedDataE6.init();
    BuildContext ctx(BuildContext ctx) => ctx.mounted ? ctx : context;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tag, style: headerStyle),
                ListTile(
                  title: const Text("Search"),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => buildHomePageWithProviders(
                          searchText: tag,
                        ),
                      )),
                ),
                ListTile(
                  title: const Text("Add to search"),
                  onTap: () {
                    widget.onAddToSearch?.call(tag);
                    // widget.tagsToAdd?.add(tag);
                    Navigator.pop(context);
                  },
                ),
                if (!(AppSettings.i?.blacklistedTags.contains(tag) ?? true))
                  ListTile(
                    title: const Text("Add to local blacklist"),
                    onTap: () {
                      AppSettings.i?.blacklistedTags.add(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (AppSettings.i?.blacklistedTags.contains(tag) ?? false)
                  ListTile(
                    title: const Text("Remove from local blacklist"),
                    onTap: () {
                      AppSettings.i?.blacklistedTags.remove(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (!(AppSettings.i?.favoriteTags.contains(tag) ?? true))
                  ListTile(
                    title: const Text("Add to local favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.add(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (AppSettings.i?.favoriteTags.contains(tag) ?? false)
                  ListTile(
                    title: const Text("Remove from local favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.remove(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (!SavedDataE6.all.any(
                  (e) => e.searchString.replaceAll(RegExp(r"\s"), "") == tag,
                ))
                  ListTile(
                    title: const Text("Add to saved searches"),
                    onTap: () {
                      Navigator.pop(context);
                      showSavedElementEditDialogue(
                        context,
                        initialData: tag,
                        initialParent: category.name,
                        initialTitle: tag,
                        initialUniqueId: tag,
                      ).then((value) {
                        if (value != null) {
                          SavedDataE6.doOnInit(
                            () => SavedDataE6.$addAndSaveSearch(
                              SavedSearchData.fromTagsString(
                                searchString: value.mainData,
                                title: value.title,
                                uniqueId: value.uniqueId ?? "",
                                parent: value.parent ?? "",
                              ),
                            ),
                          );
                        }
                      });
                    },
                  ),
                if (SavedDataE6.isInit && SavedDataE6.searches.isNotEmpty)
                  ListTile(
                    title: const Text("Add tag to a saved search"),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog<SavedSearchData>(
                        context: this.context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Select a search"),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: SavedDataE6.buildParentedView(
                                context: this.context,
                                generateOnTap: (e) =>
                                    () => Navigator.pop(this.context, e),
                              ),
                            ),
                          );
                        },
                      ).then((e) => e == null
                          ? ""
                          : showSavedElementEditDialogue(
                              // ignore: use_build_context_synchronously
                              ctx(context),
                              initialData: "${e.searchString} $tag",
                              initialParent: e.parent,
                              initialTitle: e.title,
                              initialUniqueId: e.uniqueId,
                              initialEntry: e,
                            ).then((value) {
                              if (value != null) {
                                SavedDataE6.$editAndSave(
                                  original: e,
                                  edited: SavedSearchData.fromTagsString(
                                    searchString: value.mainData,
                                    title: value.title,
                                    uniqueId: value.uniqueId ?? "",
                                    parent: value.parent ?? "",
                                  ),
                                );
                              }
                            }));
                    },
                  ),
                ListTile(
                  title: const Text("Add to clipboard"),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tag))
                        // ignore: use_build_context_synchronously
                        .then((v) => util.contextCheck(ctx(context), (context) {
                              util.showUserMessage(
                                context: context,
                                content: Text("$tag added to clipboard."),
                              );
                              Navigator.pop(context);
                            }));
                  },
                ),
                ListTile(
                  title: const Text("Search Wiki in browser"),
                  onTap: () {
                    final url = Uri.parse(
                        "https://e621.net/wiki_pages/show_or_new?title=$tag");
                    canLaunchUrl(url).then(
                      (value) => value
                          ? launchUrl(url)
                          : showDialog(
                              // ignore: use_build_context_synchronously
                              context: (ctx(context)),
                              builder: (context) => AlertDialog(
                                content: const Text("Cannot open in browser"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Ok"),
                                  )
                                ],
                              ),
                            ),
                    );
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text("Get Wiki Page"),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: this.context,
                      builder: (context) {
                        return AlertDialog(
                          title: AppBar(title: Text(tag)),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                              child: WikiPageLoader.fromTitle(
                                title: tag,
                                isFullPage: false,
                              ),
                            ),
                          ),
                        );
                        // e621.WikiPage? result;
                        // Future<e621.WikiPage>? f;
                        // f = e621
                        //     .sendRequest(
                        //         E621.initWikiTagSearchRequest(tag: tag))
                        //     .then((value) =>
                        //         e621.WikiPage.fromRawJson(value.body));
                        // return AlertDialog(
                        //   content: SizedBox(
                        //     width: double.maxFinite,
                        //     child: StatefulBuilder(
                        //       builder: (context, setState) {
                        //         f
                        //             ?.then((v) => setState(() {
                        //                   result = v;
                        //                   f?.ignore();
                        //                   f = null;
                        //                 }))
                        //             .ignore();
                        //         return SingleChildScrollView(
                        //           child: Column(
                        //             mainAxisSize: MainAxisSize.min,
                        //             children: [
                        //               if (f != null)
                        //                 // util.spinnerExpanded
                        //                 const CircularProgressIndicator()
                        //               else
                        //                 result != null
                        //                     ? Text.rich(dt.parse(result!.body))
                        //                     : const Text("Failed to load"),
                        //             ],
                        //           ),
                        //         );
                        //       },
                        //     ),
                        //   ),
                        // );
                      },
                    );
                  },
                ),
                if (SubscriptionManager.isInit &&
                    !SubscriptionManager.subscriptions.any((e) => e.tag == tag))
                  ListTile(
                    title: const Text("Add Subscription"),
                    onTap: () {
                      SubscriptionManager.subscriptions.add(
                        TagSubscription(
                            tag: tag, lastId: widget.postListing.id),
                      );
                      SubscriptionManager.writeToStorage();
                      Navigator.pop(context);
                    },
                  ),
                if (SubscriptionManager.isInit &&
                    SubscriptionManager.subscriptions.any((e) => e.tag == tag))
                  ListTile(
                    title: const Text("Remove Subscription"),
                    onTap: () {
                      SubscriptionManager.subscriptions.remove(
                          SubscriptionManager.subscriptions
                              .firstWhere((e) => e.tag == tag));
                      SubscriptionManager.writeToStorage();
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  Widget _buildSourcesDisplay() => w_.ExpansionTileAsync.delayLoading(
        debugName: "Sources ${e6Post.id}",
        title: const Text("Sources", style: headerStyle),
        childrenBuilder: (context, setState) =>
            compute((s) => s.toList(), _buildSources()),
      );
  // Widget _buildSourcesDisplay() => ExpansionTile(
  //       title: const Text("Sources", style: headerStyle),
  //       children: _buildSources().toList(),
  //     );
  Iterable<Widget> _buildSources() => e6Post.sources.map(
        (e) => Linkify(
          onOpen: (link) async {
            if (RegExp(r"(\.png|\.jpg|\.jpeg|\.gif)$").hasMatch(link.url)) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(),
                      body: SafeArea(
                        child: Image.network(
                          link.url,
                          errorBuilder: (context, error, stackTrace) {
                            Navigator.pop(context);
                            launchUrl(Uri.parse(link.url)).then((v) =>
                                !v && !Platform.isWeb
                                    ? throw Exception(
                                        'Could not launch ${link.url}')
                                    : null);
                            return ErrorPage(
                                error: error,
                                stackTrace: stackTrace,
                                logger: logger);
                          },
                        ),
                      ),
                    ),
                  ));
              return;
            }
            if (!await launchUrl(Uri.parse(link.url)) && !Platform.isWeb) {
              throw Exception('Could not launch ${link.url}');
            }
          },
          text: e,
          // style: TextStyle(color: Colors.yellow),
          linkStyle: const TextStyle(color: Colors.yellow),
        ),
      );
}

class WPostViewBackButton extends StatelessWidget {
  const WPostViewBackButton({
    super.key,
    this.onPop,
  });

  final void Function()? onPop;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SafeArea(
        child: BackButton(
          onPressed: () {
            if (onPop != null) {
              onPop!();
            } else {
              Navigator.pop(context);
            }
          },
          // icon: const Icon(Icons.arrow_back),
          // iconSize: 36,
          style: const ButtonStyle(
            iconSize: WidgetStatePropertyAll(36),
            backgroundColor: WidgetStateColor.transparent,
            elevation: WidgetStatePropertyAll(15),
            shadowColor: WidgetStatePropertyAll(Colors.black),
          ),
        ),
      ),
      // child: IconButton(
      //   onPressed: () {
      //     if (onPop != null) {
      //       onPop!();
      //     } else {
      //       Navigator.pop(context);
      //     }
      //   },
      //   icon: const Icon(Icons.arrow_back),
      //   iconSize: 36,
      //   style: const ButtonStyle(
      //     backgroundColor: WidgetStateColor.transparent,
      //     elevation: WidgetStatePropertyAll(15),
      //     shadowColor: WidgetStatePropertyAll(Colors.black),
      //   ),
      // ),
    );
  }
}

typedef PostViewParameters = ({int? id, PostListing? post});

class PostViewPageLoader extends StatelessWidget
    with IRoute<PostViewPageLoader> {
  // #region Routing
  static const routeNameConst = PostViewPage.routeNameConst;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => PostViewPage.hasStaticPathConst;
  @override
  get routeSegments => PostViewPage.routeSegmentsConst;

  @override
  get routeSegmentsFolded => PostViewPage.routePathConst;

  @override
  bool acceptsRoute(RouteSettings settings) =>
      PostViewPage.acceptsRoutePath(settings);

  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      PostViewPage.generateWidgetForRouteStatic(settings);

  @override
  Widget? tryGenerateWidgetForRoute(RouteSettings settings) =>
      PostViewPage.tryGenerateWidgetForRouteStatic(settings);
  // #endregion Routing

  final int postId;

  const PostViewPageLoader({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: e621.sendRequest(e621.initPostGet(
        postId,
        credentials: E621AccessData.allowedUserDataSafe?.cred,
      )),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return PostViewPage(
              postListing: E6PostResponse.fromRawJson(snapshot.data!.body));
        } else if (snapshot.hasError) {
          return ErrorPage(
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            logger: PostViewPage.logger,
          );
        } else {
          return util.fullPageSpinner;
        }
      },
    );
  }
}

class WarnPage extends StatefulWidget {
  final E6PostResponse p;
  final Widget? child;
  final void Function(BuildContext)? onSuccess;
  final void Function(BuildContext) onCancel;
  const WarnPage.withChild({
    super.key,
    required this.p,
    required Widget this.child,
    this.onSuccess,
    this.onCancel = _defaultOnCancel,
  });
  const WarnPage.callback({
    super.key,
    required this.p,
    this.child,
    required void Function(BuildContext) this.onSuccess,
    this.onCancel = _defaultOnCancel,
  });
  static _defaultOnCancel(BuildContext context) => Navigator.pop(context);

  @override
  State<WarnPage> createState() => _WarnPageState();
}

class _WarnPageState extends State<WarnPage> {
  bool continued = false;
  bool launchedDialog = false;

  @override
  void initState() {
    super.initState();
    final intersect = widget.p.tagList
        .toSet()
        .intersection(AppSettings.i!.blacklistedTagsAll);
    if (intersect.isEmpty) {
      continued = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration d) {
      if (continued) {
        if (!launchedDialog) {
          launchedDialog = true;
          widget.onSuccess?.call(context);
        }
      }
      if (!launchedDialog) {
        final intersect = widget.p.tagList
            .toSet()
            .intersection(AppSettings.i!.blacklistedTagsAll);
        if (intersect.isNotEmpty) {
          showDialog(
            context: context,
            useSafeArea: true,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: /* SizedBox.shrink(
                child:  */
                  Text(
                      "This post has the following blacklisted tags:${intersect.fold("", (p, e) => "$p\n\t$e")}\nDo you want to proceed?"),
              // ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  label: const Text("Yes"),
                  icon: const Icon(Icons.check),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, false),
                  label: const Text("No"),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
          ).then((v) {
            if (v != null) {
              setState(() {
                continued = v;
              });
            }
            final BuildContext context;
            if ((context = this.context).mounted) {
              v == true
                  ? widget.onSuccess?.call(context)
                  : widget.onCancel.call(context);
            }
          });
          // setState(() {
          launchedDialog = true;
          // });
        } else {
          setState(() {
            continued = launchedDialog = true;
          });
          widget.onSuccess?.call(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return continued
        ? widget.child != null
            ? widget.child!
            : const w.SoloBackButton.overlay()
        : const SizedBox.expand();
  }
}
