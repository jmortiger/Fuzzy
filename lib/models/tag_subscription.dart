import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/log_management.dart' show LogReq, LogRes;
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart'
    show LazyInitializer, ListIterators, Platform, StatusCodes;
import 'package:j_util/serialization.dart';
import 'package:shared_preferences/shared_preferences.dart' as sp;

class TagSubscription {
  final String tag;
  final int lastId;
  final Set<int> cachedPosts;

  const TagSubscription(
      {required this.tag, this.lastId = -1, this.cachedPosts = const {}});

  Map<String, dynamic> toJson() => {
        "tag": tag,
        "lastId": lastId,
        "cachedPosts": cachedPosts,
      };
  factory TagSubscription.fromJson(Map<String, dynamic> json) =>
      TagSubscription(
        tag: json["tag"],
        lastId: json["lastId"],
        cachedPosts: json["cachedPosts"],
      );
  List<Future<bool>> writeToPref(String prefix, sp.SharedPreferences pref) => [
        pref.setString("$prefix.tag", tag),
        pref.setInt("$prefix.lastId", lastId),
        pref.setStringList("$prefix.cachedPosts",
            cachedPosts.map((e) => e.toString()).toList()),
      ];
  static TagSubscription? loadFromPrefSafe(
      String prefix, sp.SharedPreferences pref) {
    final tag = pref.getString("$prefix.tag");
    final lastId = pref.getInt("$prefix.lastId");
    final cachedPosts = pref
        .getStringList("$prefix.cachedPosts")
        ?.map((e) => int.parse(e))
        .toSet();
    return tag == null || lastId == null || cachedPosts == null
        ? null
        : TagSubscription(
            tag: tag,
            lastId: lastId,
            cachedPosts: cachedPosts,
          );
  }

  factory TagSubscription.loadFromPref(
          String prefix, sp.SharedPreferences pref) =>
      TagSubscription(
        tag: pref.getString("$prefix.tag")!,
        lastId: pref.getInt("$prefix.lastId")!,
        cachedPosts: pref
            .getStringList("$prefix.cachedPosts")!
            .map((e) => int.parse(e))
            .toSet(),
      );

  TagSubscription copyWith({
    String? tag,
    int? lastId,
    Set<int>? cachedPosts,
  }) =>
      TagSubscription(
        tag: tag ?? this.tag,
        lastId: lastId ?? this.lastId,
        cachedPosts: cachedPosts ?? this.cachedPosts,
      );
}

class SubscriptionManager {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("SubscriptionManager");
  // #endregion Logger

  // #region IO
  static const fileName = "savedSearches.json";
  static final fileFullPath = LazyInitializer.immediate(fileFullPathInit);

  static Future<String> fileFullPathInit() async {
    print("fileFullPathInit called");
    try {
      return (Platform.isWeb
          ? ""
          : "${await util.appDataPath.getItem()}/$fileName")
        ..printMe();
    } catch (e) {
      print("Error in fileFullPathInit():\n$e");
      return "";
    }
  }

  static final file = LazyInitializer<File?>(() async => !Platform.isWeb
      ? Storable.getStorageAsync(await fileFullPath.getItem())
      : null);
  static const localStoragePrefix = 'tsm';
  static const localStorageLengthKey = '$localStoragePrefix.length';

  static Future<List<TagSubscription>> get storageAsync async =>
      await ((await file.getItemAsync())
              ?.readAsString()
              .then((v) => SubscriptionManager.fromJson(jsonDecode(v))) ??
          loadFromPref());
  static List<TagSubscription>? get storageSync {
    String? t = file.$Safe?.readAsStringSync();
    return (t == null)
        ? loadFromPrefTrySync()
        : SubscriptionManager.fromJson(jsonDecode(t));
  }

