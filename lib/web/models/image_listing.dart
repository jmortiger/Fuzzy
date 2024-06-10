abstract interface class PostListing {
  IImageInfo get file;
  IImageInfo get preview;
  ISampleInfo get sample;
}

abstract interface class IImageInfo {
  Uri get address;
  String get url;
  int get width;
  int get height;
  bool get hasValidUrl => Uri.tryParse(url) != null;
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
