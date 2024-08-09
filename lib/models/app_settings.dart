import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/e621.dart' show TagCategory;
import 'package:fuzzy/util/util.dart' as util;
import 'package:j_util/j_util_full.dart';

class AppSettingsRecord {
  final PostViewData postView;
  final Set<String> favoriteTags;
  final Set<String> blacklistedTags;
  final bool forceSafe;
  final SearchViewData searchView;

  const AppSettingsRecord({
    required this.postView,
    required this.favoriteTags,
    required this.blacklistedTags,
    required this.searchView,
    required this.forceSafe,
  });
  static const defaultSettings = AppSettingsRecord(
    postView: PostViewData.defaultData,
    searchView: SearchViewData.defaultData,
    favoriteTags: {},
    blacklistedTags: {
      "type:swf",
    },
    forceSafe: false,
  );
  factory AppSettingsRecord.fromJson(JsonOut json) => AppSettingsRecord(
        postView: PostViewData.fromJson(
            json["postView"] ?? defaultSettings.postView.toJson()),
        searchView: SearchViewData.fromJson(
            json["searchView"] ?? defaultSettings.searchView.toJson()),
        favoriteTags: (json["favoriteTags"] as List?)?.cast<String>().toSet() ??
            defaultSettings.favoriteTags,
        blacklistedTags:
            (json["blacklistedTags"] as List?)?.cast<String>().toSet() ??
                defaultSettings.blacklistedTags,
        forceSafe: json["forceSafe"] ?? defaultSettings.forceSafe,
      );
  JsonOut toJson() => {
        "postView": postView,
        "searchView": searchView,
        "favoriteTags": favoriteTags.toList(),
        "blacklistedTags": blacklistedTags.toList(),
        "forceSafe": forceSafe,
      };
}

class AppSettings implements AppSettingsRecord {
  // #region FileIO
  // static const localStoragePrefix = "settings";
  static const fileName = "settings.json";
  static final _fileFullPath = LazyInitializer(
      () async => "${await util.appDataPath.getItem()}/$fileName");
  static final _file = (Platform.isWeb)
      ? null
      : LazyInitializer(() async {
          var t = io.File(await _fileFullPath.getItem());
          return (await t.exists())
              ? t
              : await (await t.create(recursive: true, exclusive: true))
                  .writeAsString(
                      jsonEncode(AppSettings.defaultSettings.toJson()));
        });
  static LazyInitializer<io.File> get myFile => _file!;
  static Future<AppSettings> loadSettingsFromFile() async {
    return (Platform.isWeb)
        ? ((await devData.getItem())["settings"] == null
            ? defaultSettings
            : AppSettings.fromJson(devData.$["settings"]))
        // : await (myFile
        //     .getItem()
        //     .then((v) => v.readAsString())
        //     .then((v2) => AppSettings.fromJson(
        //           jsonDecode((v2).printMe()),
        //         ))
        //   ..then((v) {
        //     PostView._instance.itemSafe ??= v.postView;
        //     SearchView._instance.itemSafe ??= v.searchView;
        //     return v;
        //   }));
        : AppSettings.fromJson(
            jsonDecode(
                (await (await myFile.getItem()).readAsString()).printMe()),
          );
  }

  Future<AppSettings> loadFromFile() async {
    return switch (Platform.getPlatform()) {
      Platform.web => this..overwriteWithRecord(defaultSettings),
      Platform.android || Platform.iOS => this
        ..overwriteWithRecord(AppSettings.fromJson(
            jsonDecode(await (await myFile.getItem()).readAsString()))),
      _ => throw UnsupportedError("platform not supported"),
    };
  }

  /* static Future<String?> loadStringAsync() async {
    !Platform.isWeb ? await (await myFile.getItem()).readAsString()
    : (() {
      
    })();
  } */
  static Future<io.File?> writeSettingsToFile([AppSettings? a]) async =>
      switch (Platform.getPlatform()) {
        Platform.web => null,
        Platform.android ||
        Platform.iOS =>
          (await myFile.getItem()).writeAsString(
            jsonEncode(a ?? i ?? defaultSettings)..printMe(),
            flush: true,
          ),
        _ => throw UnsupportedError("platform not supported"),
      };
  Future<io.File?> writeToFile() async => writeSettingsToFile(this);
  // #endregion FileIO