  static Future<bool> writeToPref([List<TagSubscription>? collection]) {
    collection ??= SubscriptionManager._subscriptions;
    return util.pref.getItemAsync().then((v) {
      final l = v.setInt(localStorageLengthKey, collection!.length);
      final success = <Future<bool>>[];
      for (var i = 0; i < collection.length; i++) {
        final e1 = collection[i];
        e1.writeToPref("$localStoragePrefix.$i", v);
      }
      return success.fold(
          l,
          (previousValue, element) => (previousValue is Future<bool>)
              ? previousValue.then((s) => element.then((s1) => s && s1))
              : element.then((s1) => previousValue && s1));
    });
  }

  static Future<List<TagSubscription>> loadFromPref({bool store = true}) =>
      util.pref.getItemAsync().then((v) {
        final length = v.getInt(localStorageLengthKey) ?? 0;
        var data = <TagSubscription>[];
        for (var i = 0; i < length; i++) {
          data.add(
            TagSubscription.loadFromPref("$localStoragePrefix.$i", v),
          );
        }
        return store ? _subscriptions = data : data;
      });
  static List<TagSubscription>? loadFromPrefTrySync({bool store = true}) {
    if (util.pref.$Safe == null) return null;
    final length = util.pref.$.getInt(localStorageLengthKey) ?? 0;
    var data = <TagSubscription>[];
    for (var i = 0; i < length; i++) {
      data.add(
        TagSubscription.loadFromPref("$localStoragePrefix.$i", util.pref.$),
      );
    }
    return store ? _subscriptions = data : data;
  }

  static FutureOr<List<TagSubscription>> loadFromStorageAsync(
      {bool store = true}) async {
    var str = await Storable.tryLoadStringAsync(
      await fileFullPath.getItem(),
    );
    if (str == null) {
      try {
        final t = SubscriptionManager.fromJson({"subscriptions": []});
        return store ? _subscriptions = t : t;
      } catch (e) {
        final t = <TagSubscription>[];
        return store ? _subscriptions = t : t;
      }
    } else {
      final t = SubscriptionManager.fromJson(jsonDecode(str));
      return store ? _subscriptions = t : t;
    }
  }

  static List<TagSubscription>? loadFromStorageSync({bool store = true}) {
    var str = Storable.tryLoadStringSync(fileFullPath.$);
    if (str == null) {
      try {
        final t = SubscriptionManager.fromJson({"subscriptions": []});
        return store ? _subscriptions = t : t;
      } catch (e) {
        final t = <TagSubscription>[];
        return store ? _subscriptions = t : t;
      }
    } else {
      final t = SubscriptionManager.fromJson(jsonDecode(str));
      return store ? _subscriptions = t : t;
    }
  }

  static List<TagSubscription> fromJson(Map<String, dynamic> json) =>
      List.of((json["subscriptions"] as List).mapAsList(
        (e, index, list) => TagSubscription.fromJson(e),
      ));
  static Map<String, dynamic> toJson() => {
        "subscriptions": subscriptions,
      };
  static void writeToStorage(/* [List<TagSubscription>? data] */) {
    // data ??= _subscriptions;
    if (!Platform.isWeb) {
      file.$Safe
          ?.writeAsString(jsonEncode(toJson()))
          .catchError((e, s) {
            print(e, lm.LogLevel.WARNING, e, s);
            return e;
          })
          .then(
            (value) => print("Write successful"),
          )
          .catchError((e, s) => print(e, lm.LogLevel.WARNING, e, s));
    } else {
      writeToPref().then((v) => v
          ? print("SavedDataE6 stored successfully: ${jsonEncode(toJson())}",
              lm.LogLevel.FINE)
          : print("SavedDataE6 failed to store: ${jsonEncode(toJson())}",
              lm.LogLevel.SEVERE));
    }
  }

  // #endregion IO
  static late List<TagSubscription> _subscriptions;
  static List<TagSubscription> get subscriptions => _subscriptions;
  static const String batchTaskName = "checkSubscriptions";
  static bool get isInit {
    try {
      _subscriptions.isEmpty;
      return true;
    } catch (e) {
      return false;
    }
  }

