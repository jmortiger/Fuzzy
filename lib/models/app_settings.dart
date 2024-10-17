import 'dart:convert' as dc;
import 'dart:io' as io;

import 'package:e621/e621.dart' as e621;
import 'package:e621/e621.dart' show TagCategory;
import 'package:flutter/material.dart'
    show Color, FilterQuality, SliverGridDelegateWithFixedCrossAxisCount;
import 'package:fuzzy/util/shared_preferences.dart' as util;
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/widgets/w_image_result.dart' show PostInfoPaneItem;
import 'package:j_util/j_util_full.dart' show LazyInitializer, Platform;
import 'package:shared_preferences/shared_preferences.dart';

/// TODO: Integrate ChangeNotifier?
class AppSettingsRecord {
  final PostViewData postView;
  final Set<String> favoriteTags;
  final Set<String> blacklistedTags;
  final bool forceSafe;
  final bool autoLoadUserProfile;
  final bool applyProfileBlacklist;
  final bool applyProfileFavTags;
  final bool upvoteOnFavorite;
  final bool enableDownloads;
  final int maxSearchesToSave;
  final SearchViewData searchView;

  const AppSettingsRecord({
    required this.postView,
    required this.favoriteTags,
    required this.blacklistedTags,
    required this.searchView,
    required this.forceSafe,
    required this.autoLoadUserProfile,
    required this.applyProfileBlacklist,
    required this.applyProfileFavTags,
    required this.upvoteOnFavorite,
    required this.enableDownloads,
    required this.maxSearchesToSave,
  });
  static const defaultSettings = AppSettingsRecord(
    postView: PostViewData.defaultData,
    searchView: SearchViewData.defaultData,
    favoriteTags: {},
    blacklistedTags: {
      "type:swf",
    },
    forceSafe: false,
    autoLoadUserProfile: true,
    applyProfileBlacklist: true,
    applyProfileFavTags: true,
    upvoteOnFavorite: true,
    enableDownloads: false,
    maxSearchesToSave: 200,
  );
  // ignore: unnecessary_late
  factory AppSettingsRecord.fromJson(Map<String, dynamic> json) =>
      AppSettingsRecord(
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
        autoLoadUserProfile:
            json["autoLoadUserProfile"] ?? defaultSettings.autoLoadUserProfile,
        applyProfileBlacklist: json["applyProfileBlacklist"] ??
            defaultSettings.applyProfileBlacklist,
        applyProfileFavTags:
            json["applyProfileFavTags"] ?? defaultSettings.applyProfileFavTags,
        upvoteOnFavorite:
            json["upvoteOnFavorite"] ?? defaultSettings.upvoteOnFavorite,
        enableDownloads:
            json["enableDownloads"] ?? defaultSettings.enableDownloads,
        maxSearchesToSave:
            json["maxSearchesToSave"] ?? defaultSettings.maxSearchesToSave,
      );
  Map<String, dynamic> toJson() => {
        "postView": postView.toJson(),
        "searchView": searchView.toJson(),
        "favoriteTags": favoriteTags.toList(),
        "blacklistedTags": blacklistedTags.toList(),
        "forceSafe": forceSafe,
        "autoLoadUserProfile": autoLoadUserProfile,
        "applyProfileBlacklist": applyProfileBlacklist,
        "applyProfileFavTags": applyProfileFavTags,
        "upvoteOnFavorite": upvoteOnFavorite,
        "enableDownloads": enableDownloads,
        "maxSearchesToSave": maxSearchesToSave,
      };
}

class AppSettings implements AppSettingsRecord {
  // #region FileIO
  static const fileName = "settings.json";
  static final _fileFullPath = LazyInitializer(
      () async => "${await util.appDataPath.getItem()}/$fileName");
  static final myFile = LazyInitializer(() async {
    if (Platform.isWeb) return null;
    var t = io.File(await _fileFullPath.getItem());
    return (await t.exists())
        ? t
        : await (await t.create(recursive: true, exclusive: true))
            .writeAsString(dc.jsonEncode(AppSettings.defaultSettings.toJson()));
  });
  // static LazyInitializer<io.File> get myFile => _file!;
  // static Future<AppSettings> loadSettings() async {
  //   return (Platform.isWeb)
  //       ? loadFromPref()
  //       // ? ((await util.devData.getItem())?["settings"] == null
  //       //     ? defaultSettings
  //       //     : AppSettings.fromJson(util.devData.$Safe?["settings"]))
  //       : loadSettingsFromFile();
  // }