  static final defaultSettings =
      AppSettings.fromRecord(AppSettingsRecord.defaultSettings);
  static final priorSettings = LazyInitializer(loadSettingsFromFile);

  // #region Singleton
  static final _instance = LazyInitializer<AppSettings>(loadSettingsFromFile);
  static Future<AppSettings> get instance async =>
      _instance.isAssigned ? _instance.$ : await _instance.getItem();
  static AppSettings? get i => _instance.$Safe;
  // #endregion Singleton
  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  JsonOut toJson() => toRecord().toJson();
  factory AppSettings.fromJson(JsonOut json) =>
      AppSettings.fromRecord(AppSettingsRecord.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)

  // static List<(String, dynamic Function(), void Function(dynamic))> getFields(AppSettings i) => [
  //   ("postView", () => i.postView as dynamic, (v) => i.postView = v),
  //   ("searchView", () => i.searchView as dynamic, (v) => i.searchView = v),
  //   ("favoriteTags", () => i.favoriteTags as dynamic, (v) => i.favoriteTags = v),
  //   ("blacklistedTags", () => i.blacklistedTags as dynamic, (v) => i.blacklistedTags = v),
  // ];
  // static String? loadFromLocalStorage() {

  // }
  factory AppSettings.fromRecord(AppSettingsRecord r) => AppSettings.all(
        postView: PostView.fromData(r.postView),
        searchView: SearchView.fromData(r.searchView),
        favoriteTags: Set<String>.from(r.favoriteTags),
        blacklistedTags: Set<String>.from(r.blacklistedTags),
        forceSafe: r.forceSafe,
      );
  AppSettingsRecord toRecord() => AppSettingsRecord(
        postView: _postView.toData(),
        searchView: _searchView.toData(),
        favoriteTags: Set.unmodifiable(_favoriteTags),
        blacklistedTags: Set.unmodifiable(_blacklistedTags),
        forceSafe: _forceSafe,
      );
  AppSettings({
    PostView? postView,
    SearchView? searchView,
    Set<String>? favoriteTags,
    Set<String>? blacklistedTags,
    bool? forceSafe,
  })  : _postView = postView ?? defaultSettings.postView,
        _searchView = searchView ?? defaultSettings.searchView,
        _favoriteTags = favoriteTags ?? defaultSettings._favoriteTags,
        _blacklistedTags = blacklistedTags ?? defaultSettings._blacklistedTags,
        _forceSafe = forceSafe ?? defaultSettings._forceSafe;
  void overwriteWithRecord([
    AppSettingsRecord r = AppSettingsRecord.defaultSettings,
  ]) {
    _postView.overwriteWithData(r.postView);
    _searchView.overwriteWithData(r.searchView);
    _favoriteTags = Set.of(r.favoriteTags);
    _blacklistedTags = Set.of(r.blacklistedTags);
    _forceSafe = r.forceSafe;
  }

  AppSettings.all({
    required PostView postView,
    required SearchView searchView,
    required Set<String> favoriteTags,
    required Set<String> blacklistedTags,
    required bool forceSafe,
  })  : _postView = postView,
        _searchView = searchView,
        _favoriteTags = favoriteTags,
        _blacklistedTags = blacklistedTags,
        _forceSafe = forceSafe;
  PostView _postView;
  @override
  PostView get postView => _postView;
  set postView(PostView value) => _postView = value;
  SearchView _searchView;
  @override
  SearchView get searchView => _searchView;
  set searchView(SearchView value) => _searchView = value;
  Set<String> _favoriteTags;
  @override
  Set<String> get favoriteTags => _favoriteTags;
  set favoriteTags(Set<String> value) => _favoriteTags = value;
  Set<String> _blacklistedTags;
  @override
  Set<String> get blacklistedTags => _blacklistedTags;
  set blacklistedTags(Set<String> value) => _blacklistedTags = value;
  bool _forceSafe;
  @override
  bool get forceSafe => _forceSafe;
  set forceSafe(bool value) => _forceSafe = value;
}

