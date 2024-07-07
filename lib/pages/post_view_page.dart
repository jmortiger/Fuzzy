import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
import 'package:j_util/e621.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';

import '../web/e621/e621.dart';
import '../widgets/w_fab_builder.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("PostViewPage");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

abstract interface class IReturnsTags {
  List<String>? get tagsToAdd;
}

bool overrideQuality = true;

/// TODO: Expansion State Preservation on scroll
class PostViewPage extends StatelessWidget
    implements IReturnsTags, IRoute<PostViewPage> {
  static const routeNameString = "/post";
  @override
  get routeName => routeNameString;
  final PostListing postListing;
  final void Function(String addition)? onAddToSearch;
  final void Function()? onPop;
  @override
  final List<String>? tagsToAdd;
  const PostViewPage({
    super.key,
    required this.postListing,
    this.onAddToSearch,
    this.onPop,
    this.tagsToAdd,
  });
  E6PostResponse get e6Post => postListing as E6PostResponse;
  PostView get pvs => AppSettings.i!.postView;
  static final descriptionTheme = LateFinal<TextStyle>();
  @override
  Widget build(BuildContext context) {
    descriptionTheme.itemSafe ??=
        const DefaultTextStyle.fallback().style.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12 * 1.5,
            );
    var horizontalPixels = MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    // var IImageInfo(width: w, height: h, url: url) = postListing.sample;
    var IImageInfo(width: w, height: h, url: url) = postListing.file.isAVideo
        ? switch (PostView.i.imageQuality) {
            "low" => (e6Post.sample.alternates!.alternates["480p"] ??
                e6Post.sample.alternates!.alternates["720p"] ??
                e6Post.sample.alternates!.alternates["original"])!,
            "medium" => (e6Post.sample.alternates!.alternates["720p"] ??
                e6Post.sample.alternates!.alternates["original"])!,
            "high" => e6Post.sample.alternates!.alternates["original"]!,
            _ => throw UnsupportedError("type not supported"),
          }
        : postListing.file.extension == "gif" &&
                e6Post.tags.meta.contains("animated")
            ? e6Post.file
            : switch (PostView.i.imageQuality) {
                "low" => e6Post.preview,
                "medium" => e6Post.sample,
                "high" => e6Post.file,
                _ => throw UnsupportedError("type not supported"),
              };
    if (!postListing.file.isAVideo && w > horizontalPixels) {
      if (e6Post.preview.width > horizontalPixels) {
        IImageInfo(width: w, height: h, url: url) = postListing.preview;
      } else if (e6Post.sample.width > horizontalPixels) {
        IImageInfo(width: w, height: h, url: url) = postListing.sample;
      }
    }
    // if (!postListing.file.isAVideo && /* w < horizontalPixels &&  */
    //     pvs.forceHighQualityImage) {
    //   IImageInfo(width: w, height: h, url: url) = postListing.file;
    // }
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
            WPostViewBackButton(
                onPop: onPop ?? () => Navigator.pop(context, this)),
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
    return ListView(
      // padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: pvs.allowOverflow
                ? MediaQuery.of(context).size.width
                : (MediaQuery.of(context).size.height / h) * w.toDouble(),
            maxHeight: pvs.allowOverflow
                ? (MediaQuery.of(context).size.width / w) * h.toDouble()
                : MediaQuery.of(context).size.height,
          ),
          child: AspectRatio(
            aspectRatio: w / h,
            child: _buildMainContent(url, w, h, context),
          ),
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
                                logger.severe("Failed: ${snapshot.data}", e, s);
                                return Scaffold(
                                  appBar: AppBar(),
                                  body: Text("$e\n$s\n${snapshot.data}"),
                                );
                              }
                            } else if (snapshot.hasError) {
                              logger.severe(
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
              title: Text("Description", style: descriptionTheme.$),
            ),
            initiallyExpanded: PostView.i.startWithDescriptionExpanded,
            children: [SelectableText(e6Post.description)],
          ),
        ..._buildTagsDisplay(context),
      ],
    );
  }

  @widgetFactory
  Widget _buildMainContent(String url, int w, int h, BuildContext ctx) {
    return postListing.file.isAVideo
        ? WVideoPlayerScreen(
            resourceUri: Uri.tryParse(url) ?? postListing.file.address)
        : /* Platform.isWeb
            ? _createHtmlImageElement(url, w, h)
            :  */
        Image.network(
            url,
            errorBuilder: (context, error, stackTrace) => throw error,
            fit: BoxFit.contain,
            width: w.toDouble(),
            height: h.toDouble(),
            cacheWidth: min(w, MediaQuery.sizeOf(ctx).width.toInt()),
            // cacheHeight: h,
          );
  }

  static final headerStyle = LateFinal<TextStyle>();
  @widgetFactory
  Iterable<Widget> _buildTagsDisplay(BuildContext context) {
    headerStyle.itemSafe ??= descriptionTheme.$.copyWith(
      // color: Colors.amber,
      decoration: TextDecoration.underline,
      // decorationStyle: TextDecorationStyle.solid,
    );
    var tagOrder = pvs.tagOrder;
    return [
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(0)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(0)],
          ),
          tagOrder.elementAtOrNull(0),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(1)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(1)],
          ),
          tagOrder.elementAtOrNull(1),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(2)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(2)],
          ),
          tagOrder.elementAtOrNull(2),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(3)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(3)],
          ),
          tagOrder.elementAtOrNull(3),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(4)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(4)],
          ),
          tagOrder.elementAtOrNull(4),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(5)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(5)],
          ),
          tagOrder.elementAtOrNull(5),
        )!,
      if (_willTagDisplayBeNonNull(tagOrder.elementAtOrNull(6)))
        _buildTagDisplayFoldout(
          context,
          headerStyle.$.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(6)],
          ),
          tagOrder.elementAtOrNull(6),
        )!,
    ];
  }

  @widgetFactory
  Iterable<Widget>? _buildTagDisplay(
    BuildContext context,
    TextStyle headerStyle,
    TagCategory? category,
  ) {
    return _willTagDisplayBeNonNull(category)
        ? [
            _buildTagDisplayHeader(context, headerStyle, category!),
            ..._buildTagDisplayList(context, headerStyle, category),
          ]
        : null;
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
                Text(tag, style: headerStyle.$),
                ListTile(
                  title: const Text("Add to search"),
                  onTap: () {
                    onAddToSearch?.call(tag);
                    tagsToAdd?.add(tag);
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

  @widgetFactory
  HtmlElementView _createHtmlImageElement(String url, int w, int h) {
    return HtmlElementView(
      viewType: "imgPostTile",
      // creationParams: ,
      onPlatformViewCreated: (id) {
        // https://api.flutter.dev/flutter/dart-html/ImageElement-class.html
        var e = ui_web.getViewById(id) as dynamic; //ImageElement
        e.attributes["src"] = url;
        // https://api.flutter.dev/flutter/dart-html/CssStyleDeclaration-class.html
        e.style.width = "100%";
        e.style.height = "auto";
        e.style.maxWidth = "100%";
        e.style.maxHeight = "100%";
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
      child: IconButton(
        onPressed: () {
          if (onPop != null) {
            onPop!();
          } else {
            Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.arrow_back),
        iconSize: 36,
        style: const ButtonStyle(
          backgroundColor: WidgetStateColor.transparent,
          elevation: WidgetStatePropertyAll(15),
          shadowColor: WidgetStatePropertyAll(Colors.black),
        ),
      ),
    );
  }
}
