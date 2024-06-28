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

abstract interface class IImageInfoBare {
  Uri get address;
  String get url;
  bool get hasValidUrl => Uri.tryParse(url) != null;
  static bool hasValidUrlImpl(IImageInfoBare i) => Uri.tryParse(i.url) != null;
  String get extension;
  static String extensionImpl(IImageInfoBare i) => i.url.substring(i.url.lastIndexOf(".") + 1);
  bool get isAVideo => extension == "webm" || extension == "mp4";
  static bool isAVideoImpl(IImageInfoBare i) => i.extension == "webm" || i.extension == "mp4";
}

abstract interface class IImageInfo extends IImageInfoBare {
  int get width;
  int get height;
}

abstract interface class ISampleInfo extends IImageInfo {
  // Uri get address;
  // String get url;
  // int get width;
  // int get height;
  bool get has;
}

/// TODO: Finish
abstract interface class IVideoInfo {
  Uri get address;
  String get url;
  int get width;
  int get height;
}
