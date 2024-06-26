import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
import 'package:j_util/j_util_widgets.dart';
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:j_util/platform_finder.dart';

import '../web/e621/e621.dart';

class PostViewPage extends StatelessWidget {
  // final List<PostListing>? next20;
  // final List<PostListing>? prev20;
  final PostListing postListing;
  final void Function(String addition)? onAddToSearch;
  const PostViewPage({
    super.key,
    required this.postListing,
    this.onAddToSearch,
    // this.next20,
    // this.prev20,
  });
  E6PostResponse get e6Post => postListing as E6PostResponse;
  PostView get pvs => AppSettings.i!.postView;
  @override
  Widget build(BuildContext context) {
    var IImageInfo(width: w, height: h, url: url) = postListing.file;
    return NavigatorPopHandler(
      onPop: () => Navigator.pop(
        context,
      ),
      child: Scaffold(
        // appBar: AppBar(title: const Text("Fuzzy")),
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
                          ? (MediaQuery.of(context).size.width / w) *
                              h.toDouble()
                          : MediaQuery.of(context).size.height,
                    ),
                    child: AspectRatio(
                      aspectRatio: w / h,
                      child: _buildMainContent(url, w, h),
                    ),
                  ),
                  SelectableText(e6Post.description),
                  ..._buildTagsDisplay(context),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.topStart,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  style: const ButtonStyle(
                    backgroundColor: WidgetStateColor.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFab(context),
      ),
    );
  }

  ExpandableFab _buildFab(BuildContext context) {
    return ExpandableFab(
      distance: 112,
      children: [
        ActionButton(
          icon: const Icon(Icons.add),
          tooltip: "Add to set",
          onPressed: () {
            print("To Be Implemented");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("To Be Implemented")),
            );
          },
        ),
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
            var t = E621.sendRequest(
              E621.initDeleteFavoriteRequest(
                e6Post.id,
                username: E621AccessData.devUsername,
                apiKey: E621AccessData.devApiKey,
              ),
            );
            t
                .then(
              (value) => value.stream.listen(
                null,
                onDone: () {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                                value.request!.url.pathSegments.last.substring(
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
                  );
                },
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

  @widgetFactory
  Iterable<Widget> _buildTagsDisplay(BuildContext context) {
    final headerStyle = const DefaultTextStyle.fallback().style.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.amber,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.solid,
          fontSize:
              (const DefaultTextStyle.fallback().style.fontSize ?? 12) * 1.5,
        );
    var tagOrder = pvs.tagOrder;
    return [
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(0)],
          ),
          tagOrder.elementAtOrNull(0)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(1)],
          ),
          tagOrder.elementAtOrNull(1)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(2)],
          ),
          tagOrder.elementAtOrNull(2)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(3)],
          ),
          tagOrder.elementAtOrNull(3)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(4)],
          ),
          tagOrder.elementAtOrNull(4)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(5)],
          ),
          tagOrder.elementAtOrNull(5)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
            color: pvs.tagColors[tagOrder.elementAtOrNull(6)],
          ),
          tagOrder.elementAtOrNull(6)),
    ];
  }

  @widgetFactory
  Iterable<Widget>? _buildTagDisplay(
      BuildContext context, TextStyle headerStyle, TagCategory? category) {
    return category != null && e6Post.tags.getByCategory(category).isNotEmpty
        ? [
            _buildTagDisplayHeader(context, headerStyle, category),
            ..._buildTagDisplayList(context, headerStyle, category),
          ]
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
            onPressed: () => onAddToSearch?.call(e),
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

  // @widgetFactory
  // HtmlElementView _oldImg(String url, int w, int h) {
  //   return HtmlElementView.fromTagName(
  //     tagName: "img",
  //     onElementCreated: (element) {
  //       // https://api.flutter.dev/flutter/dart-html/ImageElement-class.html
  //       var e = element as dynamic; //ImageElement
  //       e.attributes["src"] = url;
  //       // https://api.flutter.dev/flutter/dart-html/CssStyleDeclaration-class.html
  //       if (w > h) {
  //         e.style.width = "100%";
  //         e.style.height = "auto";
  //       } else if (w == h) {
  //         e.style.width = "100%";
  //         e.style.height = "100%";
  //       } else {
  //         e.style.width = "auto";
  //         e.style.height = "100%";
  //       }
  //       // e.style.maxWidth = "100%";
  //       // e.style.maxHeight = "100%";
  //       e.style.objectFit = "contain";
  //       // e.style.aspectRatio = "${w / h}";
  //     },
  //   );
  // }
}
