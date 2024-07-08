import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/main.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
import 'package:j_util/e621.dart';
import 'package:j_util/j_util_full.dart';
// import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:progressive_image/progressive_image.dart';

import '../web/e621/e621.dart';
import '../widgets/w_fab_builder.dart';
import 'package:fuzzy/log_management.dart' as lm;

abstract interface class IReturnsTags {
  List<String>? get tagsToAdd;
}

bool overrideQuality = true;
const descriptionTheme = TextStyle(fontWeight: FontWeight.bold, fontSize: 18);
const headerStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 18,
  // color: Colors.amber,
  // decorationStyle: TextDecorationStyle.solid,
  decoration: TextDecoration.underline,
);

/// TODO: Expansion State Preservation on scroll
class PostViewPage extends StatefulWidget
    implements IReturnsTags, IRoute<PostViewPage> {
  // #region Logger
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("PostViewPage");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  static const routeNameString = "/post";
  final PostListing postListing;
  final void Function(String addition)? onAddToSearch;
  final void Function()? onPop;
  final bool? startFullscreen;
  final bool Function()? getFullscreen;
  final void Function(bool)? setFullscreen;
  @override
  final List<String>? tagsToAdd;
  const PostViewPage({
    super.key,
    required this.postListing,
    this.onAddToSearch,
    this.onPop,
    this.tagsToAdd,
    bool this.startFullscreen = false,
  })  : getFullscreen = null,
        setFullscreen = null;
  const PostViewPage.overrideFullscreen({
    super.key,
    required this.postListing,
    this.onAddToSearch,
    this.onPop,
    this.tagsToAdd,
    this.startFullscreen,
    required bool Function() this.getFullscreen,
    required void Function(bool) this.setFullscreen,
  });

  @override
  get routeName => PostViewPage.routeNameString;

  @override
  State<PostViewPage> createState() => _PostViewPageState();
}

class _PostViewPageState extends State<PostViewPage> implements IReturnsTags {
  // #region Logger
  // static get lRecord => PostViewPage.lRecord;
  static lm.Printer get print => PoolViewPage.print;
  static lm.FileLogger get logger => PostViewPage.logger;
  // #endregion Logger
  @override
  List<String>? get tagsToAdd => widget.tagsToAdd;
  E6PostResponse get e6Post => widget.postListing as E6PostResponse;

  PostView get pvs => AppSettings.i!.postView;