  static Future<AppSettings> loadSettingsFromFile() async {
    final devSettings =
            util.devData.$Safe?["settings"] as Map<String, dynamic>?,
        s = (await (await myFile.getItem())?.readAsString());
    var j = (s != null
        ? dc.jsonDecode(s) as Map<String, dynamic>
        : await util.loadJsonFromPrefWithTypeMap(
            typeMap,
            prefix: "$localStoragePrefix.",
          ));
    if (devSettings != null) {
      j = (j?..updateAll((k, v) => v ?? devSettings[k])) ?? devSettings;
    }
    return j != null
        ? AppSettings.fromJson(j)
        : AppSettings.fromRecord(defaultSettings);
  }

  static Future<AppSettings> loadInstance() =>
      loadSettingsFromFile()..then((v) => e621.useNsfw = !v.forceSafe).ignore();

  Future<AppSettings> loadFromFile() =>
      loadSettingsFromFile().then((v) => this..overwriteWithRecord(v));

  /// Returns the currently stored value.
  static Future<String?> writeSettingsToFile([AppSettings? a]) async =>
      (await myFile.getItem())
          ?.writeAsString(dc.jsonEncode(a ?? i ?? defaultSettings), flush: true)
          .then((v) => v.readAsString()) ??
      writeToPref(a ?? i ?? defaultSettings).then((v) => v
          ? dc.jsonEncode(util.loadJsonFromPrefWithTypeMapSync(typeMap))
          : null);
  Future<String?> writeToFile() => writeSettingsToFile(this);
  // #endregion FileIO

  // #region SharedPreferences
  static final Map<String, String> typeMap = util.makePrefTypeMap(
    util.fromJsonMapToPrefMap(
      defaultSettings.toJson(),
      "$localStoragePrefix.",
    ),
    appendSuffix: false,
  );
  static const localStoragePrefix = 'app_settings';
  static const localStorageLengthKeySuffix = '.length';
  static Future<bool> writeToPref([AppSettings? data]) =>
      (data ??= AppSettings.i) == null
          ? Future.value(false)
          : util.writeToPref(
              util.fromJsonMapToPrefMap(data!.toJson(), "$localStoragePrefix."),
            );
  /* data ??= AppSettings.i;
    if (data == null) return Future.value(false);
    return util.writeToPref(
        util.fromJsonMapToPrefTypedMap(data.toJson(), "$localStoragePrefix.")); */
  /* 
    data ??= AppSettings.i;
    if (data == null) return Future.value(false);
    return util.pref.getItemAsync().then((v) {
      final success = <Future<bool>>[];
      for (final el in data!.toPrefMap().entries) {
        switch (el) {
          case MapEntry(key: String key, value: String value):
            success.add(v.setString(key, value));
            break;
          case MapEntry(key: String key, value: bool value):
            success.add(v.setBool(key, value));
            break;
          case MapEntry(key: String key, value: int value):
            success.add(v.setInt(key, value));
            break;
          case MapEntry(key: String key, value: double value):
            success.add(v.setDouble(key, value));
            break;
          case MapEntry(key: String key, value: List value):
            if (value.isEmpty) {
              success.add(v.setStringList(key, []));
              break;
            }
            switch (value) {
              case List<String> value:
                success.add(v.setStringList(key, value));
                break;
              case List<bool> _:
              case List<int> _:
              case List<double> _:
                success
                    .add(v.setStringList(key, value.map((e) => "$e").toList()));
                break;
              default:
                throw UnsupportedError(
                    "${value.runtimeType} of $key not supported");
            }
            break;
          case MapEntry(key: String key, value: dynamic value):
            throw UnsupportedError(
                "${value.runtimeType} of $key not supported");
        }
      }
      return Future.wait(success).then((val) => val.foldUntil<bool>(
          true, (p, e, _, __) => p && e,
          breakIfTrue: (p, _, __, ___) => !p));
      // return success.fold(
      //     l,
      //     (previousValue, element) => (previousValue is Future<bool>)
      //         ? previousValue.then((s) => element.then((s1) => s && s1))
      //         : element.then((s1) => previousValue && s1));
    }); */

