import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart' show SearchView;
import 'package:fuzzy/models/saved_data.dart' show SavedDataE6;
import 'package:fuzzy/models/search_results.dart' show SearchResultsNotifier;
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/post_swipe_page.dart';
import 'package:fuzzy/util/asset_management.dart'
    show determineResolution, placeholder;
import 'package:fuzzy/web/e621/models/e6_models.dart' /*  show E6PostResponse */;
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/models/image_listing.dart'
    show IImageInfo, PostListing, RetrieveImageProvider;
import 'package:e621/e621.dart' show TagCategory;
import 'package:j_util/j_util_full.dart';
import 'package:progressive_image/progressive_image.dart' show ProgressiveImage;
import 'package:provider/provider.dart' show Provider;

BoxFit imageFit = BoxFit.cover;
const bool allowPostViewNavigation = true;

class WImageResult extends StatelessWidget {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WImageResult");
  // #endregion Logger
  final PostListing imageListing;
  bool get isE6Post => imageListing is E6PostResponse;
  E6PostResponse get post => imageListing as E6PostResponse;
  E6PostResponse? get postSafe => imageListing as E6PostResponse;
  final int index;
  final bool isSelected;
  final bool disallowSelections;

  // final void Function(int index)? onSelectionToggle;
  final Iterable<E6PostResponse>? postsCache;
  ManagedPostCollectionSync getSc(BuildContext context,
          [bool listen = false]) =>
      Provider.of<ManagedPostCollectionSync>(context, listen: listen);
  const WImageResult({
    super.key,
    required this.imageListing,
    required this.index,
    // this.onSelectionToggle,
    this.isSelected = false,
    this.disallowSelections = false,
    this.postsCache,
  });

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    IImageInfo imageInfo;
    if (Platform.isAndroid || Platform.isIOS) {
      imageInfo = imageListing.preview;
    } else if (imageListing.sample.has &&
        imageListing.sample.width > imageListing.preview.width) {
      imageInfo = imageListing.sample;
    } else {
      imageInfo = imageListing.file;
    }
    logger.fine(
      "[$index/${imageListing.id}]: w: ${imageInfo.width}, "
      "h: ${imageInfo.height}, "
      "sampleWidth: ${imageListing.sample.width}, "
      "fileWidth: ${imageListing.file.width}, "
      "isSelected: $isSelected, "
      "url: ${imageInfo.url}",
    );
    final t = getGridSizeEstimate(context);
    return Stack(
      children: [
        _buildPane(context, imageInfo),
        if (SearchView.i.postInfoBannerItems.isNotEmpty)
          PostInfoPane(
            post: imageListing,
            maxWidth: t.width,
            maxHeight: t.height / 3,
          ),
        if (isSelected ||
            (!disallowSelections &&
                sr(context).getIsPostSelected(imageListing.id)))
          _buildCheckmark(context),
        if (isE6Post && post.isAnimatedGif)
          Positioned.directional(
              textDirection: TextDirection.ltr,
              top: 0,
              end: 0,
              child: const Icon(Icons.gif))
        else if (isE6Post && post.file.isAVideo)
          Positioned.directional(
              textDirection: TextDirection.ltr,
              top: 0,
              end: 0,
              child: const Icon(Icons.play_circle_outline)),
        _buildInputDetector(context),
      ],
    );
  }

  static ({double width, double height}) getGridSizeEstimate(BuildContext ctx) {
    final size = MediaQuery.sizeOf(ctx);
    final sizeWidth = size.width / SearchView.i.postsPerRow;
    final sizeHeight = sizeWidth.isFinite
        ? sizeWidth / SearchView.i.widthToHeightRatio
        : size.height;
    logger.finest(
      "Estimated height ${sizeWidth * SearchView.i.widthToHeightRatio}"
      "Alleged height ${size.height}",
    );
    return (height: sizeHeight, width: sizeWidth);
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
          shadows: const [Shadow(offset: Offset(2.5, 5), blurRadius: 5)],
        ),
      ),
    );
  }

  SearchResultsNotifier sr(BuildContext context) =>
      Provider.of<SearchResultsNotifier>(context, listen: false);

  SearchResultsNotifier srl(BuildContext context) =>
      Provider.of<SearchResultsNotifier>(context);

  Widget _buildInputDetector(BuildContext context) {
    final srl = !disallowSelections
        ? Provider.of<SearchResultsNotifier>(context)
        : null;
    void toggle() {
      logger.info(
          "Toggling ${imageListing.id} selection, was selected: ${srl?.getIsPostSelected(imageListing.id)}, is selected: ${srl?.togglePostSelection(
        index: index,
        postId: imageListing.id,
        resolveDesync: false,
      )} ");
      // srl?.toggleSelection(
      //   index: index,
      //   postId: imageListing.id,
      // );
      logger.finest("Currently selected post ids: ${srl?.selectedPostIds}");
      logger.finest("Currently selected indices: ${srl?.selectedIndices}");
    }

    void viewPost() {
      SavedDataE6.init();
      int? p;
      ManagedPostCollectionSync? sc;
      if (!disallowSelections) {
        sc = getSc(context, false);
        // await getSc(context, false).mpcSync.updateCurrentPostIndex(index);
        p = sc.getPageOfGivenPostIndexOnPage(index);
        sc.updateCurrentPostIndex(index);
      }
      void parseReturnValue(v) {
        if (v == null) return;
        try {
          if (v.tagsToAddToSearch is List<String> &&
              (v.tagsToAddToSearch as List<String>).firstOrNull != null) {
            sc?.searchText +=
                (v.tagsToAddToSearch as List<String>).foldToString();
          }
          if (!disallowSelections) {
            // TODO: NEEDS TO TRIGGER REBUILD
            sr(context).selectedPostIds =
                ((v.selectedPosts as Iterable<E6PostResponse>).map((e) => e.id))
                    .toSet();
          }
        } catch (e, s) {
          logger.severe(e, e, s);
        }
      }

      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => allowPostViewNavigation && !disallowSelections
                ? PostSwipePageManaged(
                    initialIndex: index,
                    // initialPageIndex:
                    //     getSc(context, false).mpcSync.currentPageIndex,
                    initialPageIndex:
                        p ?? sc!.getPageOfGivenPostIndexOnPage(index),
                    posts: sc!,
                    onAddToSearch: getOnAddToSearch(context),
                    // tagsToAdd: [],
                    selectedPosts: sc.collection
                        .where(
                          (element) => sr(context)
                              .selectedPostIds
                              .contains(element.$.id),
                        )
                        .map((e) => e.$)
                        .toList(),
                    // selectedPosts: srl,
                  )
                : PostSwipePage.postsCollection(
                    initialIndex: index,
                    posts: postsCache ??
                        (!disallowSelections
                            ? getSc(context, false).posts!.posts
                            : []),
                    onAddToSearch: getOnAddToSearch(context),
                    selectedPosts: sc?.collection
                        .where(
                          (element) => sr(context)
                              .selectedPostIds
                              .contains(element.$.id),
                        )
                        .map((e) => e.$)
                        .toList(),
                    // tagsToAdd: [],
                  ),
          )).then<void>(parseReturnValue);
    }

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // onHover: (value) {
          //   // tooltip: _buildTooltipString,
          // },
          onLongPress: () {
            print("[$index] OnLongPress", lm.LogLevel.INFO);
            // toggle();
            if (isSelected || (srl?.areAnySelected ?? false)) {
              viewPost();
            } else {
              toggle();
            }
          },
          onDoubleTap: () {
            print("[$index] onDoubleTap", lm.LogLevel.FINE);
            toggle();
          },
          onTap: () {
            print("[$index] OnTap", lm.LogLevel.INFO);
            if (isSelected || (srl?.areAnySelected ?? false)) {
              toggle();
            } else {
              viewPost();
            }
          },
        ),
      ),
    );
  }

  void Function(String) getOnAddToSearch(BuildContext context) =>
      (String addition) {
        print("WImageResult: onAddToSearch:");
        print("Before: ${Provider.of<ManagedPostCollectionSync>(
          context,
          listen: false,
        ).searchText}");
        // Provider.of<SearchViewModel>(
        //   context,
        //   listen: false,
        // ).fillTextBarWithSearchString = true;
        print(
          "After: ${getSc(context, false).searchText += " $addition"}",
        );
      };
  static const progressiveImageBlur = 5.0;
  @widgetFactory
  Widget _buildPane(BuildContext ctx, IImageInfo imageInfo) {
    int w;
    int h;
    String url;
    IImageInfo(width: w, height: h, url: url) = imageInfo;
    if (url == "") {
      logger.info("NO URL $index");
    }
    var (width: sizeWidth, height: sizeHeight) =
        WImageResult.getGridSizeEstimate(ctx);
    var (:width, :height, :cacheWidth, :cacheHeight, :aspectRatio) =
        determineResolution(w, h, sizeWidth, sizeHeight, imageFit);
    if (!SearchView.i.useProgressiveImages) {
      Widget i = Image(
        errorBuilder: (context, e, s) {
          return ErrorPage(
            error: e,
            stackTrace: s,
            logger: logger,
            message: "Couldn't load ${imageInfo.url}",
            isFullPage: false,
          );
        },
        fit: imageFit,
        width: width.toDouble(),
        height: height.toDouble(),
        image: imageInfo is RetrieveImageProvider
            ? imageInfo.createResizeImage(
                cacheWidth: cacheWidth?.toInt(),
                cacheHeight: cacheHeight?.toInt(),
              )
            : ResizeImage.resizeIfNeeded(
                cacheWidth?.toInt(),
                cacheHeight?.toInt(),
                NetworkImage(url),
              ),
      );
      return imageFit != BoxFit.cover ? Center(child: i) : i;
    }
    dynamic i = imageInfo is RetrieveImageProvider
        ? imageInfo.createResizeImage(
            cacheWidth: cacheWidth?.toInt(),
            cacheHeight: cacheHeight?.toInt(),
            scale: cacheWidth?.isFinite ?? false
                ? cacheWidth! / w
                : cacheHeight?.isFinite ?? false
                    ? cacheHeight! / h
                    : 1,
          )
        : ResizeImage.resizeIfNeeded(
            cacheWidth?.toInt(),
            cacheHeight?.toInt(),
            NetworkImage(
              url,
              scale: cacheWidth?.isFinite ?? false
                  ? cacheWidth! / w
                  : cacheHeight?.isFinite ?? false
                      ? cacheHeight! / h
                      : 1,
            ),
          );
    final fWidth = width, fHeight = height;
    ImageProvider thumb;
    if (imageListing.preview != imageInfo) {
      var IImageInfo(width: w2, height: h2, url: url2) = imageListing.preview;
      var (
        width: width2,
        height: height2,
        cacheWidth: cacheWidth2,
        cacheHeight: cacheHeight2,
        aspectRatio: aspectRatio2,
      ) = determineResolution(w2, h2, sizeWidth, sizeHeight, imageFit);
      logger.finest(
        "fWidth: $fWidth"
        "\nwidth2: $width2"
        "\nfHeight: $fHeight"
        "\nheight2: $height2"
        "\naspect: $aspectRatio"
        "\naspect2: $aspectRatio2"
        "\nw: $w"
        "\nw2: $w2"
        "\nh: $h"
        "\nh2: $h2",
      );
      thumb = imageListing.preview is RetrieveImageProvider
          ? (imageListing.preview as RetrieveImageProvider).createResizeImage(
              cacheWidth: cacheWidth2?.toInt(),
              cacheHeight: cacheHeight2?.toInt(),
              scale: cacheWidth2?.isFinite ?? false
                  ? cacheWidth2! / w2
                  : cacheHeight2?.isFinite ?? false
                      ? cacheHeight2! / h2
                      : 1,
            )
          : ResizeImage.resizeIfNeeded(
              cacheWidth2?.toInt(),
              cacheHeight2?.toInt(),
              NetworkImage(
                url2,
                scale: cacheWidth2?.isFinite ?? false
                    ? cacheWidth2! / w2
                    : cacheHeight2?.isFinite ?? false
                        ? cacheHeight2! / h2
                        : 1,
              ),
            );
    } else {
      logger.finest(
        "Same thumbnail as image\n"
        "fWidth: $fWidth"
        "\nfHeight: $fHeight"
        "\naspect: $aspectRatio"
        "\nw: $w"
        "\nh: $h",
      );
      thumb = i;
    }
    i = ProgressiveImage(
      blur: progressiveImageBlur,
      placeholder: placeholder,
      thumbnail: thumb,
      image: i,
      width: fWidth.toDouble(),
      height: fHeight.toDouble(),
      fit: imageFit,
    );
    return Center(child: i);
  }
}

