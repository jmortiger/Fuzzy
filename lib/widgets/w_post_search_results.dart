// import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:j_util/j_util_full.dart';

class WPostSearchResultsFuture extends StatefulWidget {
  final Future<E6Posts> posts;
  const WPostSearchResultsFuture({
    super.key,
    required this.posts,
  });

  @override
  State<WPostSearchResultsFuture> createState() =>
      _WPostSearchResultsFutureState();
}

class _WPostSearchResultsFutureState extends State<WPostSearchResultsFuture> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<E6Posts>(
      future: widget.posts,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _makeGridView(snapshot.data!);
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return const AspectRatio(
          aspectRatio: 1,
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}

class WPostSearchResults extends StatelessWidget {
  final E6Posts posts;
  const WPostSearchResults({
    super.key,
    required this.posts,
  });
  @override
  Widget build(BuildContext context) {
    return _makeGridView(posts);
  }
}

GridView _makeGridView(E6Posts posts) => GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemBuilder: (context, index) {
        if (Platform.isWeb) {
          var data = posts.tryGet(index);
          return data == null
              ? null
              : AspectRatio(
                  aspectRatio: data.imagePreviewWidth / data.imagePreviewHeight,
                  child: HtmlElementView.fromTagName(
                    tagName: "img",
                    onElementCreated: (element) {
                      // https://api.flutter.dev/flutter/dart-html/ImageElement-class.html
                      var e = element as dynamic; //ImageElement
                      e.attributes["src"] = data.imagePreviewUrl;
                      // https://api.flutter.dev/flutter/dart-html/CssStyleDeclaration-class.html
                      e.style.width = "${data.imagePreviewWidth}px";
                      e.style.height = "${data.imagePreviewHeight}px";
                      e.style.aspectRatio = "${data.imagePreviewWidth / data.imagePreviewHeight}";
                    },
                  ),
                );
        } else {
          var data = posts.tryGet(index);
          return data == null
              ? null
              : AspectRatio(
                aspectRatio: data.imagePreviewWidth / data.imagePreviewHeight,
                child: Image.network(
                    posts[index].imagePreviewUrl,
                    errorBuilder: (context, error, stackTrace) => throw error,
                    fit: BoxFit.contain,
                    width: data.imagePreviewWidth.toDouble(),
                    height: data.imagePreviewHeight.toDouble(),
                    cacheWidth: data.imagePreviewWidth,
                    cacheHeight: data.imagePreviewHeight,
                  ),
              );
        }
      },
    );
