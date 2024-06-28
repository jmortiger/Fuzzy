import 'package:flutter/material.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/post_swipe_page.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:j_util/platform_finder.dart';
import 'package:provider/provider.dart';

import '../web/models/image_listing.dart';

BoxFit imageFit = BoxFit.contain;
const bool allowPostViewNavigation = true;

// TODO: Fade in images https://docs.flutter.dev/cookbook/images/fading-in-images
class WImageResult extends StatelessWidget {
  final PostListing imageListing;
  final int index;
  final bool isSelected;
  final bool areAnySelected;

  // final String searchText;

  final void Function(int index)? onSelectionToggle;

  const WImageResult({
    super.key,
    required this.imageListing,
    required this.index,
    // this.searchText = "",
    this.onSelectionToggle,
    this.isSelected = false,
    this.areAnySelected = false,
  });

  String get _buildTooltipString =>
      /* $searchText */ "[$index]: ${(imageListing as E6PostResponse).id.toString()}";

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
    print(/* $searchText */ "[$index]: w: $w, "
        "h: $h, "
        "sampleWidth: ${imageListing.sample.width}, "
        "fileWidth: ${imageListing.file.width}, "
        "url: $url");
    return Stack(
      children: [
        // _buildActionChip(context, w, h, url),
        // _buildWithInputDetector(context, w, h, url),
        _buildPane(w, h, url),
        PostInfoPane(post: imageListing),
        if (isSelected) _buildCheckmark(context),
        _buildInputDetector(context, w, h, url),
      ],
    );
  }

  @widgetFactory
  Widget _buildCheckmark(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: AlignmentDirectional.bottomEnd,
        // heightFactor: 6,
        // widthFactor: 6,
        child: Icon(
          Icons.check,
          color: Colors.green,
          opticalSize: (IconTheme.of(context).opticalSize ?? 48) * 6,
          size: (IconTheme.of(context).size ?? 24) * 6,
        ),
      ),
    );
  }

  SearchResults sr(BuildContext context) =>
      Provider.of<SearchResults>(context, listen: false);

  SearchResults srl(BuildContext context) =>
      Provider.of<SearchResults>(context);

  // bool returnedFromPosts = false;

  Widget _buildInputDetector(BuildContext context, int w, int h, String url) {
    // SearchResults sr() => Provider.of<SearchResults>(context, listen: false);
    SearchResults srl = Provider.of<SearchResults>(context);
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // onHover: (value) {
          //   // tooltip: _buildTooltipString,
          // },
          onLongPress: () {
            print("OnLongPress");
            onSelectionToggle?.call(index);
            srl.toggleSelection(
              index: index,
              postId: imageListing.id,
            );
          },
          onDoubleTap: () {
            print("onDoubleTap");
            onSelectionToggle?.call(index);
            srl.toggleSelection(
              index: index,
              postId: imageListing.id,
            );
          },
          onTap: () {
            print("OnTap");
            if ((isSelected || areAnySelected) ||
                (srl.getIsSelected(index) || srl.areAnySelected)) {
              onSelectionToggle?.call(index);
              srl.toggleSelection(
                index: index,
                postId: imageListing.id,
              );
            } else {
              onAddToSearch(String addition) {
                print("WImageResult: onAddToSearch:");
                print("Before: ${Provider.of<SearchViewModel>(
                  context,
                  listen: false,
                ).searchText}");
                Provider.of<SearchViewModel>(
                  context,
                  listen: false,
                ).fillTextBarWithSearchString = true;
                print(
                    "After: ${Provider.of<SearchViewModel>(context, listen: false).searchText += " $addition"}");
              }

              Navigator.push<IReturnsTags>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => allowPostViewNavigation
                        ? PostSwipePage(
                            initialIndex: index,
                            posts:
                                Provider.of<SearchCache>(context, listen: false)
                                    .posts!,
                            onAddToSearch: onAddToSearch,
                            tagsToAdd: [],
                          )
                        : PostViewPage(
                            postListing: imageListing,
                            onAddToSearch: onAddToSearch,
                            tagsToAdd: [],
                          ),
                  )).then<void>((v) {
                if (v?.tagsToAdd?.firstOrNull != null) {
                  Provider.of<SearchViewModel>(
                    context,
                    listen: false,
                  ).searchText += v!.tagsToAdd!.foldToString();
                }
              });
            }
          },
        ),
      ),
    );
  }

  @widgetFactory
  Center _buildPane(int w, int h, String url) {
    if (url == "") {
      print("NO URL");
    }
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
          // print("Trying to contain");
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
          e.style.minWidth = "100%";
          e.style.minHeight = "100%";
          e.style.maxWidth = "100vw";
          e.style.maxHeight = "100vh";
          e.style.objectFit = "cover";
          // print("Trying to cover");
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
              text: " ",
              children: [
                TextSpan(
                    text: "${e6Post.rating.toUpperCase()} ",
                    style: TextStyle(
                      color: switch (e6Post.rating) {
                        "s" => Colors.green,
                        "q" => Colors.amber,
                        "e" => Colors.red,
                        _ => throw UnsupportedError("type not supported"),
                      },
                      fontWeight: FontWeight.bold,
                    )),
                TextSpan(
                  text: "${e6Post.file.ext} ${e6Post.score.total} (",
                ),
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
                if (e6PostSafe?.isFavorited ?? false)
                  const TextSpan(
                      text: " ♥",
                      style: TextStyle(
                        color: Colors.red,
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
