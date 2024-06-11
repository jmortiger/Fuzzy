import 'package:flutter/material.dart';
import 'package:fuzzy/widgets/w_video_player_screen.dart';
// import 'package:fuzzy/util/util_platform_web.dart' as ui_web;
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
  @override
  Widget build(BuildContext context) {
    var headerStyle =
        const DefaultTextStyle.fallback().style.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.solid,
              fontSize: (const DefaultTextStyle.fallback().style.fontSize ?? 12) * 1.5,
            );
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
              maxWidth: MediaQuery.of(context).size.width,
              maxHeight: (MediaQuery.of(context).size.width / w) * h.toDouble(),
            ),
            child: AspectRatio(
              aspectRatio: w / h,
              child: _buildMainContent(url, w, h),
            ),
          ),
          Text(
            "Artist",
            style: headerStyle,
          ),
          ...e6Post.tags.artist.map((e) => SelectableText(e)),
          // ListView.builder(
          //   itemBuilder: (BuildContext context, int index) {
          //     return e6Post.tags.artist.length > index
          //         ? Text(e6Post.tags.artist[index])
          //         : null;
          //   },
          // ),
          Text(
            "Species",
            style: headerStyle,
          ),
          ...e6Post.tags.species.map((e) => SelectableText(e)),
          // ListView.builder(
          //   itemBuilder: (BuildContext context, int index) {
          //     return e6Post.tags.species.length > index
          //         ? Text(e6Post.tags.species[index])
          //         : null;
          //   },
          // ),
          Text(
            "Copyright",
            style: headerStyle,
          ),
          ...e6Post.tags.copyright.map((e) => SelectableText(e)),
          // ListView.builder(
          //   itemBuilder: (BuildContext context, int index) {
          //     return e6Post.tags.copyright.length > index
          //         ? Text(e6Post.tags.copyright[index])
          //         : null;
          //   },
          // ),
          Text(
            "General",
            style: headerStyle,
          ),
          ...e6Post.tags.general.map((e) => SelectableText(e)),
          // ListView.builder(
          //   itemBuilder: (BuildContext context, int index) {
          //     return e6Post.tags.general.length > index
          //         ? Text(e6Post.tags.general[index])
          //         : null;
          //   },
          // ),
          Text(
            "Lore",
            style: headerStyle,
          ),
          ...e6Post.tags.lore.map((e) => SelectableText(e)),
          // ListView.builder(
          //   itemBuilder: (BuildContext context, int index) {
          //     return e6Post.tags.lore.length > index
          //         ? Text(e6Post.tags.lore[index])
          //         : null;
          //   },
          // ),
          Text(
            "Meta",
            style: headerStyle,
          ),
          ...e6Post.tags.meta.map((e) => SelectableText(e)),
          // ListView.builder(
          //   itemBuilder: (BuildContext context, int index) {
          //     return e6Post.tags.meta.length > index
          //         ? Text(e6Post.tags.meta[index])
          //         : null;
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildMainContent(String url, int w, int h) {
    return postListing.file.isAVideo
        ? WVideoPlayerScreen(
            resourceUri: postListing.file.address,
          )
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
  HtmlElementView _createHtmlImageElement(String url, int w, int h) {
    return HtmlElementView(
      viewType: "imgPostTile",
      // creationParams: ,
      onPlatformViewCreated: (id) {
        // https://api.flutter.dev/flutter/dart-html/ImageElement-class.html
        var e = ui_web.getViewById(id) as dynamic; //ImageElement
        e.attributes["src"] = url;
        // https://api.flutter.dev/flutter/dart-html/CssStyleDeclaration-class.html
        // if (imageFit == BoxFit.contain) {
        //   if (w > h) {
        //     e.style.width = "100%";
        //     e.style.height = "auto";
        //   } else if (w == h) {
        //     e.style.width = "100%";
        //     e.style.height = "100%";
        //   } else {
        //     e.style.width = "auto";
        //     e.style.height = "100%";
        //   }
        //   e.style.maxWidth = "100%";
        //   e.style.maxHeight = "100%";
        //   e.style.objectFit = "contain";
        //   print("Trying to contain");
        //   // e.style.aspectRatio = "${w / h}";
        // } else /* if (imageFit == BoxFit.cover) */ {
        // if (w > h) {
        //   e.style.width = "auto";
        //   e.style.height = "100%";
        // } else if (w == h) {
        //   e.style.width = "100%";
        //   e.style.height = "100%";
        // } else {
        e.style.width = "100%";
        e.style.height = "auto";
        // }
        e.style.maxWidth = "100%";
        e.style.maxHeight = "100%";
        // e.style.objectFit = "cover";
        // print("Trying to cover");
        // e.style.aspectRatio = "${w / h}";
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