class PostInfoPane extends StatelessWidget {
  // static const darkness = 46, alpha = 149, assumedTextHeight = 20.0;
  static const darkness = 32, alpha = 168, assumedTextHeight = 20.0;
  final PostListing post;
  final double maxWidth;
  final double maxHeight;
  E6PostResponse get e6Post => post as E6PostResponse;
  E6PostResponse? get e6PostSafe =>
      post.runtimeType == E6PostResponse ? post as E6PostResponse : null;

  const PostInfoPane({
    super.key,
    required this.post,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minHeight: assumedTextHeight,
        ),
        color: const Color.fromARGB(alpha, darkness, darkness, darkness),
        child: Text.rich(
          TextSpan(
            text: " ",
            children: SearchView.i.postInfoBannerItems
                .map((e) => e.getMyTextSpan(e6Post))
                .toList(),
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
  hasActiveChildren,
  isFavorited,
  isInPools,
  firstArtist,
  firstCharacter,
  firstCopyright,
  ;

  static const readabilityShadow = [
    BoxShadow(
      color: Colors.white,
      spreadRadius: 10,
      blurRadius: 2,
      blurStyle: BlurStyle.solid,
    ),
  ];
  String toJson() => name;
  factory PostInfoPaneItem.fromJson(json) => switch (json) {
        String j when j == rating.name => rating,
        String j when j == fileExtension.name => fileExtension,
        String j when j == scoreTotal.name => scoreTotal,
        String j when j == scoreUpAndDown.name => scoreUpAndDown,
        String j when j == hasParent.name => hasParent,
        String j when j == hasChildren.name => hasChildren,
        String j when j == hasActiveChildren.name => hasActiveChildren,
        String j when j == isFavorited.name => isFavorited,
        String j when j == isInPools.name => isInPools,
        String j when j == firstArtist.name => firstArtist,
        String j when j == firstCharacter.name => firstCharacter,
        String j when j == firstCopyright.name => firstCopyright,
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
              shadows: readabilityShadow,
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
                  shadows: readabilityShadow,
                )),
            const TextSpan(text: "/"),
            TextSpan(
                text: "${e6Post.score.down}",
                style: const TextStyle(
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                  shadows: readabilityShadow,
                )),
            const TextSpan(text: ") "),
          ]),
        hasParent => (e6Post.relationships.hasParent)
            ? const TextSpan(
                text: "P ",
                style: TextStyle(
                  color: Colors.amber,
                  decoration: TextDecoration.underline,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        hasChildren => (e6Post.relationships.hasChildren)
            ? TextSpan(
                text: "C${e6Post.relationships.children.length} ",
                style: const TextStyle(
                  color: Colors.amber,
                  decoration: TextDecoration.underline,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        hasActiveChildren => (e6Post.relationships.hasActiveChildren)
            ? TextSpan(
                text: "C${e6Post.relationships.children.length} ",
                style: const TextStyle(
                  color: Colors.amber,
                  decoration: TextDecoration.underline,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        isFavorited => (e6Post.isFavorited)
            ? const TextSpan(
                text: "♥ ",
                style: TextStyle(
                  color: Colors.red,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        isInPools => (e6Post.pools.isNotEmpty)
            ? TextSpan(
                text: "P(${e6Post.pools.length}) ",
                style: const TextStyle(
                  color: Colors.green,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        firstArtist => e6Post.tags.hasArtist
            ? TextSpan(
                // text: "A: ${e6Post.tags.artistFiltered.first} ",
                text: "${e6Post.tags.artistFiltered.first} ",
                style: const TextStyle(
                  color: TagCategory.artistColor,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        firstCharacter => e6Post.tags.hasCharacter
            ? TextSpan(
                // text: "A: ${e6Post.tags.characterFiltered.first} ",
                text: "${e6Post.tags.characterFiltered.first} ",
                style: const TextStyle(
                  color: TagCategory.characterColor,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        firstCopyright => e6Post.tags.copyright.isNotEmpty
            ? TextSpan(
                text: "${e6Post.tags.copyright.first} ",
                style: const TextStyle(
                  color: TagCategory.copyrightColor,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
      };
}