  static Future<AppSettings> loadFromPref() =>
      util.pref.getItemAsync().then((v) => AppSettings.loadFromPrefSync(v)!);
  static AppSettings? loadFromPrefSync([SharedPreferences? pref]) =>
      (pref ??= util.pref.$Safe) == null
          ? null
          : AppSettings.fromJson(util.loadJsonFromPrefWithTypeMapSync(
              typeMap,
              prefInst: pref,
              prefix: "$localStoragePrefix.",
            )!);
  /* // return AppSettings.fromJson(util.loadJsonFromPrefWithKeysSync(util
    //     .fromJsonMapToPrefMap(defaultSettings.toJson(), "$localStoragePrefix.")
    //     .keys,
    //     prefInst: pref)!);
    if ((pref ??= util.pref.$Safe) == null) return null;
    pref!;
    final data = <String, dynamic>{};
    for (final el in defaultSettings.toPrefMap().entries) {
      switch (el) {
        case MapEntry(key: String key, value: String _):
          data[key] = pref.getString(key);
          break;
        case MapEntry(key: String key, value: bool _):
          data[key] = pref.getBool(key);
          break;
        case MapEntry(key: String key, value: int _):
          data[key] = pref.getInt(key);
          break;
        case MapEntry(key: String key, value: double _):
          data[key] = pref.getDouble(key);
          break;
        case MapEntry(key: String key, value: List value):
          switch (value) {
            case List<String> _:
              data[key] = pref.getStringList(key);
              break;
            case List<bool> _:
              data[key] =
                  pref.getStringList(key)?.map((e) => bool.parse(e)).toList();
            case List<int> _:
              data[key] =
                  pref.getStringList(key)?.map((e) => int.parse(e)).toList();
            case List<double> _:
              data[key] =
                  pref.getStringList(key)?.map((e) => double.parse(e)).toList();
              break;
            default:
              throw UnsupportedError(
                  "${value.runtimeType} of $key not supported");
          }
          break;
        case MapEntry(key: String key, value: dynamic value):
          throw UnsupportedError("${value.runtimeType} of $key not supported");
      }
    }
    return AppSettings.fromPrefMap(data); */
  // #endregion SharedPreferences

  static final defaultSettings =
      AppSettings.fromRecord(AppSettingsRecord.defaultSettings);
  static final priorSettings = LazyInitializer(loadSettingsFromFile);

  // #region Singleton
  static final _instance = LazyInitializer<AppSettings>(loadInstance);
  static Future<AppSettings> get instance async =>
      _instance.isAssigned ? _instance.$ : await _instance.getItem();
  static AppSettings? get i => _instance.$Safe;
  // #endregion Singleton
  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  Map<String, dynamic> toJson() => toRecord().toJson();
  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      AppSettings.fromRecord(AppSettingsRecord.fromJson(json));
  Map<String, dynamic> toPrefMap([
    String prefix = localStoragePrefix,
  ]) {
    final json =
            toJson().map((k, v) => MapEntry<String, dynamic>("$prefix.$k", v)),
        waitList = <String, dynamic>{},
        toRemove = <String>[];

    json.addAll((json["$prefix.postView"] as Map<String, dynamic>)
        .map<String, dynamic>(
            (k, v) => MapEntry<String, dynamic>("$prefix.postView.$k", v)));
    json.addAll((json["$prefix.searchView"] as Map<String, dynamic>)
        .map<String, dynamic>(
            (k, v) => MapEntry<String, dynamic>("$prefix.searchView.$k", v)));
    json.remove("$prefix.postView");
    json.remove("$prefix.searchView");
    json.entries.forEach((e) {
      if (e.value is Map<String, dynamic>) {
        toRemove.add(e.key);
        waitList.addAll((e.value as Map<String, dynamic>)
            .map((key, value) => MapEntry("${e.key}.$key", value)));
      }
    });
    json.addAll(waitList);
    toRemove.forEach(json.remove);
    final failure = json.entries
        .where((e) => switch (e.value) {
              int _ ||
              String _ ||
              double _ ||
              bool _ ||
              List<int> _ ||
              List<String> _ ||
              List<double> _ ||
              List<bool> _ =>
                false,
              _ => true,
            })
        .fold("", (p, e) => "$p ${e.key} (${e.value.runtimeType})");
    assert(failure.isEmpty,
        "$failure are not of type int, String, double, bool, List<int>, List<String>, List<double>, List<bool>");
    return json;
  }

