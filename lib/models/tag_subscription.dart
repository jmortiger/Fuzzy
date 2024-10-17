import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/log_management.dart' show LogReq, LogRes;
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart' as util hide pref;
import 'package:fuzzy/util/shared_preferences.dart' as util;
import 'package:fuzzy/web/e621/dtext_formatter.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widget_lib.dart' as w;
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart'
    show LazyInitializer, Platform, StatusCodes;
import 'package:j_util/serialization.dart';
import 'package:shared_preferences/shared_preferences.dart' as sp;

class TagSubscription {
  final String tag;
  final int lastId;
  final Set<int> cachedPosts;

  const TagSubscription({
    required this.tag,
    this.lastId = -1,
    this.cachedPosts = const {},
  });

  Map<String, dynamic> toJson() => {
        "tag": tag,
        "lastId": lastId,
        "cachedPosts": cachedPosts.toList(),
      };
  factory TagSubscription.fromJson(Map<String, dynamic> json) =>
      TagSubscription(
        tag: json["tag"],
        lastId: json["lastId"],
        cachedPosts: (json["cachedPosts"] as List<int>).toSet(),
      );
  List<Future<bool>> writeToPref(String prefix, sp.SharedPreferences pref) => [
        pref.setString("$prefix.tag", tag),
        pref.setInt("$prefix.lastId", lastId),
        pref.setStringList("$prefix.cachedPosts",
            cachedPosts.map((e) => e.toString()).toList()),
      ];
  static List<Future<bool>> removeFromPref(
          String prefix, sp.SharedPreferences pref) =>
      [
        pref.remove("$prefix.tag"),
        pref.remove("$prefix.lastId"),
        pref.remove("$prefix.cachedPosts"),
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
  @override
  bool operator ==(Object other) =>
      other is TagSubscription && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;

  static const TagSubscription empty = TagSubscription(tag: "", lastId: 0);
}

class SubscriptionManager {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("SubscriptionManager");
  // #endregion Logger

  // #region IO
  static const fileName = "subscriptions.json";
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

  static Future< /* List<TagSubscription> */ Set<TagSubscription>>
      get storageAsync async => await ((await file.getItemAsync())
              ?.readAsString()
              .then((v) => SubscriptionManager.fromJson(jsonDecode(v))) ??
          loadFromPref());
  static /* List<TagSubscription> */ Set<TagSubscription>? get storageSync {
    String? t = file.$Safe?.readAsStringSync();
    return (t == null)
        ? loadFromPrefTrySync()
        : SubscriptionManager.fromJson(jsonDecode(t));
  }

  static Future<bool> writeToPref([Iterable<TagSubscription>? collection]) {
    collection ??= SubscriptionManager._subscriptions;
    return util.pref.getItemAsync().then((v) {
      final priorLength = v.getInt(localStorageLengthKey) ?? 0;
      final l = v.setInt(localStorageLengthKey, collection!.length);
      final success = <Future<bool>>[];
      for (var i = 0; i < collection.length; i++) {
        final e1 = collection.elementAt(i);
        success.addAll(e1.writeToPref("$localStoragePrefix.$i", v));
      }
      for (var i = collection.length; i < priorLength; i++) {
        TagSubscription.removeFromPref("$localStoragePrefix.$i", v);
      }
      return success.fold(
          l,
          (previousValue, element) => (previousValue is Future<bool>)
              ? previousValue.then((s) => element.then((s1) => s && s1))
              : element.then((s1) => previousValue && s1));
    });
  }

  static Future< /* List<TagSubscription> */ Set<TagSubscription>> loadFromPref(
          {bool store = true}) =>
      util.pref.getItemAsync().then((v) {
        final length = v.getInt(localStorageLengthKey) ?? 0;
        var data = <TagSubscription>{} /* [] */;
        for (var i = 0; i < length; i++) {
          data.add(
            TagSubscription.loadFromPref("$localStoragePrefix.$i", v),
          );
        }
        return store ? _subscriptions = data : data;
      });
  static /* List<TagSubscription> */ Set<TagSubscription>? loadFromPrefTrySync(
      {bool store = true}) {
    if (util.pref.$Safe == null) return null;
    final length = util.pref.$.getInt(localStorageLengthKey) ?? 0;
    var data = <TagSubscription>{} /* [] */;
    for (var i = 0; i < length; i++) {
      data.add(
        TagSubscription.loadFromPref("$localStoragePrefix.$i", util.pref.$),
      );
    }
    return store ? _subscriptions = data : data;
  }

