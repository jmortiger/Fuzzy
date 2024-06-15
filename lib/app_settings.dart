import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:j_util/j_util_full.dart';

class AppSettingsRecord {
  final PostViewData postView;
  final Set<String> favoriteTags;
  final Set<String> blacklistedTags;
  final SearchViewData searchView;

  const AppSettingsRecord({
    required this.postView,
    required this.favoriteTags,
    required this.blacklistedTags,
    required this.searchView,
  });
  static const defaultSettings = AppSettingsRecord(
    postView: PostViewData.defaultData,
    searchView: SearchViewData.defaultData,
    favoriteTags: {},
    blacklistedTags: {
      "type:swf",
    },
  );
  factory AppSettingsRecord.fromJson(JsonOut json) => AppSettingsRecord(
        postView: PostViewData.fromJson(json["postView"] as JsonOut),
        searchView: SearchViewData.fromJson(json["searchView"] as JsonOut),
        favoriteTags:
            (json["favoriteTags"] as Set<String>) /* .cast<String>() */,
        blacklistedTags:
            (json["blacklistedTags"] as Set<String>) /* .cast<String>() */,
      );
  JsonOut toJson() => {
        "postView": postView,
        "searchView": searchView,
        "favoriteTags": favoriteTags,
        "blacklistedTags": blacklistedTags,
      };
}

class AppSettings implements AppSettingsRecord {
  static final defaultSettings =
      AppSettings.fromRecord(AppSettingsRecord.defaultSettings);
  // #region Singleton
  static final _instance = LateFinal<AppSettings>();
  static AppSettings get instance => _instance.isAssigned
      ? _instance.item
      : (_instance.item =
          AppSettings.fromRecord(AppSettingsRecord.defaultSettings));
  static AppSettings get i => instance;
  // #endregion Singleton
  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  JsonOut toJson() => toRecord().toJson();
  factory AppSettings.fromJson(JsonOut json) =>
      AppSettings.fromRecord(AppSettingsRecord.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  factory AppSettings.fromRecord(AppSettingsRecord r) => AppSettings.all(
        postView: PostView.fromData(r.postView),
        searchView: SearchView.fromData(r.searchView),
        favoriteTags: Set.from(r.favoriteTags),
        blacklistedTags: Set.from(r.favoriteTags),
      );
  AppSettingsRecord toRecord() => AppSettingsRecord(
        postView: _postView.toData(),
        searchView: _searchView.toData(),
        favoriteTags: Set.unmodifiable(_favoriteTags),
        blacklistedTags: Set.unmodifiable(_blacklistedTags),
      );
  AppSettings({
    PostView? postView,
    SearchView? searchView,
    Set<String>? favoriteTags,
    Set<String>? blacklistedTags,
  })  : _postView = postView ?? defaultSettings.postView,
        _searchView = searchView ?? defaultSettings.searchView,
        _favoriteTags = favoriteTags ?? defaultSettings._favoriteTags,
        _blacklistedTags = blacklistedTags ?? defaultSettings._blacklistedTags;
  void overwriteWithRecord({
    AppSettingsRecord r = AppSettingsRecord.defaultSettings,
  }) {
    _postView.overwriteWithData(r.postView);
    _searchView.overwriteWithData(r.searchView);
    _favoriteTags = Set.of(r.favoriteTags);
    _blacklistedTags = Set.of(r.blacklistedTags);
  }

  AppSettings.all({
    required PostView postView,
    required SearchView searchView,
    required Set<String> favoriteTags,
    required Set<String> blacklistedTags,
  })  : _postView = postView,
        _searchView = searchView,
        _favoriteTags = favoriteTags,
        _blacklistedTags = blacklistedTags;
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
    allowOverflow: true,
  );
  final List<TagCategory> tagOrder;
  final Map<TagCategory, Color> tagColors;
  final bool colorTags;
  final bool colorTagHeaders;
  final bool allowOverflow;
  const PostViewData({
    required this.tagOrder,
    required this.tagColors,
    required this.colorTags,
    required this.colorTagHeaders,
    required this.allowOverflow,
  });
  factory PostViewData.fromJson(JsonOut json) => PostViewData(
        tagOrder:
            (json["tagOrder"] as List).mapAsList((e, i, l) => e as TagCategory),
        tagColors: (json["tagColors"] as Map<TagCategory, Color>),
        colorTags: (json["colorTags"] as bool),
        colorTagHeaders: (json["colorTagHeaders"] as bool),
        allowOverflow: (json["allowOverflow"] as bool),
      );
  JsonOut toJson() => {
        "tagOrder": tagOrder,
        "tagColors": tagColors,
        "colorTags": colorTags,
        "colorTagHeaders": colorTagHeaders,
        "allowOverflow": allowOverflow,
      };
}