class PostViewData {
  static const defaultData = PostViewData(
    tagOrder: [
      TagCategory.artist,
      TagCategory.copyright,
      TagCategory.character,
      TagCategory.species,
      TagCategory.general,
      TagCategory.lore,
      TagCategory.meta,
    ],
    tagColors: {
      TagCategory.artist: Color(0xFFF2AC08),
      TagCategory.copyright: Color(0xFFDD00DD),
      TagCategory.character: Color(0xFF00AA00),
      TagCategory.species: Color(0xFFED5D1F),
      TagCategory.general: Color(0xFFB4C7D9),
      TagCategory.lore: Color(0xFF228822),
      TagCategory.meta: Color(0xFFFFFFFF),
      TagCategory.invalid: Color(0xFFFF3D3D),
    },
    colorTags: true,
    colorTagHeaders: false,
    // allowOverflow: true,
    forceHighQualityImage: true,
    autoplayVideo: true,
    startVideoMuted: true,
    showTimeLeft: true,
    startWithTagsExpanded: true,
    startWithDescriptionExpanded: false,
    imageQuality: FilterQuality.medium,
    useProgressiveImages: true,
    imageFilterQuality: FilterQuality.none,
  );
  final List<TagCategory> tagOrder;
  final Map<TagCategory, Color> tagColors;
  final bool colorTags;
  final bool colorTagHeaders;
  // final bool allowOverflow;
  final bool forceHighQualityImage;
  final bool autoplayVideo;
  final bool startVideoMuted;

  /// When playing a video, show the time remaining
  /// instead of the total duration?
  final bool showTimeLeft;
  final bool startWithTagsExpanded;
  final bool startWithDescriptionExpanded;
  final FilterQuality imageQuality;
  final bool useProgressiveImages;
  final FilterQuality imageFilterQuality;
  const PostViewData({
    required this.tagOrder,
    required this.tagColors,
    required this.colorTags,
    required this.colorTagHeaders,
    // required this.allowOverflow,
    required this.forceHighQualityImage,
    required this.autoplayVideo,
    required this.startVideoMuted,
    required this.showTimeLeft,
    required this.startWithTagsExpanded,
    required this.startWithDescriptionExpanded,
    required this.imageQuality,
    required this.useProgressiveImages,
    required this.imageFilterQuality,
  });
  factory PostViewData.fromJson(JsonOut json) => PostViewData(
        tagOrder: (json["tagOrder"] as List?)
                ?.mapAsList((e, i, l) => TagCategory.fromJson(e)) ??
            defaultData.tagOrder,
        tagColors: (json["tagColors"])?.map<TagCategory, Color>(
                (k, v) => MapEntry(TagCategory.fromJson(k), Color(v))) ??
            defaultData.tagColors,
        colorTags: json["colorTags"] ?? defaultData.colorTags,
        colorTagHeaders: json["colorTagHeaders"] ?? defaultData.colorTagHeaders,
        // allowOverflow: json["allowOverflow"] ?? defaultData.allowOverflow,
        forceHighQualityImage:
            json["forceHighQualityImage"] ?? defaultData.forceHighQualityImage,
        autoplayVideo: json["autoplayVideo"] ?? defaultData.autoplayVideo,
        startVideoMuted: json["startVideoMuted"] ?? defaultData.startVideoMuted,
        showTimeLeft: json["showTimeLeft"] ?? defaultData.showTimeLeft,
        startWithTagsExpanded:
            json["startWithTagsExpanded"] ?? defaultData.startWithTagsExpanded,
        startWithDescriptionExpanded: json["startWithDescriptionExpanded"] ??
            defaultData.startWithDescriptionExpanded,
        imageQuality: FilterQuality.values.singleWhere((e) =>
            e.name == (json["imageQuality"] ?? defaultData.imageQuality.name)),
        useProgressiveImages:
            json["useProgressiveImages"] ?? defaultData.useProgressiveImages,
        imageFilterQuality: FilterQuality.values.singleWhere((e) =>
            e.name ==
            (json["imageFilterQuality"] ??
                defaultData.imageFilterQuality.name)),
      );
  JsonOut toJson() => {
        "tagOrder": tagOrder,
        "tagColors": tagColors.map((k, v) => MapEntry(k.toJson(), v.value)),
        "colorTags": colorTags,
        "colorTagHeaders": colorTagHeaders,
        // "allowOverflow": allowOverflow,
        "forceHighQualityImage": forceHighQualityImage,
        "autoplayVideo": autoplayVideo,
        "startVideoMuted": startVideoMuted,
        "showTimeLeft": showTimeLeft,
        "startWithTagsExpanded": startWithTagsExpanded,
        "startWithDescriptionExpanded": startWithDescriptionExpanded,
        "imageQuality": imageQuality,
        "useProgressiveImages": useProgressiveImages,
        "imageFilterQuality": imageFilterQuality.name,
      };
}