  /* factory AppSettings.fromPrefMap(
    Map<String, dynamic> json, [
    String prefix = localStoragePrefix,
  ]) {
    return AppSettings.fromJson(json.entries.fold(
      {"postView": <String, dynamic>{}, "searchView": <String, dynamic>{}},
      (p, e) => e.key.startsWith("$prefix.postView.")
          ? (p
            ..["postView"]![e.key.substring("$prefix.postView.".length)] =
                e.value)
          : e.key.startsWith("$prefix.searchView.")
              ? (p
                ..["searchView"]![
                    e.key.substring("$prefix.searchView.".length)] = e.value)
              : (p..[e.key.substring(e.key.indexOf(".") + 1)] = e.value),
    ));
  } */
  // #endregion JSON (indirect, don't need updating w/ new fields)

  factory AppSettings.fromRecord(AppSettingsRecord r) => AppSettings.all(
        postView: PostView.fromData(r.postView),
        searchView: SearchView.fromData(r.searchView),
        favoriteTags: Set<String>.from(r.favoriteTags),
        blacklistedTags: Set<String>.from(r.blacklistedTags),
        forceSafe: r.forceSafe,
        autoLoadUserProfile: r.autoLoadUserProfile,
        applyProfileBlacklist: r.applyProfileBlacklist,
        applyProfileFavTags: r.applyProfileFavTags,
        upvoteOnFavorite: r.upvoteOnFavorite,
        enableDownloads: r.enableDownloads,
        maxSearchesToSave: r.maxSearchesToSave,
      );
  AppSettingsRecord toRecord() => AppSettingsRecord(
        postView: _postView.toData(),
        searchView: _searchView.toData(),
        favoriteTags: Set.unmodifiable(_favoriteTags),
        blacklistedTags: Set.unmodifiable(_blacklistedTags),
        forceSafe: _forceSafe,
        autoLoadUserProfile: _autoLoadUserProfile,
        applyProfileBlacklist: _applyProfileBlacklist,
        applyProfileFavTags: _applyProfileFavTags,
        upvoteOnFavorite: _upvoteOnFavorite,
        enableDownloads: _enableDownloads,
        maxSearchesToSave: _maxSearchesToSave,
      );
  void overwriteWithRecord([
    AppSettingsRecord r = AppSettingsRecord.defaultSettings,
  ]) {
    _postView.overwriteWithData(r.postView);
    _searchView.overwriteWithData(r.searchView);
    _favoriteTags = Set.of(r.favoriteTags);
    _blacklistedTags = Set.of(r.blacklistedTags);
    _forceSafe = r.forceSafe;
    _autoLoadUserProfile = r.autoLoadUserProfile;
    _applyProfileBlacklist = r.applyProfileBlacklist;
    _applyProfileFavTags = r.applyProfileFavTags;
    _upvoteOnFavorite = r.upvoteOnFavorite;
    _enableDownloads = r.enableDownloads;
    _maxSearchesToSave = r.maxSearchesToSave;
  }

  AppSettings.all({
    required PostView postView,
    required SearchView searchView,
    required Set<String> favoriteTags,
    required Set<String> blacklistedTags,
    required bool forceSafe,
    required bool autoLoadUserProfile,
    required bool applyProfileBlacklist,
    required bool applyProfileFavTags,
    required bool upvoteOnFavorite,
    required bool enableDownloads,
    required int maxSearchesToSave,
  })  : _postView = postView,
        _searchView = searchView,
        _favoriteTags = favoriteTags,
        _blacklistedTags = blacklistedTags,
        _forceSafe = forceSafe,
        _autoLoadUserProfile = autoLoadUserProfile,
        _applyProfileBlacklist = applyProfileBlacklist,
        _applyProfileFavTags = applyProfileFavTags,
        _upvoteOnFavorite = upvoteOnFavorite,
        _enableDownloads = enableDownloads,
        _maxSearchesToSave = maxSearchesToSave;
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
  Set<String> get favoriteTagsAll => applyProfileFavTags &&
          E621.loggedInUser.isAssigned &&
          E621.loggedInUser.$.favoriteTags.isNotEmpty
      ? (_favoriteTags
        ..addAll(E621.loggedInUser.$.favoriteTags.split(RegExp(r"\s"))))
      : _favoriteTags;
  // TODO: backing store for all blacklisted tags
  Set<String> _blacklistedTags;
  @override
  Set<String> get blacklistedTags => _blacklistedTags;
  set blacklistedTags(Set<String> value) => _blacklistedTags = value;
  Set<String> get blacklistedTagsAll => applyProfileBlacklist &&
          E621.loggedInUser.isAssigned &&
          E621.loggedInUser.$.blacklistedTags.isNotEmpty
      ? (_blacklistedTags
        ..addAll(E621.loggedInUser.$.blacklistedTags.split(RegExp(r"\s"))))
      : _blacklistedTags;
  bool _forceSafe;
  @override
  bool get forceSafe => _forceSafe;
  set forceSafe(bool value) {
    if (this == i && e621.useNsfw != !value) {
      e621.useNsfw = !value;
    }
    _forceSafe = value;
  }

