import 'package:flutter/material.dart'
    show AssetImage, ImageProvider, NetworkImage, ResizeImage;
import 'package:fuzzy/util/util.dart'
    as util /* "deletedPreview" : {
    "path": "assets/deleted-preview.png",
    "width": 150,
    "height": 150,
  }, */
    ;

const deletedUrl = "deleted";

abstract interface class PostListing extends PostListingBare {
  @override
  IImageInfo get file;
  @override
  IImageInfo get preview;
  ISampleInfo get sample;
}

abstract interface class PostListingBare {
  int get id;
  DateTime get createdAt;
  List<String> get tagList;
  ITagData get tagData;
  IImageInfoBare get file;
  IImageInfoBare get preview;
  String get description;
  bool get isFavorited;
}

abstract interface class ITagData {
  List<String> get general;
  List<String> get species;
}

mixin IImageInfoBare {
  Uri get address;
  String get url;
  bool get hasValidUrl => hasValidUrlImpl(this);
  static bool hasValidUrlImpl(IImageInfoBare i) =>
      i.url.isNotEmpty && i.url != deletedUrl && Uri.tryParse(i.url) != null;
  String get extension;
  static String extensionImpl(IImageInfoBare i) =>
      i.url.substring(i.url.lastIndexOf(".") + 1);
  bool get isAVideo => extension == "webm" || extension == "mp4";
  static bool isAVideoImpl(IImageInfoBare i) =>
      i.extension == "webm" || i.extension == "mp4";
}

mixin RetrieveImageProvider on IImageInfo {
  /// The base provider that can be wrapped in a [ResizeImage].
  ImageProvider createRootProvider({
    double scale = 1.0,
    Map<String, String>? headers,
  }) =>
      hasValidUrl && !isAVideo
          ? NetworkImage(url, scale: scale, headers: headers)
          : url != deletedUrl
              ? const AssetImage(util.StaticImageDataNotFound4x.path)
              : const AssetImage(util.StaticImageDataDeleted4x.path)
                  as ImageProvider;

  /// The base provider that can be wrapped in a [ResizeImage].
  ImageProvider createResizeImage({
    int? cacheWidth,
    int? cacheHeight,
    double scale = 1.0,
    Map<String, String>? headers,
  }) =>
      ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        createRootProvider(scale: scale, headers: headers),
      );
}

mixin IImageInfo implements IImageInfoBare {
  int get width;
  int get height;
  @override
  bool get hasValidUrl => IImageInfoBare.hasValidUrlImpl(this);
  @override
  bool get isAVideo => IImageInfoBare.isAVideoImpl(this);
}

abstract interface class ISampleInfo with IImageInfo {
  bool get has;
}

/// TODO: Finish
abstract interface class IVideoInfo {
  Uri get address;
  String get url;
  int get width;
  int get height;
}