class PostView implements PostViewData {
  // #region Fields
  List<TagCategory> _tagOrder;
  @override
  List<TagCategory> get tagOrder => _tagOrder;
  set tagOrder(List<TagCategory> v) => _tagOrder = v;
  Map<TagCategory, Color> _tagColors;
  @override
  Map<TagCategory, Color> get tagColors => _tagColors;
  set tagColors(Map<TagCategory, Color> v) => _tagColors = v;
  bool _colorTags;
  @override
  bool get colorTags => _colorTags;
  set colorTags(bool v) => _colorTags = v;
  bool _colorTagHeaders;
  @override
  bool get colorTagHeaders => _colorTagHeaders;
  set colorTagHeaders(bool v) => _colorTagHeaders = v;
  // bool _allowOverflow;
  // @override
  // bool get allowOverflow => _allowOverflow;
  // set allowOverflow(bool v) => _allowOverflow = v;
  bool _forceHighQualityImage;
  @override
  bool get forceHighQualityImage => _forceHighQualityImage;
  set forceHighQualityImage(bool v) => _forceHighQualityImage = v;
  bool _autoplayVideo;
  @override
  bool get autoplayVideo => _autoplayVideo;
  set autoplayVideo(bool v) => _autoplayVideo = v;
  bool _startVideoMuted;
  @override
  bool get startVideoMuted => _startVideoMuted;
  set startVideoMuted(bool v) => _startVideoMuted = v;
  bool _showTimeLeft;
  @override
  bool get showTimeLeft => _showTimeLeft;
  set showTimeLeft(bool v) => _showTimeLeft = v;
  bool _startWithTagsExpanded;
  @override
  bool get startWithTagsExpanded => _startWithTagsExpanded;
  set startWithTagsExpanded(bool v) => _startWithTagsExpanded = v;
  bool _startWithDescriptionExpanded;
  @override
  bool get startWithDescriptionExpanded => _startWithDescriptionExpanded;
  set startWithDescriptionExpanded(bool v) => _startWithDescriptionExpanded = v;
  FilterQuality _imageQuality;
  @override
  FilterQuality get imageQuality => _imageQuality;
  set imageQuality(FilterQuality v) => _imageQuality = v;
  bool _useProgressiveImages;
  @override
  bool get useProgressiveImages => _useProgressiveImages;
  set useProgressiveImages(bool v) => _useProgressiveImages = v;
  FilterQuality _imageFilterQuality;
  @override
  FilterQuality get imageFilterQuality => _imageFilterQuality;
  set imageFilterQuality(FilterQuality v) => _imageFilterQuality = v;
  // #endregion Fields
  PostView({
    required List<TagCategory> tagOrder,
    required Map<TagCategory, Color> tagColors,
    required bool colorTags,
    required bool colorTagHeaders,
    // required bool allowOverflow,
    required bool forceHighQualityImage,
    required bool autoplayVideo,
    required bool startVideoMuted,
    required bool showTimeLeft,
    required bool startWithTagsExpanded,
    required bool startWithDescriptionExpanded,
    required FilterQuality imageQuality,
    required bool useProgressiveImages,
    required FilterQuality imageFilterQuality,
  })  : _tagOrder = tagOrder,
        _tagColors = tagColors,
        _colorTags = colorTags,
        _colorTagHeaders = colorTagHeaders,
        // _allowOverflow = allowOverflow,
        _forceHighQualityImage = forceHighQualityImage,
        _autoplayVideo = autoplayVideo,
        _startVideoMuted = startVideoMuted,
        _showTimeLeft = showTimeLeft,
        _startWithTagsExpanded = startWithTagsExpanded,
        _startWithDescriptionExpanded = startWithDescriptionExpanded,
        _imageQuality = imageQuality,
        _useProgressiveImages = useProgressiveImages,
        _imageFilterQuality = imageFilterQuality;