  static FutureOr< /* List<TagSubscription> */ Set<TagSubscription>>
      loadFromStorageAsync({bool store = true}) async {
    final t = await storageAsync;
    return store ? _subscriptions = t : t;
    /* var str = await Storable.tryLoadStringAsync(
      await fileFullPath.getItem(),
    );
    if (str == null) {
      try {
        final t = SubscriptionManager.fromJson({"subscriptions": []});
        return store ? _subscriptions = t : t;
      } catch (e) {
        final t = <TagSubscription>{} /* [] */;
        return store ? _subscriptions = t : t;
      }
    } else {
      final t = SubscriptionManager.fromJson(jsonDecode(str));
      return store ? _subscriptions = t : t;
    } */
  }

  static /* List<TagSubscription> */ Set<TagSubscription>? loadFromStorageSync(
      {bool store = true}) {
    var str = Storable.tryLoadStringSync(fileFullPath.$);
    if (str == null) {
      try {
        final t = SubscriptionManager.fromJson({"subscriptions": []});
        return store ? _subscriptions = t : t;
      } catch (e) {
        final t = <TagSubscription>{} /* [] */;
        return store ? _subscriptions = t : t;
      }
    } else {
      final t = SubscriptionManager.fromJson(jsonDecode(str));
      return store ? _subscriptions = t : t;
    }
  }

  static /* List<TagSubscription> */ Set<TagSubscription> fromJson(
          Map<String, dynamic> json) =>
      /* List */ Set.of((json["subscriptions"] as List)
          .map((e) => TagSubscription.fromJson(e)));
  static Map<String, dynamic> toJson() => {
        "subscriptions": subscriptions,
      };
  static Future<bool> writeToStorage(/* [List<TagSubscription>? data] */) {
    // data ??= _subscriptions;
    return (!Platform.isWeb
        ? file
            .getItemAsync()
            .then((v) => v!.writeAsString(jsonEncode(toJson())))
            .then((_) => true)
            .catchError((_) => false)
        : writeToPref())
      ..then((v) => v
              ? logger.fine(
                  "SubscriptionManager stored successfully: ${jsonEncode(toJson())}")
              : logger.warning(
                  "SubscriptionManager failed to store: ${jsonEncode(toJson())}"))
          .ignore();
  }

  // #endregion IO
  static late /* List<TagSubscription> */ Set<TagSubscription> _subscriptions;
  static /* List<TagSubscription> */ Set<TagSubscription> get subscriptions =>
      _subscriptions;
  static const String batchTaskName = "checkSubscriptions";
  static bool get isInit {
    try {
      _subscriptions.isEmpty;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Duration frequency = const Duration(hours: 12);
  static Future<void> initAndCheckSubscriptions({
    lm.FileLogger? logger,
    E621AccessData? accessData,
  }) async {
    logger ??= SubscriptionManager.logger;
    accessData ??= await E621AccessData.tryLoad();
    bool hasChanges = false;
    final l = await SubscriptionManager.loadFromStorageAsync();
    for (var e in l) {
      final res = (await e621.sendRequest(
          e621.initPostSearch(
              credentials: accessData?.cred,
              tags: e.tag,
              limit: e621.maxPostSearchLimit)
            ..log(logger)))
        ..log(logger);
      if (res.statusCodeInfo.isSuccessful) {
        final posts = E6PostResponse.fromRawJsonResults(res.body).toList();
        final lastIndex =
            posts.lastIndexWhere((element) => element.id > e.lastId);
        if (lastIndex < 0 || lastIndex > posts.length) {
          continue;
        }
        l
          ..remove(e)
          ..add(e.copyWith(
              cachedPosts: Set.of(e.cachedPosts)
                ..addAll(posts.take(lastIndex + 1).map((e) => e.id))));
        hasChanges = true;
        // TODO: NOTIFICATIONS
      }
    }
    // for (int i = 0; i < l.length; ++i) {
    //   final res = (await e621.sendRequest(
    //       e621.initPostSearch(
    //           credentials: accessData?.cred,
    //           tags: l[i].tag,
    //           limit: e621.maxPostSearchLimit)
    //         ..log(logger)))
    //     ..log(logger);
    //   if (res.statusCodeInfo.isSuccessful) {
    //     final posts = E6PostResponse.fromRawJsonResults(res.body).toList();
    //     final lastIndex =
    //         posts.lastIndexWhere((element) => element.id > l[i].lastId);
    //     if (lastIndex < 0 || lastIndex > posts.length) {
    //       continue;
    //     }
    //     l[i] = l[i].copyWith(
    //         cachedPosts: Set.of(l[i].cachedPosts)
    //           ..addAll(posts.take(lastIndex + 1).map((e) => e.id)));
    //     hasChanges = true;
    //     // TODO: NOTIFICATIONS
    //   }
    // }
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

/// TOD: Fix layout bugs
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
    AsyncSnapshot< /* List<TagSubscription> */ Set<TagSubscription>> snapshot,
  ) {
    return snapshot.hasData ? buildRoot(snapshot.data!) : util.fullPageSpinner;
  }

  Scaffold buildRoot(/* List<TagSubscription> */ Set<TagSubscription> data) {
    return Scaffold(
      appBar: AppBar(title: Text.rich(parse("{{$title}}", context))),
      body: SafeArea(
        child: PageView(
            onPageChanged: (value) => setState(() {
                  title = data.elementAtOrNull(value)?.tag ?? "";
                }),
            children:
                data.map(buildPostResultViewFromTagSubscription).toList()),
      ),
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
                e621.initPostSearch(
                    tags: e.cachedPosts.length > e621.maxTagsPerSearch
                        ? e.cachedPosts.fold("", (prior, t) => "~id:$t $prior")
                        : e.tag,
                    credentials: E621AccessData.forcedUserDataSafe?.cred,
                    limit: e621.maxPostSearchLimit)
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
        return w.PostGrid(
          posts: ps,
          // expectedCount: ps.length,
          stripToGridView: true,
          disallowSelections: true,
          useProviderForPosts: false, filterBlacklist: false,
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
