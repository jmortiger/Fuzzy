import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:j_util/j_util_full.dart';

class AppSettingsRecord {
  final PostViewData postView;
  final Set<String> favoriteTags;

  const AppSettingsRecord({
    required this.postView,
    required this.favoriteTags,
  });
  static const defaultSettings = AppSettingsRecord(
    postView: PostViewData.defaultData,
    favoriteTags: {},
  );
  factory AppSettingsRecord.fromJson(JsonOut json) => AppSettingsRecord(
        postView: PostViewData.fromJson(json["postView"] as JsonOut),
        favoriteTags:
            (json["favoriteTags"] as Set<String>) /* .cast<String>() */,
      );
  JsonOut toJson() => {
        "postView": postView,
        "favoriteTags": favoriteTags,
      };
}

class AppSettings implements AppSettingsRecord {
  static final defaultSettings =
      AppSettings.fromRecord(AppSettingsRecord.defaultSettings);
  static final _instance = LateFinal<AppSettings>();
  static AppSettings get instance => _instance.isAssigned
      ? _instance.item
      : (_instance.item =
          AppSettings.fromRecord(AppSettingsRecord.defaultSettings));
  static AppSettings get i => instance;
  factory AppSettings.fromRecord(AppSettingsRecord r) => AppSettings(
        postView: PostView.fromData(r.postView),
        favoriteTags: Set.from(r.favoriteTags),
      );
  AppSettingsRecord toRecord() => AppSettingsRecord(
        postView: _postView,
        favoriteTags: _favoriteTags,
      );
  @override
  JsonOut toJson() => toRecord().toJson();
  factory AppSettings.fromJson(JsonOut json) =>
      AppSettings.fromRecord(AppSettingsRecord.fromJson(json));
  AppSettings({
    PostView? postView,
    Set<String>? favoriteTags,
  })  : _postView = postView ?? defaultSettings.postView,
        _favoriteTags = favoriteTags ?? defaultSettings._favoriteTags;
  PostView _postView;
  @override
  PostView get postView => _postView;
  set postView(PostView value) => _postView = value;
  Set<String> _favoriteTags;
  @override
  Set<String> get favoriteTags => _favoriteTags;
  set favoriteTags(Set<String> value) => _favoriteTags = value;
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
  factory PostView.fromJson(JsonOut json) =>
      PostView.fromData(PostViewData.fromJson(json));

  @override
  JsonOut toJson() => PostViewData(
        tagOrder: tagOrder,
        tagColors: tagColors,
        colorTags: colorTags,
        colorTagHeaders: colorTagHeaders,
        allowOverflow: allowOverflow,
      ).toJson();

  factory PostView.fromData(PostViewData postView) => PostView(
        tagOrder: List.from(postView.tagOrder.toList()),
        tagColors: Map.from(postView.tagColors),
        colorTags: postView.colorTags,
        colorTagHeaders: postView.colorTagHeaders,
        allowOverflow: postView.allowOverflow,
      );
}