  static Duration frequency = const Duration(hours: 12);
  static void initAndCheckSubscriptions({
    lm.FileLogger? logger,
    E621AccessData? accessData,
  }) async {
    logger ??= SubscriptionManager.logger;
    accessData ??= await E621AccessData.tryLoad();
    bool hasChanges = false;
    final l = await SubscriptionManager.loadFromStorageAsync();
    for (int i = 0; i < l.length; ++i) {
      final res = (await e621.sendRequest(
          e621.initSearchPostsRequest(
              credentials: accessData?.cred,
              tags: l[i].tag,
              limit: e621.maxPostsPerSearch)
            ..log(logger)))
        ..log(logger);
      if (res.statusCodeInfo.isSuccessful) {
        final posts = E6PostResponse.fromRawJsonResults(res.body).toList();
        final lastIndex =
            posts.lastIndexWhere((element) => element.id > l[i].lastId);
        if (lastIndex < 0 || lastIndex > posts.length) {
          continue;
        }
        l[i] = l[i].copyWith(
            cachedPosts: Set.of(l[i].cachedPosts)
              ..addAll(posts.take(lastIndex + 1).map((e) => e.id)));
        hasChanges = true;
        // TODO: NOTIFICATIONS
      }
    }
    if (hasChanges) {
      SubscriptionManager.writeToStorage();
    }
  }
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  String title = "";
  @override
  Widget build(BuildContext context) {
    return ErrorPage.errorWidgetWrapper(
      logger: SubscriptionManager.logger,
      () => !SubscriptionManager.isInit
          ? FutureBuilder(
              future: SubscriptionManager.storageAsync,
              builder: buildFutureFromStorage,
            )
          : buildRoot(SubscriptionManager.subscriptions),
    ).value;
  }

  Widget buildFutureFromStorage(
    BuildContext context,
    AsyncSnapshot<List<TagSubscription>> snapshot,
  ) {
    return snapshot.hasData ? buildRoot(snapshot.data!) : util.fullPageSpinner;
  }

  Scaffold buildRoot(List<TagSubscription> data) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageView(
          onPageChanged: (value) => setState(() {
                title = data.elementAtOrNull(value)?.tag ?? "";
              }),
          children: data.map(buildPostResultViewFromTagSubscription).toList()),
    );
  }

  Column buildPostResultViewFromTagSubscription(TagSubscription e) {
    return Column(
      children: [
        Text(e.tag),
        if (e.cachedPosts.isEmpty)
          const Text("No Results")
        else
          FutureBuilder(
            future: e621.sendRequest(
                e621.initSearchPostsRequest(
                    tags: e.cachedPosts.length > e621.maxTagsPerSearch
                        ? e.cachedPosts.fold("", (prior, t) => "~id:$t $prior")
                        : e.tag,
                    credentials: E621AccessData.fallbackForced?.cred,
                    limit: e621.maxPostsPerSearch)
                  ..log(SubscriptionManager.logger))
              ..then((v) => v.log(SubscriptionManager.logger)).ignore(),
            builder: buildFutureFromSearchResults,
          ),
      ],
    );
  }

  Widget buildFutureFromSearchResults(context, snapshot) {
    if (snapshot.hasData) {
      return ErrorPage.errorWidgetWrapper(logger: SubscriptionManager.logger,
          () {
        final ps = E6PostsSync.fromRawJson(snapshot.data!.body);
        return WPostSearchResults.sync(
          posts: ps,
          expectedCount: ps.length,
          stripToGridView: true,
          disallowSelections: true,
        );
      }).value;
    } else if (snapshot.hasError) {
      return ErrorPage.logError(
          error: snapshot.error,
          stackTrace: snapshot.stackTrace,
          logger: SubscriptionManager.logger);
    } else {
      return util.spinnerExpanded;
    }
  }
}

// class PersistentStorageManager {
//   static final Map<String, (File? file, Future<bool> Function(dynamic data) writeAsync, Future<dynamic> Function(File? file) readAsync)> ioData = {};
//   static void register()
// }