  factory PostView.fromData(PostViewData postView) => PostView(
        tagOrder: List.from(postView.tagOrder),
        tagColors: Map.from(postView.tagColors),
        colorTags: postView.colorTags,
        colorTagHeaders: postView.colorTagHeaders,
        // allowOverflow: postView.allowOverflow,
        forceHighQualityImage: postView.forceHighQualityImage,
        autoplayVideo: postView.autoplayVideo,
        startVideoMuted: postView.startVideoMuted,
        showTimeLeft: postView.showTimeLeft,
        startWithTagsExpanded: postView.startWithTagsExpanded,
        startWithDescriptionExpanded: postView.startWithDescriptionExpanded,
        imageQuality: postView.imageQuality,
        useProgressiveImages: postView.useProgressiveImages,
        imageFilterQuality: postView.imageFilterQuality,
      );

  void overwriteWithData(PostViewData postView) {
    tagOrder = List.from(postView.tagOrder);
    tagColors = Map.from(postView.tagColors);
    colorTags = postView.colorTags;
    colorTagHeaders = postView.colorTagHeaders;
    // allowOverflow = postView.allowOverflow;
    forceHighQualityImage = postView.forceHighQualityImage;
    autoplayVideo = postView.autoplayVideo;
    startVideoMuted = postView.startVideoMuted;
    showTimeLeft = postView.showTimeLeft;
    startWithTagsExpanded = postView.startWithTagsExpanded;
    startWithDescriptionExpanded = postView.startWithDescriptionExpanded;
    imageQuality = postView.imageQuality;
    useProgressiveImages = postView.useProgressiveImages;
    imageFilterQuality = postView.imageFilterQuality;
  }