  IImageInfo getImageInfo(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width,
        dpr = MediaQuery.devicePixelRatioOf(context),
        horizontalPixels = w * dpr;
    logger.log(lm.LogLevel.INFO,
        "MediaQuery.sizeOf(context).width: $w\nMediaQuery.devicePixelRatioOf(context): $dpr\nCalculated pixel width(w*dpr): $horizontalPixels");
    // var IImageInfo(width: w, height: h, url: url) = postListing.sample;
    var i = widget.postListing.file.isAVideo
        ? switch (PostView.i.imageQuality) {
            "low" => (e6Post.sample.alternates!.alternates["480p"] ??
                e6Post.sample.alternates!.alternates["720p"] ??
                e6Post.sample.alternates!.alternates["original"])!,
            "medium" => (e6Post.sample.alternates!.alternates["720p"] ??
                e6Post.sample.alternates!.alternates["original"])!,
            "high" => e6Post.sample.alternates!.alternates["original"]!,
            _ => throw UnsupportedError("type not supported"),
          }
        : widget.postListing.file.extension == "gif" &&
                e6Post.tags.meta.contains("animated")
            ? e6Post.file
            : switch (PostView.i.imageQuality) {
                "low" => e6Post.preview,
                "medium" => e6Post.sample,
                "high" => e6Post.file,
                _ => throw UnsupportedError("type not supported"),
              };
    /* if (!postListing.file.isAVideo && i.width > horizontalPixels) {
      if (e6Post.preview.width > horizontalPixels) {
        i = postListing.preview;
      } else if (e6Post.sample.width > horizontalPixels) {
        i = postListing.sample;
      }
    } */
    // if (!postListing.file.isAVideo && /* w < horizontalPixels &&  */
    //     pvs.forceHighQualityImage) {
    //   IImageInfo(width: w, height: h, url: url) = postListing.file;
    // }
    return i;
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
    var IImageInfo(width: w, height: h, url: url) = getImageInfo(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(
              context,
              w: w,
              h: h,
              url: url,
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
                      url,
                      w,
                      h,
                      context,
                      BoxFit.contain,
                    ),
                  ),
                ),
              ),
            // if (treatAsFullscreen) _buildFullscreenToggle(),
            WPostViewBackButton(
              // onPop: widget.onPop ?? () => Navigator.pop(context, this),
              onPop: !treatAsFullscreen
                  ? widget.onPop ?? () => Navigator.pop(context, this)
                  : toggleFullscreen,
            ),
          ],
        ),
      ),
      floatingActionButton: WFabBuilder.singlePost(post: e6Post),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required int w,
    required int h,
    required String url,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    final maxHeight = (h / w) * maxWidth;
    final ar = w / h;
    logger.log(
      lm.LogLevel.INFO,
      "Content: w $w h $h ratio $ar",
    );
    logger.log(
      lm.LogLevel.INFO,
      "Constraints: maxWidth $maxWidth maxHeight $maxHeight ratio ${maxWidth / maxHeight}",
    );
    return ListView(
      // padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            // maxHeight: (MediaQuery.of(context).size.width / w) * h.toDouble(),
            // maxWidth: pvs.allowOverflow
            //     ? MediaQuery.of(context).size.width
            //     : (MediaQuery.of(context).size.height / h) * w.toDouble(),
            // maxHeight: pvs.allowOverflow
            //     ? (MediaQuery.of(context).size.width / w) * h.toDouble()
            //     : MediaQuery.of(context).size.height,
          ),
          child: AspectRatio(
            aspectRatio: ar,
            child: _buildMainContent(url, w, h, context),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
                "ID: ${e6Post.id}, W: $w, H: $h, screenWidth: ${maxWidth.toStringAsPrecision(5)}, MQWidth: ${MediaQuery.sizeOf(context).width.toStringAsPrecision(5)}"),
          ],
        ),
        if (e6Post.relationships.hasActiveChildren)
          Row(children: [
            const Text("Children: "),
            ...e6Post.relationships.children.map(
              (e) => TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FutureBuilder(
                          future: E621
                              .sendRequest(Api.initSearchPostRequest(e))
                              .toResponse()
                              .then((v) => jsonDecode(v.body)),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              try {
                                return PostViewPage(
                                  postListing: E6PostResponse.fromJson(
                                    snapshot.data["posts"],
                                  ),
                                );
                              } catch (e, s) {
                                PostViewPage.logger
                                    .severe("Failed: ${snapshot.data}", e, s);
                                return Scaffold(
                                  appBar: AppBar(),
                                  body: Text("$e\n$s\n${snapshot.data}"),
                                );
                              }
                            } else if (snapshot.hasError) {
                              PostViewPage.logger.severe(
                                "Failed: ${snapshot.data}",
                                snapshot.error,
                                snapshot.stackTrace,
                              );
                              return Scaffold(
                                appBar: AppBar(),
                                body: Text(
                                  "${snapshot.error}\n${snapshot.stackTrace}",
                                ),
                              );
                            } else {
                              return scSaCoExArCpi;
                            }
                          },
                        ),
                      ),
                    );
                  },
                  child: Text(e.toString())),
            ),
          ]),
        if (e6Post.pools.firstOrNull != null)
          Row(children: [
            const Text("Pools: "),
            ...e6Post.pools.map((e) => TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    "${PoolViewPageBuilder.routeNameString}?poolId=$e",
                    // MaterialPageRoute(
                    //   builder: (context) => PoolViewPageBuilder(poolId: e),
                    // ),
                  );
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => PoolViewPageBuilder(poolId: e),
                  //   ),
                  // );
                },
                child: Text(e.toString()))),
          ]),
        if (e6Post.description.isNotEmpty)
          ExpansionTile(
            title: ListTile(
              title: Text("Description", style: descriptionTheme),
            ),
            initiallyExpanded: PostView.i.startWithDescriptionExpanded,
            children: [SelectableText(e6Post.description)],
          ),
        ..._buildTagsDisplay(context),
      ],
    );
  }

  @widgetFactory
  Widget _buildMainContent(
    final String url,
    final int w,
    final int h,
    final BuildContext ctx,
  ) {
    if (widget.postListing.file.isAVideo) {
      return WVideoPlayerScreen(
          resourceUri: Uri.tryParse(url) ?? widget.postListing.file.address);
    } else {
      return Stack(
        children: [
          Positioned.fill(child: _buildImageContent(url, w, h, ctx)),
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

  @widgetFactory
  Widget _buildMainContentLegacy(
    final String url,
    final int w,
    final int h,
    final BuildContext ctx,
  ) {
    if (widget.postListing.file.isAVideo) {
      return WVideoPlayerScreen(
          resourceUri: Uri.tryParse(url) ?? widget.postListing.file.address);
    } else {
      return Stack(
        children: [
          Positioned.fill(child: _buildImageContent(url, w, h, ctx)),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (context) {
                    return Scaffold(
                      body: Stack(
                        children: [
                          Positioned.fill(
                            child: InteractiveViewer(
                              child: _buildImageContent(
                                url,
                                w,
                                h,
                                ctx,
                                BoxFit.contain,
                              ),
                            ),
                          ),
                          const WPostViewBackButton(),
                        ],
                      ),
                    );
                  },
                )),
              ),
            ),
          ),
        ],
      );
    }
  }

  @widgetFactory
  Widget _buildImageContent(
    final String url,
    final int w,
    final int h,
    final BuildContext ctx, [
    final BoxFit fit = BoxFit.fitWidth,
  ]) {
    final screenWidth = MediaQuery.sizeOf(ctx).width * MediaQuery.devicePixelRatioOf(context);
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
    var cWidth = min(w, MediaQuery.sizeOf(ctx).width.toInt());
    var iFinal = ResizeImage.resizeIfNeeded(
      cWidth,
      null,
      NetworkImage(url, scale: w / cWidth),
    );
    if (url == e6Post.preview.url) {
      return ProgressiveImage(
        placeholder: placeholder,
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
          placeholder: placeholder,
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

  bool _willTagDisplayBeNonNull(TagCategory? category) =>
      category != null && e6Post.tags.getByCategory(category).isNotEmpty;

  @widgetFactory
  Widget? _buildTagDisplayFoldout(
    BuildContext context,
    TextStyle headerStyle,
    TagCategory? category,
  ) {
    return _willTagDisplayBeNonNull(category)
        ? ExpansionTile(
            initiallyExpanded: PostView.i.startWithTagsExpanded,
            title: _buildTagDisplayHeader(context, headerStyle, category!),
            dense: true,
            expandedAlignment: Alignment.centerLeft,
            children: _buildTagDisplayList(
              context,
              headerStyle,
              category,
            ).toList(growable: false),
          )
        : null;
  }

  @widgetFactory
  Widget _buildTagDisplayHeader(
    BuildContext context,
    TextStyle headerStyle,
    TagCategory category,
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
    TagCategory category,
  ) {
    if (!pvs.colorTags) headerStyle.copyWith(color: null);
    return e6Post.tags.getByCategory(category).map((e) => Align(
          widthFactor: 1,
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => showTagDialog(e, context),
            child: Text(e),
          ),
        ));
  }

  void showTagDialog(String tag, BuildContext cxt) {
    showDialog(
      context: cxt,
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
                    widget.tagsToAdd?.add(tag);
                    Navigator.pop(context);
                  },
                ),
                if (!(AppSettings.i?.blacklistedTags.contains(tag) ?? true))
                  ListTile(
                    title: const Text("Add to blacklist"),
                    onTap: () {
                      AppSettings.i?.blacklistedTags.add(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (AppSettings.i?.blacklistedTags.contains(tag) ?? false)
                  ListTile(
                    title: const Text("Remove from blacklist"),
                    onTap: () {
                      AppSettings.i?.blacklistedTags.remove(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (!(AppSettings.i?.favoriteTags.contains(tag) ?? true))
                  ListTile(
                    title: const Text("Add to favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.add(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (AppSettings.i?.favoriteTags.contains(tag) ?? false)
                  ListTile(
                    title: const Text("Remove from favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.remove(tag);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(context);
                    },
                  ),
                if (!SavedDataE6.all.any((e) =>
                    e.searchString.replaceAll(
                      RegExpExt.whitespace,
                      "",
                    ) ==
                    tag))
                  ListTile(
                    title: const Text("Add to saved searches"),
                    onTap: () {
                      Navigator.pop(context);
                      showSavedElementEditDialogue(
                        context,
                      ).then((value) {
                        if (value != null) {
                          SavedDataE6.addAndSaveSearch(
                            SavedSearchData.fromTagsString(
                              searchString: value.mainData,
                              title: value.title,
                              uniqueId: value.uniqueId ?? "",
                              parent: value.parent ?? "",
                            ),
                          );
                        }
                      });
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  title: const Text("Add to clipboard"),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tag)).then((v) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("$tag added to clipboard."),
                      ));
                      Navigator.pop(context);
                    });
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
