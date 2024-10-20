import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart' show SearchView;
import 'package:fuzzy/models/saved_data.dart' show SavedDataE6;
import 'package:fuzzy/models/selected_posts.dart' show SelectedPosts;
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/post_swipe_page.dart';
import 'package:fuzzy/util/asset_management.dart'
    show determineResolution, placeholder;
import 'package:fuzzy/util/extensions.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart' show E6PostResponse;
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/util.dart' as util;
import 'package:fuzzy/web/models/image_listing.dart'
    show IImageInfo, PostListing, RetrieveImageProvider;
import 'package:e621/e621.dart' show TagCategory;
import 'package:j_util/j_util_full.dart';
import 'package:progressive_image/progressive_image.dart' show ProgressiveImage;
import 'package:provider/provider.dart' show Provider;

/// TODO: Alter
BoxFit imageFit = BoxFit.cover;
const bool allowPostViewNavigation = true;
typedef _M = ManagedPostCollectionSync;
typedef _P = Provider;
typedef _S = SelectedPosts;

class ImageResult extends StatelessWidget {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("ImageResult");
  // #endregion Logger
  final PostListing imageListing;
  bool get isE6Post => imageListing is E6PostResponse;
  E6PostResponse get post => imageListing as E6PostResponse;
  E6PostResponse? get postSafe => imageListing as E6PostResponse;
  final int index;
  final bool isSelected;
  final bool disallowSelections;
  final bool? filterBlacklist;

  final Iterable<E6PostResponse>? postsCache;
  bool get usePostProvider => postsCache == null;
  ManagedPostCollectionSync getSc(BuildContext context,
          {bool listen = false}) =>
      Provider.of<ManagedPostCollectionSync>(context, listen: listen);
  const ImageResult({
    super.key,
    required this.imageListing,
    required this.index,
    // this.onSelectionToggle,
    this.isSelected = false,
    this.disallowSelections = false,
    this.postsCache,
    required this.filterBlacklist,
  });

  String _buildTooltipString(BuildContext ctx) =>
      /* $searchText */ "[$index]: ${postSafe?.id}"; //" (${usePostProvider ? Provider.of<ManagedPostCollectionSync>(ctx, listen: false)})";