  bool _autoLoadUserProfile;
  @override
  bool get autoLoadUserProfile => _autoLoadUserProfile;
  set autoLoadUserProfile(bool value) => _autoLoadUserProfile = value;

  bool _applyProfileBlacklist;
  @override
  bool get applyProfileBlacklist => _applyProfileBlacklist;
  set applyProfileBlacklist(bool value) => _applyProfileBlacklist = value;

  bool _applyProfileFavTags;
  @override
  bool get applyProfileFavTags => _applyProfileFavTags;
  set applyProfileFavTags(bool value) => _applyProfileFavTags = value;

  bool _upvoteOnFavorite;
  @override
  bool get upvoteOnFavorite => _upvoteOnFavorite;
  set upvoteOnFavorite(bool value) => _upvoteOnFavorite = value;

  bool _enableDownloads;
  @override
  bool get enableDownloads => _enableDownloads;
  set enableDownloads(bool value) => _enableDownloads = value;

  int _maxSearchesToSave;
  @override
  int get maxSearchesToSave => _maxSearchesToSave;
  set maxSearchesToSave(int value) => _maxSearchesToSave = value;
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
    videoQuality: FilterQuality.medium,
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
  final FilterQuality videoQuality;
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
    required this.videoQuality,
    required this.useProgressiveImages,
    required this.imageFilterQuality,
  });
  factory PostViewData.fromJson(Map<String, dynamic> json) => PostViewData(
        tagOrder: (json["tagOrder"] as List?)
                ?.map((e) => TagCategory.fromJson(e))
                .toList() ??
            defaultData.tagOrder,
        tagColors: (json["tagColors"])?.map<TagCategory, Color>((k, v) =>
                MapEntry<TagCategory, Color>(
                    TagCategory.fromJson(k),
                    (v != null
                        ? Color(v)
                        : defaultData.tagColors[TagCategory.fromJson(k)])!)) ??
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
        videoQuality: FilterQuality.values.singleWhere((e) =>
            e.name == (json["videoQuality"] ?? defaultData.videoQuality.name)),
        useProgressiveImages:
            json["useProgressiveImages"] ?? defaultData.useProgressiveImages,
        imageFilterQuality: FilterQuality.values.singleWhere((e) =>
            e.name ==
            (json["imageFilterQuality"] ??
                defaultData.imageFilterQuality.name)),
      );
  Map<String, dynamic> toJson() => {
        "tagOrder": tagOrder.map<String>((e) => e.toJson()).toList(),
        "tagColors":
            tagColors.map<String, int>((k, v) => MapEntry(k.toJson(), v.value)),
        "colorTags": colorTags,
        "colorTagHeaders": colorTagHeaders,
        // "allowOverflow": allowOverflow,
        "forceHighQualityImage": forceHighQualityImage,
        "autoplayVideo": autoplayVideo,
        "startVideoMuted": startVideoMuted,
        "showTimeLeft": showTimeLeft,
        "startWithTagsExpanded": startWithTagsExpanded,
        "startWithDescriptionExpanded": startWithDescriptionExpanded,
        "imageQuality": imageQuality.name,
        "videoQuality": videoQuality.name,
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
  FilterQuality _videoQuality;
  @override
  FilterQuality get videoQuality => _videoQuality;
  set videoQuality(FilterQuality v) => _videoQuality = v;
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
    required FilterQuality videoQuality,
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
        _videoQuality = videoQuality,
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
        videoQuality: postView.videoQuality,
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
    videoQuality = postView.videoQuality;
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
        videoQuality: videoQuality,
        useProgressiveImages: useProgressiveImages,
        imageFilterQuality: imageFilterQuality,
      );

  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  Map<String, dynamic> toJson() => toData().toJson();
  factory PostView.fromJson(Map<String, dynamic> json) =>
      PostView.fromData(PostViewData.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  // #region Singleton
  static PostView get instance => AppSettings.i!.postView;
  static PostView get i => instance;
  // #endregion Singleton
}