class PostView implements PostViewData {
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
  bool _allowOverflow;
  @override
  bool get allowOverflow => _allowOverflow;
  set allowOverflow(bool v) => _allowOverflow = v;
  PostView({
    required List<TagCategory> tagOrder,
    required Map<TagCategory, Color> tagColors,
    required bool colorTags,
    required bool colorTagHeaders,
    required bool allowOverflow,
  })  : _tagOrder = tagOrder,
        _tagColors = tagColors,
        _colorTags = colorTags,
        _colorTagHeaders = colorTagHeaders,
        _allowOverflow = allowOverflow;

  factory PostView.fromData(PostViewData postView) => PostView(
        tagOrder: List.from(postView.tagOrder.toList()),
        tagColors: Map.from(postView.tagColors),
        colorTags: postView.colorTags,
        colorTagHeaders: postView.colorTagHeaders,
        allowOverflow: postView.allowOverflow,
      );

  void overwriteWithData(PostViewData postView) {
    tagOrder = List.from(postView.tagOrder.toList());
    tagColors = Map.from(postView.tagColors);
    colorTags = postView.colorTags;
    colorTagHeaders = postView.colorTagHeaders;
    allowOverflow = postView.allowOverflow;
  }

  PostViewData toData() => PostViewData(
        tagOrder: tagOrder,
        tagColors: tagColors,
        colorTags: colorTags,
        colorTagHeaders: colorTagHeaders,
        allowOverflow: allowOverflow,
      );

  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  JsonOut toJson() => toData().toJson();
  factory PostView.fromJson(JsonOut json) =>
      PostView.fromData(PostViewData.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  // #region Singleton
  static final _instance = LateFinal<PostView>();
  static PostView get instance => _instance.isAssigned
      ? _instance.item
      : (_instance.item = PostView.fromData(PostViewData.defaultData));
  static PostView get i => instance;
  // #endregion Singleton
}

class SearchViewData {
  static const defaultData = SearchViewData(
    postsPerPage: 50,
    postsPerRow: 3,
  );
  final int postsPerPage;
  final int postsPerRow;
  const SearchViewData({
    required this.postsPerPage,
    required this.postsPerRow,
  });
  factory SearchViewData.fromJson(JsonOut json) => SearchViewData(
        postsPerPage: (json["postsPerPage"] as int),
        postsPerRow: (json["postsPerRow"] as int),
      );
  JsonOut toJson() => {
        "postsPerPage": postsPerPage,
        "postsPerRow": postsPerRow,
      };
}

class SearchView implements SearchViewData {
  int _postsPerPage;
  @override
  int get postsPerPage => _postsPerPage;
  set postsPerPage(int v) => _postsPerPage = v;
  int _postsPerRow;
  @override
  int get postsPerRow => _postsPerRow;
  set postsPerRow(int v) => _postsPerRow = v;
  SearchView({
    required int postsPerPage,
    required int postsPerRow,
  })  : _postsPerPage = postsPerPage,
        _postsPerRow = postsPerRow;

  factory SearchView.fromData(SearchViewData postView) => SearchView(
        postsPerPage: postView.postsPerPage,
        postsPerRow: postView.postsPerRow,
      );
  void overwriteWithData(SearchViewData searchView) {
    _postsPerPage = searchView.postsPerPage;
    _postsPerRow = searchView.postsPerRow;
  }

  SearchViewData toData() => SearchViewData(
        postsPerPage: postsPerPage,
        postsPerRow: postsPerRow,
      );

  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  JsonOut toJson() => toData().toJson();
  factory SearchView.fromJson(JsonOut json) =>
      SearchView.fromData(SearchViewData.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  // #region Singleton (don't need updating w/ new fields)
  static final _instance = LateFinal<SearchView>();
  static SearchView get instance => _instance.isAssigned
      ? _instance.item
      : (_instance.item = SearchView.fromData(SearchViewData.defaultData));
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