  @override
  Widget build(BuildContext context) {
    // TODO: Prob a remnant from before wrapping input detector in material; might be able to remove.
    assert(debugCheckHasMaterial(context));
    IImageInfo imageInfo = Platform.isAndroid || Platform.isIOS
        ? imageListing.preview
        : imageListing.sample.has &&
                imageListing.sample.width > imageListing.preview.width
            ? imageListing.sample
            : imageListing.file;
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
            blacklistedTags: SearchView.i.postInfoBannerItems
                    .intersection(PostInfoPaneItem.blacklistValuesSet)
                    .isNotEmpty
                ? util.findBlacklistedTags(post).asSet()
                : null,
          ),
        if (isSelected ||
            (!disallowSelections &&
                _P.of<_S>(context).getIsPostSelected(imageListing.id)))
          _Checkmark(/* key: ObjectKey(imageListing.id), */ context: context),
        // TODO: Pull this into PostInfoPane?
        if (isE6Post)
          if (post.isAnimatedGif)
            Positioned.directional(
                textDirection: TextDirection.ltr,
                top: 0,
                end: 0,
                child: const Icon(Icons.gif))
          else if (post.file.isAVideo)
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
    final sizeWidth = MediaQuery.sizeOf(ctx).width / SearchView.i.postsPerRow;
    return (
      height: sizeWidth / SearchView.i.widthToHeightRatio,
      width: sizeWidth
    );
  }
  // static ({double width, double height}) getGridSizeEstimate(BuildContext ctx) {
  //   final size = MediaQuery.sizeOf(ctx),
  //       sizeWidth = size.width / SearchView.i.postsPerRow,
  //       sizeHeight = sizeWidth.isFinite
  //           ? sizeWidth / SearchView.i.widthToHeightRatio
  //           : size.height;
  //   logger.finest(
  //     "Estimated height ${sizeWidth * SearchView.i.widthToHeightRatio}"
  //     "Alleged height ${size.height}",
  //   );
  //   return (height: sizeHeight, width: sizeWidth);
  // }

  Widget _buildInputDetector(BuildContext ctx) {
    final srl = !disallowSelections ? Provider.of<SelectedPosts>(ctx) : null;
    void toggle() {
      if (srl == null) return logger.warning("Can't select ${imageListing.id}");
      logger.info("Toggling ${imageListing.id} selection, "
          "was selected: ${srl.getIsPostSelected(imageListing.id)}, "
          "is selected: ${srl.togglePostSelection(postId: imageListing.id)}");
      logger.finest("Currently selected post ids: ${srl.selectedPostIds}");
    }

    void viewPost() {
      SavedDataE6.init();
      int? p;
      ManagedPostCollectionSync? sc;
      if (!disallowSelections) {
        sc = _P.of<_M>(ctx, listen: false);
        // await _P.of<_M>(ctx, listen: false).updateCurrentPostIndex(index);
        p = sc.getPageIndexOfGivenPost(index);
        sc.updateCurrentPostIndex(index);
      }
      void parseReturnValue(e) {
        if (e == null) return;
        final v = (
          selectedPosts: e.selectedPosts as List<E6PostResponse>?,
          tagsToAddToSearch: e.tagsToAddToSearch as List<String>
        );
        try {
          if (v.tagsToAddToSearch.firstOrNull != null) {
            sc?.searchText += v.tagsToAddToSearch.foldToString();
          }
          // if (!disallowSelections && v.selectedPosts != null) {
          //   // TODO: NEEDS TO TRIGGER REBUILD
          //   sr(context).selectedPostIds =
          //       (v.selectedPosts!.map((e) => e.id)).toSet();
          // }
        } catch (e, s) {
          logger.severe(e, e, s);
        }
      }

      Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => allowPostViewNavigation && !disallowSelections
                ? PostSwipePageManaged(
                    initialIndex: index,
                    // initialPageIndex:
                    //     _P.of<_M>(ctx, listen: false).currentPageIndex,
                    initialPageIndex: p ?? sc!.getPageIndexOfGivenPost(index),
                    posts: sc!,
                    onAddToSearch: getOnAddToSearch(ctx),
                    filterBlacklist: filterBlacklist,
                    selectedPosts: _P
                        .of<_S>(ctx, listen: false)
                        .makeSelectedPostList(sc.collection.map((e) => e.$)),
                    // selectedPosts: sc.collection
                    //     .where(
                    //       (element) => sr(context)
                    //           .selectedPostIds
                    //           .contains(element.$.id),
                    //     )
                    //     .map((e) => e.$)
                    //     .toList(),
                    // selectedPosts: srl,
                    srn: srl,
                  )
                : PostSwipePage.postsCollection(
                    initialIndex: index,
                    posts: postsCache ?? sc?.posts!.posts ?? [],
                    onAddToSearch: getOnAddToSearch(ctx),
                    selectedPosts: sc != null
                        ? _P
                            .of<_S>(ctx, listen: false)
                            .makeSelectedPostList(sc.collection.map((e) => e.$))
                        : null,
                    // selectedPosts: sc?.collection
                    //     .where(
                    //       (element) => sr(context)
                    //           .selectedPostIds
                    //           .contains(element.$.id),
                    //     )
                    //     .map((e) => e.$)
                    //     .toList(),
                    // tagsToAdd: [],
                  ),
          )).then<void>(parseReturnValue);
    }

    bool inSelectionState() => isSelected || (srl?.areAnySelected ?? false);

    void onLongPress() {
      print("[$index][${post.id}] OnLongPress", lm.LogLevel.INFO);
      inSelectionState() ? viewPost() : toggle();
    }

    void onDoubleTap() {
      print("[$index][${post.id}] OnDoubleTap", lm.LogLevel.FINE);
      toggle();
    }

    void onTap() {
      print("[$index][${post.id}] OnTap", lm.LogLevel.INFO);
      inSelectionState() ? toggle() : viewPost();
    }

    return Positioned.fill(
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              onLongPress: onLongPress,
              onDoubleTap: onDoubleTap,
              onTap: onTap,
            )));
  }

  void Function(String) getOnAddToSearch(BuildContext ctx) => (addition) => print(
      "onAddToSearch:"
      "\n\tBefore: ${_P.of<_M>(ctx, listen: false).searchText}"
      "\n\tAfter: ${_P.of<_M>(ctx, listen: false).searchText += " $addition"}");
  static const progressiveImageBlur = 5.0;
  @widgetFactory
  Widget _buildPane(BuildContext ctx, IImageInfo imageInfo) {
    var IImageInfo(width: w, height: h, url: url) = imageInfo;
    if (url == "") logger.info("NO URL $index");
    var (width: sizeWidth, height: sizeHeight) =
        ImageResult.getGridSizeEstimate(ctx);
    var (:width, :height, :cacheWidth, :cacheHeight, :aspectRatio) =
        determineResolution(w, h, sizeWidth, sizeHeight, imageFit);
    if (!SearchView.i.useProgressiveImages) {
      final i = Image(
        errorBuilder: (context, e, s) => ErrorPage(
          error: e,
          stackTrace: s,
          logger: logger,
          message: "Couldn't load ${imageInfo.url}",
          isFullPage: false,
        ),
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
                    : 1)
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
            ));
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
    return Center(
      child: ProgressiveImage(
        blur: progressiveImageBlur,
        placeholder: placeholder,
        thumbnail: thumb,
        image: i,
        width: fWidth.toDouble(),
        height: fHeight.toDouble(),
        fit: imageFit,
      ),
    );
  }
}