class SearchViewData {
  static const postsPerPageBounds = (min: 1, max: 320),
      postsPerRowBounds = (min: 1, max: 30),
      horizontalGridSpaceBounds = (min: 0.0, max: 10.0),
      verticalGridSpaceBounds = horizontalGridSpaceBounds,
      widthToHeightRatioBounds = (min: .5, max: 2.0),
      defaultData = SearchViewData(
        postsPerPage: 50,
        postsPerRow: 3,
        horizontalGridSpace: 4,
        verticalGridSpace: 4,
        postInfoBannerItems: PostInfoPaneItem.valuesSet,
        widthToHeightRatio: 1,
        useProgressiveImages: true,
        numSavedSearchesInSearchBar: 5,
        lazyLoad: false,
        blacklistFavs: false,
        lazyBuilding: false,
        preferPoolName: true,
        preferSetShortname: true,
        tagDbPath: "",
        maxCharsInPostInfo: 100,
      );
  final int postsPerPage;
  final int postsPerRow;
  final double horizontalGridSpace;
  final double verticalGridSpace;
  final Set<PostInfoPaneItem> postInfoBannerItems;
  final double widthToHeightRatio;
  final bool useProgressiveImages;
  final int numSavedSearchesInSearchBar;
  final bool lazyLoad;
  final bool lazyBuilding;
  final bool preferPoolName;

  /// {@template blacklistFavs}
  /// Apply blacklist to favorited posts.
  ///
  /// If you've favorited it, you're likely view it as an exception to your
  /// blacklist.
  ///
  /// Defaults to false.
  /// {@endtemplate}
  final bool blacklistFavs;
  final bool preferSetShortname;
  final String tagDbPath;
  final int maxCharsInPostInfo;
  const SearchViewData({
    required this.postsPerPage,
    required this.postsPerRow,
    required this.horizontalGridSpace,
    required this.verticalGridSpace,
    required this.postInfoBannerItems,
    required this.widthToHeightRatio,
    required this.useProgressiveImages,
    required this.numSavedSearchesInSearchBar,
    required this.lazyLoad,
    required this.blacklistFavs,
    required this.lazyBuilding,
    required this.preferPoolName,
    required this.preferSetShortname,
    required this.tagDbPath,
    required this.maxCharsInPostInfo,
  });
  static _postInfoBannerItemsParser(Map<String, dynamic> json) {
    try {
      return (json["postInfoBannerItems"] as List?)
          ?.map((e) => PostInfoPaneItem.fromJson(e))
          .toSet();
    } catch (_) {
      return (json["postInfoBannerItems"] as String?)
          ?.replaceAll(RegExp(r"^{|}$"), "")
          .split(",")
          .map((e) => PostInfoPaneItem.fromJson(e))
          .toSet();
    }
  }

  factory SearchViewData.fromJson(Map<String, dynamic> json) => SearchViewData(
        postsPerPage: json["postsPerPage"] ?? defaultData.postsPerPage,
        postsPerRow: json["postsPerRow"] ?? defaultData.postsPerRow,
        horizontalGridSpace:
            json["horizontalGridSpace"] ?? defaultData.horizontalGridSpace,
        verticalGridSpace:
            json["verticalGridSpace"] ?? defaultData.verticalGridSpace,
        postInfoBannerItems:
            _postInfoBannerItemsParser(json) ?? defaultData.postInfoBannerItems,
        /* postInfoBannerItems: (json["postInfoBannerItems"] as List?)
                ?.map((e) => PostInfoPaneItem.fromJson(e))
                .toSet() ??
            defaultData.postInfoBannerItems, */
        // postInfoBannerItems: (json["postInfoBannerItems"] as String?)
        //         ?.replaceAll(RegExp(r"^{|}$"), "")
        //         .split(",")
        //         .map((e) => PostInfoPaneItem.fromJson(e))
        //         .toSet() ??
        //     defaultData.postInfoBannerItems,
        widthToHeightRatio:
            json["widthToHeightRatio"] ?? defaultData.widthToHeightRatio,
        useProgressiveImages:
            json["useProgressiveImages"] ?? defaultData.useProgressiveImages,
        numSavedSearchesInSearchBar: json["numSavedSearchesInSearchBar"] ??
            defaultData.numSavedSearchesInSearchBar,
        lazyLoad: json["lazyLoad"] ?? defaultData.lazyLoad,
        lazyBuilding: json["lazyBuilding"] ?? defaultData.lazyBuilding,
        preferPoolName: json["preferPoolName"] ?? defaultData.preferPoolName,
        blacklistFavs: json["blacklistFavs"] ?? defaultData.blacklistFavs,
        preferSetShortname:
            json["preferSetShortname"] ?? defaultData.preferSetShortname,
        tagDbPath: json["tagDbPath"] ?? defaultData.tagDbPath,
        maxCharsInPostInfo:
            json["maxCharsInPostInfo"] ?? defaultData.maxCharsInPostInfo,
      );
  Map<String, dynamic> toJson() => {
        "postsPerPage": postsPerPage,
        "postsPerRow": postsPerRow,
        "horizontalGridSpace": horizontalGridSpace,
        "verticalGridSpace": verticalGridSpace,
        "postInfoBannerItems":
            postInfoBannerItems.map((e) => e.name).toList(growable: false),
        // "postInfoBannerItems": "{${postInfoBannerItems.fold(
        //   "",
        //   (previousValue, element) =>
        //       "$previousValue${previousValue.isNotEmpty ? ',' : ""}"
        //       "${element.name}",
        // )}}",
        "widthToHeightRatio": widthToHeightRatio,
        "useProgressiveImages": useProgressiveImages,
        "numSavedSearchesInSearchBar": numSavedSearchesInSearchBar,
        "lazyLoad": lazyLoad,
        "lazyBuilding": lazyBuilding,
        "preferPoolName": preferPoolName,
        "blacklistFavs": blacklistFavs,
        "preferSetShortname": preferSetShortname,
        "tagDbPath": tagDbPath,
        "maxCharsInPostInfo": maxCharsInPostInfo,
      };
}

