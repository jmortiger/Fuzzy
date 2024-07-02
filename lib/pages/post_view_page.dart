import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/pages/pool_view_page.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
import 'package:http/http.dart';
import 'package:j_util/e621.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';

import '../web/e621/e621.dart';
import '../widgets/w_fab_builder.dart';

import 'package:fuzzy/log_management.dart' as lm;

final print = lm.genPrint("PostViewPage");

abstract interface class IReturnsTags {
  List<String>? get tagsToAdd;
}

/// TODO: Expansion State Preservation on scroll
class PostViewPage extends StatelessWidget implements IReturnsTags {
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
    descriptionTheme.itemSafe ??= const DefaultTextStyle.fallback()
        .style
        .copyWith(
          fontWeight: FontWeight.bold,
          fontSize:
              (const DefaultTextStyle.fallback().style.fontSize ?? 12) * 1.5,
        );
    var horizontalPixels = MediaQuery.of(context).size.width *
        MediaQuery.of(context).devicePixelRatio;
    var IImageInfo(width: w, height: h, url: url) = postListing.sample;
    if (postListing.sample.width < horizontalPixels ||
        pvs.forceHighQualityImage) {
      IImageInfo(width: w, height: h, url: url) = postListing.file;
    }
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              // padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: pvs.allowOverflow
                        ? MediaQuery.of(context).size.width
                        : (MediaQuery.of(context).size.height / h) *
                            w.toDouble(),
                    maxHeight: pvs.allowOverflow
                        ? (MediaQuery.of(context).size.width / w) * h.toDouble()
                        : MediaQuery.of(context).size.height,
                  ),
                  child: AspectRatio(
                    aspectRatio: w / h,
                    child: _buildMainContent(url, w, h),
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
                                      .then((v) =>
                                          jsonDecode((v as Response).body)),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      try {
                                        return PostViewPage(
                                          postListing: E6PostResponse.fromJson(
                                            snapshot.data["posts"],
                                          ),
                                        );
                                      } catch (e) {
                                        return Scaffold(
                                          body: Text(
                                            "$e\n${snapshot.data}",
                                          ),
                                        );
                                      }
                                    } else if (snapshot.hasError) {
                                      return Scaffold(
                                        body: Text("${snapshot.error}"),
                                      );
                                    } else {
                                      return const Scaffold(
                                        body: CircularProgressIndicator(),
                                      );
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
                    ...e6Post.pools.map(
                      (e) => TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FutureBuilder(
                                  future: E621
                                      .sendRequest(Api.initSearchPoolsRequest(
                                          searchId: [e]))
                                      .toResponse()
                                      .then((v) =>
                                          jsonDecode(v.body))
                                      .then(
                                        (v) => PoolViewPage(
                                          pool: PoolModel.fromJson(
                                            v[0],
                                          ),
                                        ),
                                      ) /* .catchError((element) => Scaffold(
                                          body: Text("$e\n${element}"),
                                        )) */
                                  ,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      try {
                                        return snapshot.data!;
                                      } catch (e, s) {
                                        return Scaffold(
                                          body: Text(
                                              "$e\n$s\n${snapshot.data}\n${snapshot.error}\n${snapshot.stackTrace}"),
                                        );
                                      }
                                    } else if (snapshot.hasError) {
                                      return Scaffold(
                                        body: Text(
                                            "${snapshot.error}\n${snapshot.stackTrace}"),
                                      );
                                    } else {
                                      return Scaffold(
                                        appBar: AppBar(
                                          title: Text("Pool $e"),
                                        ),
                                        body: const Column(
                                          children: [
                                            Expanded(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          child: Text(e.toString())),
                    ),
                  ]),
                if (e6Post.description.isNotEmpty)
                  ExpansionTile(
                    title: ListTile(
                      title: Text(
                        "Description",
                        style: descriptionTheme.$,
                      ),
                    ),
                    initiallyExpanded: PostView.i.startWithDescriptionExpanded,
                    children: [SelectableText(e6Post.description)],
                  ),
                ..._buildTagsDisplay(context),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.topStart,
              child: IconButton(
                onPressed: () {
                  if (onPop != null) {
                    onPop!();
                  } else {
                    Navigator.pop(context, this);
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
            ),
          ],
        ),
      ),
      floatingActionButton:
          WFabBuilder.singlePost(post: e6Post), //_buildFab(context),
    );
  }

  ExpandableFab _buildFab(BuildContext context) {
    return ExpandableFab(
      distance: 112,
      children: [
        ActionButton(
          icon: const Icon(Icons.add),
          tooltip: "Add to set",
          onPressed: () async {
            print("Adding ${postListing.id} to a set");
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(content: Text("To Be Implemented")),
            // );
            var v = await showDialog<e621.PostSet>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: WSearchSet(
                    initialLimit: 10,
                    initialPage: null,
                    initialSearchCreatorName: "***REMOVED***,
                    initialSearchOrder: e621.SetOrder.updatedAt,
                    initialSearchName: null,
                    initialSearchShortname: null,
                    onSelected: (e621.PostSet set) =>
                        Navigator.pop(context, set),
                  ),
                  // scrollable: true,
                );
              },
            );
            if (v != null) {
              print("Adding ${postListing.id} to set ${v.id}");
              var res = await E621
                  .sendRequest(e621.Api.initAddToSetRequest(
                    v.id,
                    [postListing.id],
                    credentials: (E621.accessData.itemSafe ??=
                            await E621AccessData.devAccessData.getItem())
                        .cred,
                  ))
                  .toResponse() as Response;
              if (res.statusCode == 201) {
                print("${postListing.id} successfully added to set ${v.id}");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "${postListing.id} successfully added to set ${v.id}"),
                      action: SnackBarAction(
                        label: "See Set",
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(),
                              body: WPostSearchResults.directResultFromSearch(
                                "set:${v.shortname}",
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
              return;
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No Set Selected, canceling.")),
              );
              return;
            } else {
              return;
            }
          },
        ),
        if (!e6Post.isFavorited)
          ActionButton(
            icon: const Icon(Icons.favorite),
            tooltip: "Add to favorites",
            onPressed: () async {
              print("Adding ${e6Post.id} to favorites...");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Adding ${e6Post.id} to favorites...")),
              );
              var t = E621.sendRequest(
                E621.initAddFavoriteRequest(
                  e6Post.id,
                  username: E621AccessData.devUsername,
                  apiKey: E621AccessData.devApiKey,
                ),
              );
              t.then(
                (v) => v.stream.listen(
                  null,
                  onDone: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${v.statusCode}: ${v.reasonPhrase}"),
                        action: SnackBarAction(
                          label: "Undo",
                          onPressed: () async {
                            try {
                              var newStream = E621.sendRequest(
                                E621.initDeleteFavoriteRequest(
                                  int.parse(
                                    v.request!.url.queryParameters["post_id"]!,
                                  ),
                                  username: E621AccessData.devUsername,
                                  apiKey: E621AccessData.devApiKey,
                                ),
                              );
                              newStream.then(
                                (value2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "${value2.statusCode}: ${value2.reasonPhrase}",
                                      ),
                                    ),
                                  );
                                },
                              );
                            } catch (e) {
                              print(e);
                              rethrow;
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ActionButton(
          icon: const Icon(Icons.delete),
          tooltip: "Remove selected from set",
          onPressed: () {
            print("To Be Implemented");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("To Be Implemented")),
            );
          },
        ),
        if (e6Post.isFavorited)
          ActionButton(
            icon: const Icon(Icons.heart_broken_outlined),
            tooltip: "Remove selected from favorites",
            onPressed: () async {
              print("Removing ${e6Post.id} from favorites...");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Removing ${e6Post.id} from favorites..."),
                ),
              );
              E621
                  .sendRequest(
                    E621.initDeleteFavoriteRequest(
                      e6Post.id,
                      username: E621AccessData.devUsername,
                      apiKey: E621AccessData.devApiKey,
                    ),
                  )
                  .toResponse()
                  .then(
                    (value) => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "${value.statusCode}: ${value.reasonPhrase}",
                        ),
                        action: SnackBarAction(
                          label: "Undo",
                          onPressed: () async {
                            var newStream = E621
                                .sendRequest(
                              E621.initAddFavoriteRequest(
                                int.parse(
                                  value.request!.url.pathSegments.last
                                      .substring(
                                    0,
                                    value.request!.url.pathSegments.last
                                        .indexOf("."),
                                  ),
                                ),
                                username: E621AccessData.devUsername,
                                apiKey: E621AccessData.devApiKey,
                              ),
                            )
                                .onError((error, stackTrace) {
                              print(error);
                              throw error!;
                            });
                            newStream.then(
                              (value2) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                    "${value2.statusCode}: ${value2.reasonPhrase}",
                                  ),
                                ));
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  )
                  .onError((error, stackTrace) {
                print(error);
                throw error!;
              });
            },
          ),
      ],
    );
  }

  // TODO: Use ExpansionPanelList & ExpansionPanel for tags https://api.flutter.dev/flutter/material/ExpansionPanelList-class.html
  @widgetFactory
  Widget _buildMainContent(String url, int w, int h) {
    return postListing.file.isAVideo
        ? WVideoPlayerScreen(resourceUri: postListing.file.address)
        : Platform.isWeb
            ? _createHtmlImageElement(url, w, h)
            : Image.network(
                url,
                errorBuilder: (context, error, stackTrace) => throw error,
                fit: BoxFit.contain,
                width: w.toDouble(),
                height: h.toDouble(),
                cacheWidth: w,
                cacheHeight: h,
              );
  }

  static final headerStyle = LateFinal<TextStyle>();
  @widgetFactory
  Iterable<Widget> _buildTagsDisplay(BuildContext context) {
    headerStyle.itemSafe ??= descriptionTheme.$.copyWith(
      color: Colors.amber,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.solid,
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
      BuildContext context, TextStyle headerStyle, TagCategory? category) {
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
      BuildContext context, TextStyle headerStyle, TagCategory? category) {
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
      BuildContext context, TextStyle headerStyle, TagCategory category) {
    if (!pvs.colorTagHeaders) headerStyle.copyWith(color: null);
    return Text(
      "${category.name[0].toUpperCase()}${category.name.substring(1)}",
      style: headerStyle,
    );
  }

  @widgetFactory
  Iterable<Widget> _buildTagDisplayList(
      BuildContext context, TextStyle headerStyle, TagCategory category) {
    if (!pvs.colorTags) headerStyle.copyWith(color: null);
    return e6Post.tags.getByCategory(category).map((e) => Align(
          widthFactor: 1,
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () {
              showTagDialog(e, context);
            },
            // onPressed: () {
            //   onAddToSearch?.call(e);
            //   tagsToAdd?.add(e);
            // },
            child: SelectableText(e),
          ),
        ));
    // ListView.builder(
    //   itemBuilder: (BuildContext context, int index) {
    //     return e6Post.tags.getByCategory(category).length > index
    //         ? Text(e6Post.tags.getByCategory(category)[index])
    //         : null;
    //   },
    // );
  }

  // @widgetFactory
  // AlertDialog
  void showTagDialog(String tag, BuildContext cxt) {
    showDialog(
      context: cxt,
      builder: (context) {
        return AlertDialog(
          content: ListBody(
            children: [
              ListTile(
                title: Text(tag),
              ),
              ListTile(
                title: const Text("Add to search"),
                onTap: () {
                  onAddToSearch?.call(tag);
                  tagsToAdd?.add(tag);
                  Navigator.pop(context);
                },
              ),
              if (!AppSettings.i!.blacklistedTags.contains(tag))
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
            ],
          ),
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
