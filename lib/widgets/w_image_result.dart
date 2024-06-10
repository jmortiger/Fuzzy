import 'package:flutter/material.dart';
// import 'package:fuzzy/util/util_platform_web.dart' as ui_web;
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/widgets/w_post_view.dart';
import 'package:j_util/platform_finder.dart';

import '../web/models/image_listing.dart';

BoxFit imageFit = BoxFit.contain;

// TODO: Fade in images https://docs.flutter.dev/cookbook/images/fading-in-images
class WImageResult extends StatelessWidget {
  final PostListing imageListing;
  final int index;
  final bool isSelected;

  final String searchText;

  final void Function(int index)? onSelectionToggle;

  const WImageResult({
    super.key,
    required this.imageListing,
    this.index = -1,
    this.searchText = "",
    this.onSelectionToggle,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    int w, h;
    String url;
    if (Platform.isAndroid || Platform.isIOS) {
      IImageInfo(width: w, height: h, url: url) = imageListing.preview;
    } else if (imageListing.sample.has &&
        imageListing.sample.width > imageListing.preview.width) {
      IImageInfo(width: w, height: h, url: url) = imageListing.sample;
    } else {
      IImageInfo(width: w, height: h, url: url) = imageListing.file;
    }
    print("$searchText[$index]: w: $w, "
        "h: $h, "
        "sampleWidth: ${imageListing.sample.width}, "
        "fileWidth: ${imageListing.file.width}");
    return Stack(
      children: [
        // _buildActionChip(context, w, h, url),
        _buildWithInputDetector(context, w, h, url),
        PostInfoPane(post: imageListing),
        if (isSelected) _buildCheckmark(context)
      ],
    );
  }

  Widget _buildCheckmark(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      // heightFactor: 6,
      // widthFactor: 6,
      child: Icon(
        Icons.check,
        color: Colors.green,
        opticalSize: (IconTheme.of(context).opticalSize ?? 48) * 6,
        size: (IconTheme.of(context).size ?? 24) * 6,
      ),
    );
  }

  InkWell _buildWithInputDetector(
      BuildContext context, int w, int h, String url) {
    return InkWell(
      // onHover: (value) {
      //   // tooltip: _buildTooltipString,
      // },
      onLongPress: () {
        print("OnLongPress");
        /* if (!isSelected)  */onSelectionToggle?.call(index);
      },
      // onDoubleTap: () {
      //   print("onDoubleTap");
      //   /* if (!isSelected)  */onSelectionToggle?.call(index);
      // },
      onTap: () {
        print("OnTap");
        if (isSelected) {
          onSelectionToggle?.call(index);
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WPostView(postListing: imageListing),
              ));
        }
      },
      // TODO: Fix vertical image offset
      child: _buildPane(w, h, url),
    );
  }

  ActionChip _buildActionChip(BuildContext context, int w, int h, String url) {
    return ActionChip(
      tooltip: _buildTooltipString,
      onPressed: () {
        print("OnPressed");
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: ((context) => WPostView(postListing: imageListing))));
      },
      // TODO: Fix vertical image offset
      label: _buildPane(w, h, url),
    );
  }

  Center _buildPane(int w, int h, String url) {
    return Center(
      child: AspectRatio(
        aspectRatio: w / h,
        child: Platform.isWeb
            ? _createHtmlImageElement(url, w, h)
            : Image.network(
                url,
                errorBuilder: (context, error, stackTrace) => throw error,
                fit: BoxFit.contain,
                width: w.toDouble(),
                height: h.toDouble(),
                cacheWidth: w,
                cacheHeight: h,
              ),
      ),
    );
  }

  String get _buildTooltipString =>
      "$searchText[$index]: ${(imageListing as E6PostResponse).id.toString()}";

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
        if (imageFit == BoxFit.contain) {
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
          e.style.maxWidth = "100%";
          e.style.maxHeight = "100%";
          e.style.objectFit = "contain";
          print("Trying to contain");
          // e.style.aspectRatio = "${w / h}";
        } else /* if (imageFit == BoxFit.cover) */ {
          if (w > h) {
            e.style.width = "auto";
            e.style.height = "100%";
          } else if (w == h) {
            e.style.width = "100%";
            e.style.height = "100%";
          } else {
            e.style.width = "100%";
            e.style.height = "auto";
          }
          e.style.maxWidth = "100%";
          e.style.maxHeight = "100%";
          e.style.objectFit = "cover";
          print("Trying to cover");
          // e.style.aspectRatio = "${w / h}";
        }
      },
    );
  }
}

class PostInfoPane extends StatelessWidget {
  final PostListing post;
  E6PostResponse get e6Post => post as E6PostResponse;
  E6PostResponse? get e6PostSafe =>
      post.runtimeType == E6PostResponse ? post as E6PostResponse : null;

  const PostInfoPane({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          /* minWidth: 70,
          minHeight: 20, */
          maxWidth: 150,
          maxHeight: 150,
        ),
        child: Container(
          height: 20,
          color: const Color.fromARGB(149, 46, 46, 46),
          child: Text.rich(
            TextSpan(
              text: "${e6Post.file.ext} ${e6Post.score.total} (",
              children: [
                // const TextSpan(text: "U: "),
                TextSpan(
                    text: "${e6Post.score.up}",
                    style: const TextStyle(
                      color: Colors.green,
                      decoration: TextDecoration.underline,
                    )),
                const TextSpan(text: ", "),
                // const TextSpan(text: " D: "),
                TextSpan(
                    text: "${e6Post.score.down}",
                    style: const TextStyle(
                      color: Colors.red,
                      decoration: TextDecoration.underline,
                    )),
                const TextSpan(text: ")"),
                if (e6PostSafe?.relationships.hasParent ?? false)
                  const TextSpan(
                      text: " P",
                      style: TextStyle(
                        color: Colors.amber,
                        decoration: TextDecoration.underline,
                      )),
                if (e6PostSafe?.relationships.hasChildren ?? false)
                  TextSpan(
                      text: " C(${e6Post.relationships.children.length})",
                      style: const TextStyle(
                        color: Colors.amber,
                        decoration: TextDecoration.underline,
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
