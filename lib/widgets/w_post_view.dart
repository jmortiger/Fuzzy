import 'package:flutter/material.dart';
import 'package:fuzzy/app_settings.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:j_util/platform_finder.dart';

class WPostView extends StatelessWidget {
  final PostListing postListing;
  const WPostView({
    super.key,
    required this.postListing,
  });
  E6PostResponse get e6Post => postListing as E6PostResponse;
  PostView get pvs => AppSettings.i.postView;
  @override
  Widget build(BuildContext context) {
    var IImageInfo(width: w, height: h, url: url) = postListing.file;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fuzzy"),
      ),
      body: ListView(
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
              child: _buildMainContent(url, w, h),
            ),
          ),
          ..._buildTagsDisplay(context),
        ],
      ),
    );
  }

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
              color: pvs.tagColors[tagOrder.elementAtOrNull(0)]),
          tagOrder.elementAtOrNull(0)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
              color: pvs.tagColors[tagOrder.elementAtOrNull(1)]),
          tagOrder.elementAtOrNull(1)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
              color: pvs.tagColors[tagOrder.elementAtOrNull(2)]),
          tagOrder.elementAtOrNull(2)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
              color: pvs.tagColors[tagOrder.elementAtOrNull(3)]),
          tagOrder.elementAtOrNull(3)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
              color: pvs.tagColors[tagOrder.elementAtOrNull(4)]),
          tagOrder.elementAtOrNull(4)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
              color: pvs.tagColors[tagOrder.elementAtOrNull(5)]),
          tagOrder.elementAtOrNull(5)),
      ...?_buildTagDisplay(
          context,
          headerStyle.copyWith(
              color: pvs.tagColors[tagOrder.elementAtOrNull(6)]),
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
    return e6Post.tags.getByCategory(category).map((e) => SelectableText(e));
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

  HtmlElementView _oldImg(String url, int w, int h) {
    return HtmlElementView.fromTagName(
      tagName: "img",
      onElementCreated: (element) {
        // https://api.flutter.dev/flutter/dart-html/ImageElement-class.html
        var e = element as dynamic; //ImageElement
        e.attributes["src"] = url;
        // https://api.flutter.dev/flutter/dart-html/CssStyleDeclaration-class.html
        if (w > h) {
          e.style.width = "100%";
          e.style.height = "auto";
        } else if (w == h) {
          e.style.width = "100%";
          e.style.height = "100%";
        } else {
          e.style.width = "auto";
          e.style.height = "100%";
        }
        // e.style.maxWidth = "100%";
        // e.style.maxHeight = "100%";
        e.style.objectFit = "contain";
        // e.style.aspectRatio = "${w / h}";
      },
    );
  }
}