class SearchView implements SearchViewData {
  static SliverGridDelegateWithFixedCrossAxisCount get gridDelegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: SearchView.i.postsPerRow,
        crossAxisSpacing: SearchView.i.horizontalGridSpace,
        mainAxisSpacing: SearchView.i.verticalGridSpace,
        childAspectRatio: SearchView.i.widthToHeightRatio,
      );
  int _postsPerPage;
  @override
  int get postsPerPage => _postsPerPage;
  set postsPerPage(int v) => (v >= SearchViewData.postsPerPageBounds.min &&
          v <= SearchViewData.postsPerPageBounds.max)
      ? _postsPerPage = v
      : "";
  int _postsPerRow;
  @override
  int get postsPerRow => _postsPerRow;
  set postsPerRow(int v) => (v >= SearchViewData.postsPerRowBounds.min &&
          v <= SearchViewData.postsPerRowBounds.max)
      ? _postsPerRow = v
      : "";
  double _horizontalGridSpace;
  @override
  double get horizontalGridSpace => _horizontalGridSpace;
  set horizontalGridSpace(double v) =>
      (v >= SearchViewData.horizontalGridSpaceBounds.min &&
              v <= SearchViewData.horizontalGridSpaceBounds.max)
          ? _horizontalGridSpace = v
          : "";
  double _verticalGridSpace;
  @override
  double get verticalGridSpace => _verticalGridSpace;
  set verticalGridSpace(double v) =>
      (v >= SearchViewData.verticalGridSpaceBounds.min &&
              v <= SearchViewData.verticalGridSpaceBounds.max)
          ? _verticalGridSpace = v
          : "";
  Set<PostInfoPaneItem> _postInfoBannerItems;
  @override
  Set<PostInfoPaneItem> get postInfoBannerItems => _postInfoBannerItems;
  set postInfoBannerItems(Set<PostInfoPaneItem> v) => _postInfoBannerItems = v;
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
  bool _preferPoolName;
  @override
  bool get preferPoolName => _preferPoolName;
  set preferPoolName(bool v) => _preferPoolName = v;

  /// {@macro blacklistFavs}
  bool _blacklistFavs;

  /// {@macro blacklistFavs}
  @override
  bool get blacklistFavs => _blacklistFavs;
  set blacklistFavs(bool v) => _blacklistFavs = v;
  bool _preferSetShortname;
  @override
  bool get preferSetShortname => _preferSetShortname;
  set preferSetShortname(bool v) => _preferSetShortname = v;
  String _tagDbPath;
  @override
  String get tagDbPath => _tagDbPath;
  set tagDbPath(String v) => _tagDbPath = v;
  int _maxCharsInPostInfo;
  @override
  int get maxCharsInPostInfo => _maxCharsInPostInfo;
  set maxCharsInPostInfo(int v) => (v >= 0) ? _maxCharsInPostInfo = v : "";
  SearchView({
    required int postsPerPage,
    required int postsPerRow,
    required double horizontalGridSpace,
    required double verticalGridSpace,
    required int maxCharsInPostInfo,
    required Set<PostInfoPaneItem> postInfoBannerItems,
    required double widthToHeightRatio,
    required bool useProgressiveImages,
    required int numSavedSearchesInSearchBar,
    required bool lazyLoad,
    required bool blacklistFavs,
    required bool lazyBuilding,
    required bool preferPoolName,
    required bool preferSetShortname,
    required String tagDbPath,
  })  : _postsPerPage = postsPerPage,
        _postsPerRow = postsPerRow,
        _horizontalGridSpace = horizontalGridSpace,
        _verticalGridSpace = verticalGridSpace,
        _postInfoBannerItems = postInfoBannerItems,
        _widthToHeightRatio = widthToHeightRatio,
        _useProgressiveImages = useProgressiveImages,
        _numSavedSearchesInSearchBar = numSavedSearchesInSearchBar,
        _lazyLoad = lazyLoad,
        _blacklistFavs = blacklistFavs,
        _lazyBuilding = lazyBuilding,
        _preferPoolName = preferPoolName,
        _preferSetShortname = preferSetShortname,
        _tagDbPath = tagDbPath,
        _maxCharsInPostInfo = maxCharsInPostInfo;

  factory SearchView.fromData(SearchViewData searchView) => SearchView(
        postsPerPage: searchView.postsPerPage,
        postsPerRow: searchView.postsPerRow,
        horizontalGridSpace: searchView.horizontalGridSpace,
        verticalGridSpace: searchView.verticalGridSpace,
        postInfoBannerItems: searchView.postInfoBannerItems,
        widthToHeightRatio: searchView.widthToHeightRatio,
        useProgressiveImages: searchView.useProgressiveImages,
        numSavedSearchesInSearchBar: searchView.numSavedSearchesInSearchBar,
        lazyLoad: searchView.lazyLoad,
        blacklistFavs: searchView.blacklistFavs,
        lazyBuilding: searchView.lazyBuilding,
        preferPoolName: searchView.preferPoolName,
        preferSetShortname: searchView.preferSetShortname,
        tagDbPath: searchView.tagDbPath,
        maxCharsInPostInfo: searchView.maxCharsInPostInfo,
      );
  void overwriteWithData(SearchViewData searchView) {
    _postsPerPage = searchView.postsPerPage;
    _postsPerRow = searchView.postsPerRow;
    _horizontalGridSpace = searchView.horizontalGridSpace;
    _verticalGridSpace = searchView.verticalGridSpace;
    _postInfoBannerItems = searchView.postInfoBannerItems.toSet();
    _widthToHeightRatio = searchView.widthToHeightRatio;
    _useProgressiveImages = searchView.useProgressiveImages;
    _numSavedSearchesInSearchBar = searchView.numSavedSearchesInSearchBar;
    _lazyLoad = searchView.lazyLoad;
    _blacklistFavs = searchView.blacklistFavs;
    _lazyBuilding = searchView.lazyBuilding;
    _preferPoolName = searchView.preferPoolName;
    _preferSetShortname = searchView.preferSetShortname;
    _tagDbPath = searchView.tagDbPath;
    _maxCharsInPostInfo = searchView.maxCharsInPostInfo;
  }

  SearchViewData toData() => SearchViewData(
        postsPerPage: postsPerPage,
        postsPerRow: postsPerRow,
        horizontalGridSpace: horizontalGridSpace,
        verticalGridSpace: verticalGridSpace,
        postInfoBannerItems: postInfoBannerItems,
        widthToHeightRatio: widthToHeightRatio,
        useProgressiveImages: useProgressiveImages,
        numSavedSearchesInSearchBar: numSavedSearchesInSearchBar,
        lazyLoad: lazyLoad,
        blacklistFavs: blacklistFavs,
        lazyBuilding: lazyBuilding,
        preferPoolName: preferPoolName,
        preferSetShortname: preferSetShortname,
        tagDbPath: tagDbPath,
        maxCharsInPostInfo: maxCharsInPostInfo,
      );

  // #region JSON (indirect, don't need updating w/ new fields)
  @override
  Map<String, dynamic> toJson() => toData().toJson();
  factory SearchView.fromJson(Map<String, dynamic> json) =>
      SearchView.fromData(SearchViewData.fromJson(json));
  // #endregion JSON (indirect, don't need updating w/ new fields)
  // #region Singleton (don't need updating w/ new fields)
  static SearchView get instance => AppSettings.i!.searchView;
  static SearchView get i => instance;
  // #endregion Singleton (don't need updating w/ new fields)
}
