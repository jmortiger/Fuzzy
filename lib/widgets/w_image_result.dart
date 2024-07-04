import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/post_swipe_page.dart' as old;
import 'package:fuzzy/pages/post_swipe_page_redux.dart';
import 'package:j_util/j_util_full.dart';
import 'package:j_util/platform_finder.dart' as ui_web;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/pages/post_view_page.dart';
import 'package:provider/provider.dart';

import '../web/models/image_listing.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("WImageResult");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

BoxFit imageFit = BoxFit.cover;
const bool allowPostViewNavigation = true;
const bool useLinkedList = false;

// TODO: Fade in images https://docs.flutter.dev/cookbook/images/fading-in-images
class WImageResult extends StatelessWidget {
  final PostListing imageListing;
  final int index;
  final bool isSelected;
  final bool disallowSelections;

  final void Function(int index)? onSelectionToggle;
  final Iterable<E6PostResponse>? postsCache;
  SearchCache getSc(BuildContext context, [bool listen = false]) =>
      Provider.of<SearchCache>(context, listen: listen);
  const WImageResult({
    super.key,
    required this.imageListing,
    required this.index,
    this.onSelectionToggle,
    this.isSelected = false,
    this.disallowSelections = false,
    this.postsCache,
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
    logger.fine(
      "[$index/${imageListing.id}]: w: $w, "
      "h: $h, "
      "sampleWidth: ${imageListing.sample.width}, "
      "fileWidth: ${imageListing.file.width}, "
      "isSelected: $isSelected, "
      "url: $url",
    );
    return Stack(
      children: [
        _buildPane(context, w, h, url),
        PostInfoPane(post: imageListing),
        if (isSelected ||
            (!disallowSelections && sr(context).getIsSelected(index)))
          _buildCheckmark(context),
        _buildInputDetector(context, w, h, url),
      ],
    );
  }

  static ({num width, num height, num? cacheWidth, num? cacheHeight})
      determineResolution(
    BuildContext ctx,
    num fileWidth,
    num fileHeight,
    BoxFit fit,
  ) {
    final size = MediaQuery.sizeOf(ctx);
    final sizeWidth = size.width / SearchView.i.postsPerRow;
    final sizeHeight = sizeWidth.isFinite
        ? sizeWidth * SearchView.i.widthToHeightRatio
        : size.height;
    num width, height;
    num? cacheWidth, cacheHeight;
    if (fileWidth != fileHeight) {
      switch (fit) {
        case BoxFit.cover:
          if (fileWidth > fileHeight) {
            cacheHeight = (sizeHeight.isFinite) ? sizeHeight : null;
            height = (sizeHeight.isFinite)
                ? sizeHeight //min(sizeHeight, fileHeight)
                : fileHeight;
            width = (fileWidth * height) / fileHeight;
          } else /*  if (fileHeight > fileWidth) */ {
            cacheWidth = (sizeWidth.isFinite) ? sizeWidth : null;
            width = (sizeWidth.isFinite)
                ? sizeWidth //min(sizeWidth, fileWidth)
                : fileWidth;
            height = (fileHeight * width) / fileWidth;
          }
          break;
        case BoxFit.fitHeight:
        case BoxFit.fitWidth:
        case BoxFit.none:
        case BoxFit.contain:
        default:
          if (fileWidth > fileHeight) {
            cacheWidth = (sizeWidth.isFinite) ? sizeWidth : null;
            width = (sizeWidth.isFinite)
                ? sizeWidth //min(sizeWidth, fileWidth)
                : fileWidth;
            height = (fileHeight * width) / fileWidth;
          } else /*  if (fileHeight > fileWidth) */ {
            cacheHeight = (sizeHeight.isFinite) ? sizeHeight : null;
            height = (sizeHeight.isFinite)
                ? sizeHeight //min(sizeHeight, fileHeight)
                : fileHeight;
            width = (fileWidth * height) / fileHeight;
          }
      }
    } else {
      cacheHeight = cacheWidth = (sizeHeight.isFinite)
          ? sizeHeight
          : (sizeWidth.isFinite)
              ? sizeWidth
              : null;
      height = width = (sizeHeight.isFinite)
          ? sizeHeight //min(sizeHeight, fileHeight)
          : (sizeWidth.isFinite)
              ? sizeWidth //min(sizeWidth, fileWidth)
              : fileWidth;
    }
    return (
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight
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

  SearchResultsNotifier sr(BuildContext context) =>
      Provider.of<SearchResultsNotifier>(context, listen: false);

  SearchResultsNotifier srl(BuildContext context) =>
      Provider.of<SearchResultsNotifier>(context);

  Widget _buildInputDetector(BuildContext context, int w, int h, String url) {
    // SearchResults sr() => Provider.of<SearchResults>(context, listen: false);
    SearchResultsNotifier? srl;
    if (!disallowSelections) srl = Provider.of<SearchResultsNotifier>(context);
    void toggle() {
      onSelectionToggle?.call(index);
      srl?.toggleSelection(
        index: index,
        postId: imageListing.id,
      );
    }

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // onHover: (value) {
          //   // tooltip: _buildTooltipString,
          // },
          onLongPress: () {
            print("OnLongPress");
            toggle();
          },
          onDoubleTap: () {
            print("onDoubleTap");
            toggle();
          },
          onTap: () {
            print("OnTap");
            if (isSelected || (srl?.areAnySelected ?? false)) {
              toggle();
            } else {
              SavedDataE6.init();
              Navigator.push<IReturnsTags>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => allowPostViewNavigation
                        ? useLinkedList
                            ? const Placeholder() //_buildLinkedSwiper(context)
                            : old.PostSwipePage.postsCollection(
                                initialIndex: index,
                                posts: postsCache ??
                                    Provider.of<SearchCache>(context,
                                            listen: false)
                                        .posts!
                                        .posts,
                                onAddToSearch: getOnAddToSearch(context),
                                tagsToAdd: [],
                              )
                        : PostViewPage(
                            postListing: imageListing,
                            onAddToSearch: getOnAddToSearch(context),
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

  void Function(String) getOnAddToSearch(BuildContext context) =>
      (String addition) {
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
          "After: ${Provider.of<SearchViewModel>(
            context,
            listen: false,
          ).searchText += " $addition"}",
        );
      };

  @widgetFactory
  Widget _buildPane(BuildContext ctx, int w, int h, String url) {
    if (url == "") {
      print("NO URL");
    }
    var (:width, :height, :cacheWidth, :cacheHeight) =
        WImageResult.determineResolution(ctx, w, h, imageFit);
    return Image.network(
      url,
      errorBuilder: (context, error, stackTrace) => throw error,
      fit: imageFit, //BoxFit.contain,
      width: width.toDouble(),
      height: height.toDouble(),
      cacheWidth: cacheWidth?.toInt(),
      cacheHeight: cacheHeight?.toInt(),
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

  // @widgetFactory
  // PostSwipePage _buildLinkedSwiper(BuildContext context) {
  //   PostLle t = PostLle(
  //     post: imageListing as E6PostResponse,
  //   );
  //   LinkedList<PostLle>().addAll(
  //       Provider.of<SearchCache>(context, listen: false).posts!.posts.map((e) {
  //     return e == (imageListing as E6PostResponse) ? t : PostLle(post: e);
  //   }));
  //   return PostSwipePage(
  //     length:
  //         Provider.of<SearchCache>(context, listen: false).posts!.posts.length,
  //     initialIndex: index,
  //     post: t,
  //     onAddToSearch: getOnAddToSearch(context),
  //     tagsToAdd: [],
  //   );
  // }
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
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 150,
          maxHeight: 150,
        ),
        height: 20,
        color: const Color.fromARGB(149, 46, 46, 46),
        child: Text.rich(
          TextSpan(
            text: " ",
            children: SearchView.i.postInfoBannerItems.mapAsList(
              (e, i, l) => e.getMyTextSpan(e6Post),
            ),
          ),
        ),
      ),
    );
  }
}

enum PostInfoPaneItem {
  rating,
  fileExtension,
  scoreTotal,
  scoreUpAndDown,
  hasParent,
  hasChildren,
  isFavorited,
  ;

  String toJson() => name;
  factory PostInfoPaneItem.fromJson(json) => switch (json) {
        String j when j == rating.name => rating,
        String j when j == fileExtension.name => fileExtension,
        String j when j == scoreTotal.name => scoreTotal,
        String j when j == scoreUpAndDown.name => scoreUpAndDown,
        String j when j == hasParent.name => hasParent,
        String j when j == hasChildren.name => hasChildren,
        String j when j == isFavorited.name => isFavorited,
        _ => throw UnsupportedError("type not supported"),
      };
  InlineSpan getMyTextSpan(E6PostResponse e6Post) => switch (this) {
        rating => TextSpan(
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
        fileExtension => TextSpan(text: "${e6Post.file.ext} "),
        scoreTotal => TextSpan(text: "${e6Post.score.total} "),
        scoreUpAndDown => TextSpan(children: [
            const TextSpan(
              text: "(",
            ),
            TextSpan(
                text: "${e6Post.score.up}",
                style: const TextStyle(
                  color: Colors.green,
                  decoration: TextDecoration.underline,
                )),
            const TextSpan(text: "/"),
            TextSpan(
                text: "${e6Post.score.down}",
                style: const TextStyle(
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                )),
            const TextSpan(text: ") "),
          ]),
        hasParent => (e6Post.relationships.hasParent)
            ? const TextSpan(
                text: "P ",
                style: TextStyle(
                  color: Colors.amber,
                  decoration: TextDecoration.underline,
                ))
            : const TextSpan(),
        hasChildren => (e6Post.relationships.hasChildren)
            ? TextSpan(
                text: "C${e6Post.relationships.children.length} ",
                style: const TextStyle(
                  color: Colors.amber,
                  decoration: TextDecoration.underline,
                ))
            : const TextSpan(),
        isFavorited => (e6Post.isFavorited)
            ? const TextSpan(
                text: "♥ ",
                style: TextStyle(
                  color: Colors.red,
                ))
            : const TextSpan(),
      };
}