  PostViewData toData() => PostViewData(
        tagOrder: tagOrder,
        tagColors: tagColors,
        colorTags: colorTags,
        colorTagHeaders: colorTagHeaders,
        // allowOverflow: allowOverflow,
        forceHighQualityImage: forceHighQualityImage,
        autoplayVideo: autoplayVideo,
        startVideoMuted: startVideoMuted,
        showTimeLeft: showTimeLeft,
        startWithTagsExpanded: startWithTagsExpanded,
        startWithDescriptionExpanded: startWithDescriptionExpanded,
        imageQuality: imageQuality,
        useProgressiveImages: useProgressiveImages,
        imageFilterQuality: imageFilterQuality,
      );

  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  JsonOut toJson() => toData().toJson();
  factory PostView.fromJson(JsonOut json) =>
      PostView.fromData(PostViewData.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  // #region Singleton
  static PostView get instance => AppSettings.i!.postView;
  static PostView get i => instance;
  // #endregion Singleton
}

class SearchViewData {
  static const postsPerRowBounds = (min: 1, max: 15);
  static const widthToHeightRatioBounds = (min: .5, max: 2);
  static const defaultData = SearchViewData(
    postsPerPage: 50,
    postsPerRow: 3,
    maxCharsInPostInfo: 100,
    postInfoBannerItems: PostInfoPaneItem.values,
    widthToHeightRatio: 1,
    useProgressiveImages: true,
    numSavedSearchesInSearchBar: 5,
    lazyLoad: false,
    lazyBuilding: false,
    preferSetShortname: true,
  );
  final int postsPerPage;
  final int postsPerRow;
  final List<PostInfoPaneItem> postInfoBannerItems;
  final double widthToHeightRatio;
  final bool useProgressiveImages;
  final int numSavedSearchesInSearchBar;
  final bool lazyLoad;
  final bool lazyBuilding;
  final bool preferSetShortname;
  final int maxCharsInPostInfo;
  const SearchViewData({
    required this.postsPerPage,
    required this.postsPerRow,
    required this.postInfoBannerItems,
    required this.widthToHeightRatio,
    required this.useProgressiveImages,
    required this.numSavedSearchesInSearchBar,
    required this.lazyLoad,
    required this.lazyBuilding,
    required this.preferSetShortname,
    required this.maxCharsInPostInfo,
  });
  factory SearchViewData.fromJson(JsonOut json) => SearchViewData(
        postsPerPage: json["postsPerPage"] ?? defaultData.postsPerPage,
        postsPerRow: json["postsPerRow"] ?? defaultData.postsPerRow,
        postInfoBannerItems:
            (json["postInfoBannerItems"] as String?)?.split(",").mapAsList(
                      (e, i, l) => PostInfoPaneItem.fromJson(e),
                    ) ??
                defaultData.postInfoBannerItems,
        widthToHeightRatio:
            json["widthToHeightRatio"] ?? defaultData.widthToHeightRatio,
        useProgressiveImages:
            json["useProgressiveImages"] ?? defaultData.useProgressiveImages,
        numSavedSearchesInSearchBar: json["numSavedSearchesInSearchBar"] ??
            defaultData.numSavedSearchesInSearchBar,
        lazyLoad: json["lazyLoad"] ?? defaultData.lazyLoad,
        lazyBuilding: json["lazyBuilding"] ?? defaultData.lazyBuilding,
        preferSetShortname:
            json["preferSetShortname"] ?? defaultData.preferSetShortname,
        maxCharsInPostInfo:
            json["maxCharsInPostInfo"] ?? defaultData.maxCharsInPostInfo,
      );
  JsonOut toJson() => {
        "postsPerPage": postsPerPage,
        "postsPerRow": postsPerRow,
        "postInfoBannerItems": postInfoBannerItems.fold(
          "",
          (previousValue, element) =>
              "${previousValue.isNotEmpty ? '$previousValue,' : previousValue}"
              "${element.name}",
        ),
        "widthToHeightRatio": widthToHeightRatio,
        "useProgressiveImages": useProgressiveImages,
        "numSavedSearchesInSearchBar": numSavedSearchesInSearchBar,
        "lazyLoad": lazyLoad,
        "lazyBuilding": lazyBuilding,
        "preferSetShortname": preferSetShortname,
        "maxCharsInPostInfo": maxCharsInPostInfo,
      };
}

/// TODO: Integrate ChangeNotifier?
class SearchView implements SearchViewData {
  int _postsPerPage;
  @override
  int get postsPerPage => _postsPerPage;
  set postsPerPage(int v) =>
      (v > 0 && v <= E621.maxPostsPerSearch) ? _postsPerPage = v : "";
  int _postsPerRow;
  @override
  int get postsPerRow => _postsPerRow;
  set postsPerRow(int v) => (v >= SearchViewData.postsPerRowBounds.min &&
          v <= SearchViewData.postsPerRowBounds.max)
      ? _postsPerRow = v
      : "";
  List<PostInfoPaneItem> _postInfoBannerItems;
  @override
  List<PostInfoPaneItem> get postInfoBannerItems => _postInfoBannerItems;
  set postInfoBannerItems(List<PostInfoPaneItem> v) => _postInfoBannerItems = v;
  double _widthToHeightRatio;
  @override
  double get widthToHeightRatio => _widthToHeightRatio;
  set widthToHeightRatio(double v) =>
      (v >= SearchViewData.widthToHeightRatioBounds.min &&
              v < SearchViewData.widthToHeightRatioBounds.max)
          ? _widthToHeightRatio = v
          : "";
  bool _useProgressiveImages;
  @override
  bool get useProgressiveImages => _useProgressiveImages;
  set useProgressiveImages(bool v) => _useProgressiveImages = v;
  int _numSavedSearchesInSearchBar;
  @override
  int get numSavedSearchesInSearchBar => _numSavedSearchesInSearchBar;
  set numSavedSearchesInSearchBar(int v) => _numSavedSearchesInSearchBar = v;
  bool _lazyLoad;
  @override
  bool get lazyLoad => _lazyLoad;
  set lazyLoad(bool v) => _lazyLoad = v;
  bool _lazyBuilding;
  @override
  bool get lazyBuilding => _lazyBuilding;
  set lazyBuilding(bool v) => _lazyBuilding = v;
  bool _preferSetShortname;
  @override
  bool get preferSetShortname => _preferSetShortname;
  set preferSetShortname(bool v) => _preferSetShortname = v;
  int _maxCharsInPostInfo;
  @override
  int get maxCharsInPostInfo => _maxCharsInPostInfo;
  set maxCharsInPostInfo(int v) => (v >= 0) ? _maxCharsInPostInfo = v : "";
  SearchView({
    required int postsPerPage,
    required int postsPerRow,
    required int maxCharsInPostInfo,
    required List<PostInfoPaneItem> postInfoBannerItems,
    required double widthToHeightRatio,
    required bool useProgressiveImages,
    required int numSavedSearchesInSearchBar,
    required bool lazyLoad,
    required bool lazyBuilding,
    required bool preferSetShortname,
  })  : _postsPerPage = postsPerPage,
        _postsPerRow = postsPerRow,
        _postInfoBannerItems = postInfoBannerItems,
        _widthToHeightRatio = widthToHeightRatio,
        _useProgressiveImages = useProgressiveImages,
        _numSavedSearchesInSearchBar = numSavedSearchesInSearchBar,
        _lazyLoad = lazyLoad,
        _lazyBuilding = lazyBuilding,
        _preferSetShortname = preferSetShortname,
        _maxCharsInPostInfo = maxCharsInPostInfo;