class _Checkmark extends StatelessWidget {
  const _Checkmark({
    // super.key,
    required this.context,
  });

  final BuildContext context;
  static const double assumedOpticalSize = 48,
      assumedSize = 24,
      desktopMultiplier = 6,
      mobileMultiplier = 3;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: true,
        child: Align(
          alignment: Alignment.bottomRight,
          // heightFactor: (Platform.isDesktop ? desktopMultiplier : mobileMultiplier),
          // widthFactor: (Platform.isDesktop ? desktopMultiplier : mobileMultiplier),
          child: Icon(
            Icons.check,
            color: Colors.green,
            opticalSize:
                (IconTheme.of(context).opticalSize ?? assumedOpticalSize) *
                    (Platform.isDesktop ? desktopMultiplier : mobileMultiplier),
            size: (IconTheme.of(context).size ?? assumedSize) *
                (Platform.isDesktop ? desktopMultiplier : mobileMultiplier),
            shadows: const [Shadow(offset: Offset(2.5, 5), blurRadius: 5)],
          ),
        ),
      );
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
  final Set<String>? blacklistedTags;

  const PostInfoPane({
    super.key,
    required this.post,
    required this.maxWidth,
    required this.maxHeight,
    this.blacklistedTags,
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
                .map((e) => e.getMyTextSpan(e6Post, blacklistedTags))
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
  id,
  blacklistedTagCount,
  blacklistedTags,
  ;

  static const valuesSet = {
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
    id,
    blacklistedTagCount,
    blacklistedTags,
  };
  static const blacklistValuesSet = {
    blacklistedTagCount,
    blacklistedTags,
  };

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
        String j when j == id.name => id,
        String j when j == blacklistedTagCount.name => blacklistedTagCount,
        String j when j == blacklistedTags.name => blacklistedTags,
        _ => throw UnsupportedError("type not supported"),
      };
  InlineSpan getMyTextSpan(E6PostResponse e6Post,
          [Set<String>? blacklistedPostTags]) =>
      switch (this) {
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
        id => TextSpan(
            text: "#${e6Post.id} ",
            style: const TextStyle(
              color: Colors.white,
              // shadows: readabilityShadow,
            )),
        blacklistedTags => (blacklistedPostTags?.isNotEmpty ??
                util.isBlacklisted(e6Post))
            ? TextSpan(
                text:
                    "{${(blacklistedPostTags ?? util.findBlacklistedTags(e6Post)).join(",")}} ",
                style: const TextStyle(
                  color: Colors.amber,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
        blacklistedTagCount => (blacklistedPostTags?.isNotEmpty ??
                util.isBlacklisted(e6Post))
            ? TextSpan(
                text:
                    "${(blacklistedPostTags ?? util.findBlacklistedTags(e6Post)).length} ",
                style: const TextStyle(
                  color: TagCategory.copyrightColor,
                  shadows: readabilityShadow,
                ))
            : const TextSpan(),
      };
}