  factory SearchView.fromData(SearchViewData searchView) => SearchView(
        postsPerPage: searchView.postsPerPage,
        postsPerRow: searchView.postsPerRow,
        postInfoBannerItems: searchView.postInfoBannerItems,
        widthToHeightRatio: searchView.widthToHeightRatio,
        useProgressiveImages: searchView.useProgressiveImages,
        numSavedSearchesInSearchBar: searchView.numSavedSearchesInSearchBar,
        lazyLoad: searchView.lazyLoad,
        lazyBuilding: searchView.lazyBuilding,
        preferSetShortname: searchView.preferSetShortname,
        maxCharsInPostInfo: searchView.maxCharsInPostInfo,
      );
  void overwriteWithData(SearchViewData searchView) {
    _postsPerPage = searchView.postsPerPage;
    _postsPerRow = searchView.postsPerRow;
    _postInfoBannerItems = searchView.postInfoBannerItems.toList();
    _widthToHeightRatio = searchView.widthToHeightRatio;
    _useProgressiveImages = searchView.useProgressiveImages;
    _numSavedSearchesInSearchBar = searchView.numSavedSearchesInSearchBar;
    _lazyLoad = searchView.lazyLoad;
    _lazyBuilding = searchView.lazyBuilding;
    _preferSetShortname = searchView.preferSetShortname;
    _maxCharsInPostInfo = searchView.maxCharsInPostInfo;
  }

  SearchViewData toData() => SearchViewData(
        postsPerPage: postsPerPage,
        postsPerRow: postsPerRow,
        postInfoBannerItems: postInfoBannerItems,
        widthToHeightRatio: widthToHeightRatio,
        useProgressiveImages: useProgressiveImages,
        numSavedSearchesInSearchBar: numSavedSearchesInSearchBar,
        lazyLoad: lazyLoad,
        lazyBuilding: lazyBuilding,
        preferSetShortname: preferSetShortname,
        maxCharsInPostInfo: maxCharsInPostInfo,
      );

  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  JsonOut toJson() => toData().toJson();
  factory SearchView.fromJson(JsonOut json) =>
      SearchView.fromData(SearchViewData.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  // #region Singleton (don't need updating w/ new fields)
  static SearchView get instance => AppSettings.i!.searchView;
  static SearchView get i => instance;
  // #endregion Singleton (don't need updating w/ new fields)
}

extension OnAppSettings on AppSettings {
  // TagDB
}

class Field<T> {
  T _item;
  T get item => _item;
  set item(T value) => _item = value;
  Field(T item) : _item = item;
  factory Field.fromJson(dynamic item) => Field(item);
  dynamic toJson() => item /* .toString() */;
}
