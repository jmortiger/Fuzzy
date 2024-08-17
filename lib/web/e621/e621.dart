import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/e621.dart' as e621;

import 'package:fuzzy/log_management.dart' as lm;
import 'package:url_launcher/url_launcher.dart';

import 'e621_access_data.dart';

// #region Logger
late final lRecord = lm.generateLogger("E621");
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;

// #endregion Logger
sealed class E621 extends Site {
  @event
  static final favDeleted = JPureEvent();
  @event
  static final favFailed = JEvent<PostActionArgs>();
  @event
  static final favAdded = JEvent<PostActionArgs>();
  @event
  static final searchBegan = JEvent<SearchArgs>([
    (e) => logger.info("New User Search initiated"
        "\n\tTags: ${e.tags.foldToString()},"
        "\n\tPage: ${e.page},\n\t"
        "Limit: ${e.limit}")
  ]);
  @event
  static final searchEnded = JEvent<SearchResultArgs>();
  @event
  static final nonUserSearchBegan = JEvent<SearchArgs>();
  @event
  static final nonUserSearchEnded = JEvent<SearchResultArgs>();
  static const int hardRateLimit = 1;
  static const int softRateLimit = 2;
  static const int idealRateLimit = 3;
  static final http.Client client = http.Client();
  static const maxPostsPerSearch = e621.Api.maxPostsPerSearch;
  static DateTime timeOfLastRequest =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  // #region User Account Data
  static final loggedInUser = LateInstance<e621.UserLoggedIn>();

  /// Won't update unless [user] is non-null and of type [e621.UserLoggedIn].
  static bool tryUpdateLoggedInUser(e621.User? user) {
    if (user is e621.UserLoggedIn) {
      if (user is! e621.UserLoggedInDetail &&
          loggedInUser.$Safe is e621.UserLoggedInDetail) {
        loggedInUser.$ =
            (loggedInUser.$ as e621.UserLoggedInDetail).copyWithInstance(user);
      } else {
        loggedInUser.$ = user;
      }
      return true;
    } else {
      return false;
    }
  }

  static int get tagQueryLimit =>
      loggedInUser.isAssigned ? loggedInUser.$.tagQueryLimit : 40;
  static int get favoriteLimit =>
      loggedInUser.isAssigned ? loggedInUser.$.favoriteLimit : 80000;
  static bool get blacklistUsers =>
      loggedInUser.isAssigned ? loggedInUser.$.blacklistUsers : false;
  static String get blacklistedTags =>
      loggedInUser.isAssigned ? loggedInUser.$.blacklistedTags : "";
  static String get favoriteTags =>
      loggedInUser.isAssigned ? loggedInUser.$.favoriteTags : "";
  static int get apiBurstLimit =>
      loggedInUser.isAssigned ? loggedInUser.$.apiBurstLimit : 60;
  static int get apiRegenMultiplier =>
      loggedInUser.isAssigned ? loggedInUser.$.apiRegenMultiplier : 1;
  static int get remainingApiLimit =>
      loggedInUser.isAssigned ? loggedInUser.$.remainingApiLimit : 60;

  static FutureOr<e621.User?> retrieveUserNonDetailed(
      {e621.User? user, E621AccessData? data, String? username}) {
    if (user != null) return user;
    logger.finest("No User obj, trying access data");
    var d = (data ??
            E621AccessData.userData.$Safe ??
            (isDebug ? E621AccessData.devAccessData.$Safe : null))
        ?.cred;
    if (d == null) {
      logger.finest("No access data, trying by name");
    }
    username ??= d?.username;
    if (username == null || username.isEmpty) {
      logger.warning("No user info available: cannot find user");
      return null;
    }
    var r = e621.Api.initSearchUsersRequest(
      searchNameMatches: username,
      credentials: d,
      limit: 1,
    );
    logRequest(r, logger);
    return e621.Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logResponse(v, logger, lm.LogLevel.SEVERE);
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logResponse(v, logger, lm.LogLevel.WARNING);
        return null;
      } else {
        logResponse(v, logger, lm.LogLevel.INFO);
        try {
          return e621.UserLoggedIn.fromRawJson(v.body);
        } catch (e) {
          return e621.User.fromRawJson(v.body);
        }
      }
    });
  }

  /// Based on the provided user info, attempts to get, in order:
  /// 1. [UserLoggedInDetail]
  /// 1. [UserDetailed]
  /// 1. [UserLoggedIn]
  /// 1. [User]
  static FutureOr<e621.User?> retrieveUserMostSpecific({
    e621.User? user,
    E621AccessData? data,
    String? username,
    int? id,
    bool updateIfLoggedIn = true,
  }) {
    if (user != null) {
      if (user is e621.UserLoggedInDetail || user is e621.UserDetailed) {
        if (updateIfLoggedIn) tryUpdateLoggedInUser(user);
        return user;
      } else {
        id ??= user.id;
        logger.finest("Attempting to retrieve more specific user "
            "info for user ${user.id}/$id (${user.name}/$username)");
      }
    } else {
      logger.finest("No User obj, trying id");
    }
    var d = (data ??
            E621AccessData.userData.$Safe ??
            (isDebug ? E621AccessData.devAccessData.$Safe : null))
        ?.cred;
    if (id != null) {
      if (d == null) {
        logger.info("No credential data, can't get logged in data.");
      }
      var r = e621.Api.initGetUserRequest(
        id,
        credentials: d,
      );
      logRequest(r, logger);
      return e621.Api.sendRequest(r).then(E621.resolveGetUserFuture);
    }
    logger.finest("No id, trying access data");
    if (d == null) {
      logger.finest("No access data, trying by name");
    }
    username ??= d?.username;
    if (username == null || username.isEmpty) {
      logger.warning("No user info available: cannot find user");
      return null;
    }
    var r = e621.Api.initSearchUsersRequest(
      searchNameMatches: username,
      credentials: d,
      limit: 1,
    );
    logRequest(r, logger);
    return e621.Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logResponse(v, logger, lm.LogLevel.SEVERE);
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logResponse(v, logger, lm.LogLevel.WARNING);
        return null;
      } else {
        logResponse(v, logger, lm.LogLevel.FINER);
        e621.User t;
        try {
          t = e621.UserLoggedIn.fromRawJson(v.body);
        } catch (e) {
          t = e621.User.fromRawJson(v.body);
        }
        logger.info("Launching request for User ${t.id} (${t.name})");
        var r = e621.Api.initGetUserRequest(
          t.id,
          credentials: d,
        );
        logRequest(r, logger);
        return e621.Api.sendRequest(r).then(resolveGetUserFuture);
      }
    });
  }
  // #endregion User Account Data

  // #region Saved Search Parsing
  /// The (escaped) character used to delimit saved search insertion.
  static const savedSearchInsertionDelimiter = r"#";

  /// Matches either whitespace or the end of input without consuming characters
  static const savedSearchInsertionEnd =
      r'(?=' + RegExpExt.whitespacePattern + r'+?|$)';

  /// The (escaped) character used to delimit saved search insertion.
  static const delimiter = savedSearchInsertionDelimiter;

  /// Used to inject a saved search entry into a search using the entry's unique ID.
  ///
  /// Lazily expands
  /// #(.+?)(?=[\u2028\n\r\u000B\f\u2029\u0085 ]+?|$)
  static final savedSearchInsertion =
      RegExp("$delimiter(.+?)$savedSearchInsertionEnd");

  /// Used to inject a saved search entry into a search using the entry's unique ID.
  ///
  /// Matches all characters other than [delimiter]
  static final savedSearchInsertionAlt =
      RegExp("$delimiter([^$delimiter]+?)$savedSearchInsertionEnd");
  // #endregion Saved Search Parsing
  E621();
  // RegExp("(?<=^|\\+${RegExpExt.whitespacePattern})fav:${loggedInUser.$Safe?.name ?? E621AccessData.fallbackForced?.username ?? " "}(?=\$|${RegExpExt.whitespacePattern})", caseSensitive: false)
  static RegExp get userFavoriteSearchFinder => RegExp(
      r"(?<=^|[\u2028\n\r\u000B\f\u2029\u0085 	]|\+)fav:"
      "${loggedInUser.$Safe?.name ?? E621AccessData.fallbackForced?.username ?? " "}"
      r"(?=$|[\u2028\n\r\u000B\f\u2029\u0085 	])",
      caseSensitive: false);
  static String fillTagTemplate(String tags) {
    print("fillTagTemplate: Before: $tags");
    tags = tags.replaceAllMapped(
      savedSearchInsertion,
      (match) {
        try {
          return SavedDataE6.all
              .singleWhere((element) => element.uniqueId == match.group(1))
              .searchString;
        } catch (e) {
          return "";
        }
      },
    );
    print("fillTagTemplate: After: $tags", lm.LogLevel.FINER);
    if (!tags.contains(userFavoriteSearchFinder)) {
      tags += AppSettings.i?.blacklistedTags.map((e) => "-$e").fold(
                "",
                (p, e) => "$p $e",
              ) ??
          "";
      print("fillTagTemplate: After Blacklist: $tags", lm.LogLevel.FINER);
    } else {
      print("fillTagTemplate: User favorite search, not applying blacklist",
          lm.LogLevel.FINER);
    }
    return tags;
  }

  static Future<void> sendRequestBatch(
    Iterable<http.Request> Function() requestGenerator, {
    FutureOr<void> Function(List<http.StreamedResponse> responses)? onComplete,
    void Function(Object? error, StackTrace trace)? onError = defaultOnError,
  }) async {
    var responses = <http.StreamedResponse>[],
        stream = E621
            .sendRequests(requestGenerator())
            .asyncMap((event) => event)
            .asyncMap((event) async {
          var s = event.stream.asBroadcastStream();
          await s.length;
          return http.StreamedResponse(
            s,
            event.statusCode,
            contentLength: event.contentLength,
            request: event.request,
            headers: event.headers,
            isRedirect: event.isRedirect,
            persistentConnection: event.persistentConnection,
            reasonPhrase: event.reasonPhrase,
          );
        }).handleError(onError as Function);
    await for (final srf in stream) {
      responses.add(srf);
    }
    onComplete?.call(responses);
  }

  static Stream<Future<http.StreamedResponse>> sendRequests(
      Iterable<http.Request> requests) async* {
    for (var request in requests) {
      yield sendRequest(request);
      await Future.delayed(const Duration(seconds: idealRateLimit));
    }
  }

  /// Won't blow the rate limit
  static Future<http.StreamedResponse> sendRequest(
    http.Request request,
  ) async {
    var t = DateTime.timestamp().difference(timeOfLastRequest);
    if (t.inSeconds < softRateLimit) {
      return Future.delayed(const Duration(seconds: softRateLimit) - t, () {
        timeOfLastRequest = DateTime.timestamp();
        return client.send(request);
      });
    }
    timeOfLastRequest = DateTime.timestamp();
    return client.send(request);
  }

  static http.Request initDeleteFavoriteRequest(
    int postId, {
    String? username,
    String? apiKey,
  }) =>
      e621.Api.initDeleteFavoriteRequest(
        postId: postId,
        credentials: getAuth(username, apiKey),
      );
  static Future<http.Response> sendDeleteFavoriteRequest(
    int postId, {
    String? username,
    String? apiKey,
  }) {
    return sendRequest(initDeleteFavoriteRequest(postId,
            username: username, apiKey: apiKey))
        .toResponse()
        .onError(defaultOnError)
        .then((v) {
      favDeleted.invoke();
      return v;
    });
  }

  static Future<void> sendDeleteFavoriteRequestBatch(
    Iterable<int> postIdGenerator, {
    String? username,
    String? apiKey,
    FutureOr<void> Function(List<http.StreamedResponse> responses)? onComplete,
    void Function(Object? error, StackTrace trace)? onError = defaultOnError,
  }) {
    return sendRequestBatch(
        () => postIdGenerator.map((e) =>
            initDeleteFavoriteRequest(e, username: username, apiKey: apiKey)),
        onComplete: (responses) => onComplete?.call(responses.map((v) {
              v.stream
                  .asBroadcastStream()
                  .last
                  .then((v1) => favDeleted.invoke());
              return v;
            }).toList()));
  }

  static bool maxedOutFaves = false;
  static Future<http.StreamedResponse> sendAddFavoriteRequest(
    int postId, {
    String? username,
    String? apiKey,
  }) {
    return sendRequest(
            initAddFavoriteRequest(postId, username: username, apiKey: apiKey))
        .then((v) {
      http.ByteStream(v.stream.asBroadcastStream()).bytesToString().then((v1) {
        try {
          favAdded.invoke(PostActionArgs(
            post: E6PostResponse.fromJson(jsonDecode(v1)),
            responseBody: v1,
            statusCode: v.statusCodeInfo,
          ));
        } catch (e) {
          favFailed.invoke(PostActionArgs.withoutPost(
            postId: int.parse(v.request!.url.queryParameters["post_id"]!),
            responseBody: v1,
            statusCode: v.statusCodeInfo,
          ));
        }
      });
      return v;
    });
  }

  static http.Request initAddFavoriteRequest(
    int postId, {
    String? username,
    String? apiKey,
  }) =>
      e621.Api.initCreateFavoriteRequest(
        postId: postId,
        credentials: getAuth(username, apiKey),
      );

  /// Invokes [favAdded] on success and [favFailed] on failure for each post.
  static Future<void> sendAddFavoriteRequestBatch(
    Iterable<int> postIds, {
    String? username,
    String? apiKey,
    FutureOr<void> Function(List<http.StreamedResponse> responses)? onComplete,
    void Function(Object? error, StackTrace trace)? onError = defaultOnError,
  }) {
    return sendRequestBatch(
        () => postIds.map((e) =>
            initAddFavoriteRequest(e, username: username, apiKey: apiKey)),
        onComplete: (responses) => onComplete?.call(responses.map((v) {
              http.ByteStream(v.stream.asBroadcastStream())
                  .bytesToString()
                  .then((v1) {
                try {
                  favAdded.invoke(PostActionArgs(
                    post: E6PostResponse.fromJson(jsonDecode(v1)),
                    responseBody: v1,
                    statusCode: v.statusCodeInfo,
                  ));
                } catch (e) {
                  favFailed.invoke(PostActionArgs.withoutPost(
                    postId:
                        int.parse(v.request!.url.queryParameters["post_id"]!),
                    responseBody: v1,
                    statusCode: v.statusCodeInfo,
                  ));
                }
              });
              return v;
            }).toList()));
  }

  static http.Request initSearchRequest({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) =>
      e621.Api.initSearchPostsRequest(
        credentials: getAuth(username, apiKey),
        tags: fillTagTemplate(tags),
        limit: limit ?? SearchView.i.postsPerPage,
        page: encodePageParameterFromOptions(
          pageModifier: pageModifier,
          id: postId,
          pageNumber: pageNumber,
        ),
      );
  static Future<SearchResultArgs> performPostSearchWithPage({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? page,
    String? username,
    String? apiKey,
  }) {
    final p = parsePageParameterDirectly(page);
    String? pageModifier;
    int? pageNumber, postId;
    if (p is int) {
      pageNumber = p;
    } else {
      (:pageModifier, id: postId) = p as PageOffset;
    }
    return performPostSearch(
      tags: tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      username: username,
      apiKey: apiKey,
    );
  }

  static Future<http.Response> logAndSendRequest(http.Request r) {
    logRequest(r, logger);
    return e621.Api.sendRequest(r);
  }

  // #region User API
  static e621.UserDetailed? resolveGetUserFuture(http.Response v,
      [bool updateIfLoggedIn = true]) {
    if (v.statusCodeInfo.isError) {
      logResponse(v, logger, lm.LogLevel.SEVERE);
      return null;
    } else if (!v.statusCodeInfo.isSuccessful) {
      logResponse(v, logger, lm.LogLevel.WARNING);
      return null;
    } else {
      logResponse(v, logger, lm.LogLevel.FINER);
      try {
        final t = e621.UserLoggedInDetail.fromRawJson(v.body);
        if (updateIfLoggedIn) tryUpdateLoggedInUser(t);
        return t;
      } catch (e) {
        return e621.UserDetailed.fromRawJson(v.body);
      }
    }
  }

  static Future<e621.UserDetailed?> getUserDetailedFromId(int id,
      [e621.E6Credentials? c]) {
    var d = c ?? E621AccessData.fallback?.cred;
    if (d == null) {
      logger.finest("No access data");
    }
    var r = e621.Api.initGetUserRequest(
      id,
      credentials: d,
    );
    logRequest(r, logger, lm.LogLevel.FINEST);
    return e621.Api.sendRequest(r).then(resolveGetUserFuture);
  }

  static Future<http.Response> sendGetUserRequest(
    int userId, {
    e621.BaseCredentials? credentials,
    bool logRequest = kDebugMode,
  }) =>
      (logRequest
          ? logAndSendRequest(
              e621.Api.initGetUserRequest(userId, credentials: credentials))
          : e621.Api.sendRequest(
              e621.Api.initGetUserRequest(userId, credentials: credentials)))
        ..then((v) {
          final t = resolveGetUserFuture(v);
          if (t is e621.UserLoggedInDetail) loggedInUser.$ = t;
        });
  // #endregion User API

  static Future<SearchResultArgs> performPostSearch({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) async {
    limit ??= SearchView.i.postsPerPage;
    print(tags);
    var a1 = SearchArgs(
        // tags: [tags], //tags.split(RegExpExt.whitespace),
        tags: tags.split(RegExp(RegExpExt.whitespacePattern)),
        limit: limit,
        pageModifier: pageModifier,
        postId: postId,
        pageNumber: pageNumber,
        username: username,
        apiKey: apiKey);
    nonUserSearchBegan.invoke(a1);
    var t = await sendRequest(initSearchRequest(
      tags: tags,
      limit: limit,
      pageModifier: pageModifier,
      postId: postId,
      pageNumber: pageNumber,
      username: username,
      apiKey: apiKey,
    ));
    var t1 = await t.stream.bytesToString();
    E6Posts? t2;
    try {
      t2 = E6PostsSync.fromJson(jsonDecode(t1));
    } catch (e) {
      print("performPostSearch: $e");
    }
    var a2 = SearchResultArgs.fromSearchArgs(
      responseBody: t1,
      statusCode: t.statusCodeInfo,
      args: a1,
      results: t2,
      response: t,
    );
    nonUserSearchEnded.invoke(a2);
    return a2;
  }

  static Future<SearchResultArgs> performUserPostSearch({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? pageModifier,
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) async {
    limit ??= SearchView.i.postsPerPage;
    print(tags);
    var a1 = SearchArgs(
        // tags: [tags], //tags.split(RegExpExt.whitespace),
        tags: tags.split(RegExp(RegExpExt.whitespacePattern)),
        limit: limit,
        pageModifier: pageModifier,
        postId: postId,
        pageNumber: pageNumber,
        username: username,
        apiKey: apiKey);
    searchBegan.invoke(a1);
    var t = await sendRequest(initSearchRequest(
      tags: tags,
      limit: limit,
      pageModifier: pageModifier,
      postId: postId,
      pageNumber: pageNumber,
      username: username,
      apiKey: apiKey,
    ));
    var t1 = await t.stream.bytesToString();
    E6Posts? t2;
    try {
      t2 = E6PostsSync.fromJson(jsonDecode(t1));
    } catch (e) {
      print("performPostSearch: $e");
    }
    var a2 = SearchResultArgs.fromSearchArgs(
      responseBody: t1,
      statusCode: t.statusCodeInfo,
      args: a1,
      results: t2,
      response: t,
    );
    searchEnded.invoke(a2);
    return a2;
  }

  /// Should take at most 12 iterations to find, forcibly ends after 16;
  /// profiled with https://dartpad.dev/?id=ec269e2c4c7ccd4019bd07d3470e0d97
  static Future<int> findLastPageNumber({
    String tags = "",
    int? limit,
    String? username,
    String? apiKey,
    bool checkOnNonFullPages = false,
  }) async =>
      await findTotalPostNumber(
        tags: tags,
        username: username,
        apiKey: apiKey,
        checkOnNonFullPages: checkOnNonFullPages,
      ).then((v) => (v / (limit ?? SearchView.i.postsPerPage)).ceil());

  /// Should take at most 12 iterations to find, forcibly ends after 16;
  /// profiled with https://dartpad.dev/?id=ec269e2c4c7ccd4019bd07d3470e0d97
  static Future<int> findTotalPostNumber({
    String tags = "",
    String? username,
    String? apiKey,
    bool checkOnNonFullPages = false,
  }) async {
    const sLimit = e621.Api.maxPostsPerSearch;
    tags = fillTagTemplate(tags);
    final cred = getAuth(username, apiKey);
    f({
      int limit = sLimit,
      required int pageNumber,
    }) =>
        e621.Api.initSearchPostsRequest(
          credentials: cred,
          tags: tags,
          limit: limit,
          page: pageNumber.toString(),
        );
    Iterable<E6PostResponse> results =
        parsePostsResults((await e621.Api.sendRequest(f(
      limit: sLimit,
      pageNumber: 1,
    ))));
    if (results.lastOrNull == null) return -1;
    final lastId = (await sendSearchForLastPostRequest(
      tags: tags,
      apiKey: apiKey,
      username: username,
    ))
        .id;
    int finalPage = 1;
    num delta = e621.Api.maxPageNumber * 2;
    // Should take at most 12 iterations, I'll add the leeway of 3 iterations
    for (int currentPageNumber = 0, safety = 1;
        // for (int currentPageNumber = 0, delta = e621.Api.maxPageNumber * 2;
        // (results.lastOrNull?.id ?? -1) != lastId && delta > 0;
        (results.lastOrNull?.id ?? -1) != lastId &&
            (!checkOnNonFullPages &&
                results.isNotEmpty &&
                results.length == sLimit) &&
            safety < 15;
        safety++,
        // delta ~/= 2,
        currentPageNumber =
            currentPageNumber + (results.isEmpty ? -delta : delta).toInt(),
        // currentPageNumber += results.isEmpty ? -delta : delta,
        finalPage = currentPageNumber,
        results = parsePostsResults(await e621.Api.sendRequest(f(
      pageNumber: currentPageNumber,
    ))) /* .toList() */) {
      if (results.isNotEmpty && currentPageNumber == e621.Api.maxPageNumber) {
        break;
      }
      // if (currentPageNumber != 0 &&
      //     results.length != sLimit &&
      //     results.isNotEmpty) {
      if (results.length != sLimit && results.isNotEmpty) {
        // This should only happen when it's at the end.
        if (checkOnNonFullPages) {
          safety++;
          final temp = parsePostsResults(await e621.Api.sendRequest(f(
            pageNumber: currentPageNumber + 1,
          )));
          if ((temp.lastOrNull?.id ?? -1) == lastId) {
            results = temp;
            finalPage = currentPageNumber++;
            logger.warning(
                "Should have completed prior; page ${currentPageNumber - 1} wasn't full, but page $currentPageNumber's last id ${results.lastOrNull?.id ?? -1} equals $lastId. Either the posts were edited over the course of the run, or the supposition was wrong.");
            break;
          } else if (temp.isEmpty) {
            break;
          } else {
            logger.warning("findLastPageNumber: this is weird, investigate"
                "\ntags:$tags,"
                "\nusername:$username,"
                "\napiKey:$apiKey,"
                "\ncheckOnNonFullPages:$checkOnNonFullPages,"
                "\npage ${currentPageNumber + 1} results: [${temp.firstOrNull?.toJson().toString()}, [${temp.length - 2} other posts]..., ${temp.lastOrNull?.toJson().toString()}],"
                "\npage $currentPageNumber : [${results.firstOrNull?.toJson().toString()}, [${results.length - 2} other posts]..., ${results.lastOrNull?.toJson().toString()}],");
            delta /= 2;
          }
        } else {
          break;
        }
      } else {
        delta /= 2;
      }
    }
    // int currentPageNumber = 0, delta = e621.Api.maxPageNumber * 2;
    // do {
    //   if (results.length != sLimit && results.isNotEmpty) {

    //   }
    //   if (results.isNotEmpty && currentPageNumber == e621.Api.maxPageNumber) {
    //     break;
    //   }
    //   // if (results.length != sLimit) {
    //   //   currentPageNumber += 1;
    //   //   // continue;
    //   // } else {
    //   delta ~/= 2;
    //   currentPageNumber += results.isEmpty ? -delta : delta;
    //   // }
    //   results = parsePostsResults(await e621.Api.sendRequest(f(
    //     pageNumber: currentPageNumber,
    //   ))) /* .toList() */;
    // } while ((results.lastOrNull?.id ?? -1) != lastId && delta > 0);
    return (((finalPage - 1) * sLimit) + results.length);
  }

  /// For some reason, throws (at least on web) if not separated.
  ///
  /// TODO: Handle errors
  static Iterable<E6PostResponse> parsePostsResults(http.Response r) {
    final f = (jsonDecode(r.body)["posts"] as List)
        .map((e) => E6PostResponse.fromJson(e));
    return f;
  }

  static http.Request initSearchForLastPageRequest({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? username,
    String? apiKey,
  }) =>
      initSearchRequest(
        tags: tags,
        limit: limit,
        apiKey: apiKey,
        username: username,
        postId: 0,
        pageModifier: 'a',
      );
  static Future<http.Response> sendSearchForLastPageRequest({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? username,
    String? apiKey,
  }) =>
      e621.Api.sendRequest(initSearchForLastPageRequest(
        tags: tags,
        limit: limit,
        apiKey: apiKey,
        username: username,
      ));

  static Future<Iterable<E6PostResponse>> getLastPageFull({
    String tags = "",
    // int limit = 50,
    int? limit,
    String? username,
    String? apiKey,
  }) async {
    return parsePostsResults(
        (await e621.Api.sendRequest(initSearchForLastPageRequest(
      tags: tags,
      limit: limit,
      apiKey: apiKey,
      username: username,
    ))));
  }

  static http.Request initSearchForLastPostRequest({
    String tags = "",
    String? username,
    String? apiKey,
  }) =>
      initSearchRequest(
        tags: tags,
        limit: 1,
        apiKey: apiKey,
        username: username,
        postId: 0,
        pageModifier: 'a',
      );
  static Future<E6PostResponse> sendSearchForLastPostRequest({
    String tags = "",
    String? username,
    String? apiKey,
  }) async {
    return E6PostResponse.fromJson(
        (jsonDecode((await e621.Api.sendRequest(initSearchForLastPostRequest(
      tags: tags,
      apiKey: apiKey,
      username: username,
    )))
                .body)["posts"] as List)
            .lastOrNull);
  }

  static Future<E6PostResponse> sendSearchForFirstPostRequest({
    String tags = "",
    String? username,
    String? apiKey,
  }) async {
    return E6PostResponse.fromJson(
        (jsonDecode((await e621.Api.sendRequest(initSearchForFirstPostRequest(
      tags: tags,
      apiKey: apiKey,
      username: username,
    )))
                .body)["posts"] as Iterable)
            .firstOrNull);
  }

  static http.Request initSearchForFirstPostRequest({
    String tags = "",
    String? username,
    String? apiKey,
  }) =>
      initSearchRequest(
        tags: tags,
        limit: 1,
        apiKey: apiKey,
        username: username,
        pageNumber: 1,
      );

  static e621.E6Credentials? getAuth(
    String? username,
    String? apiKey,
  ) =>
      (username?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false)
          ? e621.Api.activeCredentials = e621.E6Credentials(
              username: username!,
              apiKey: apiKey!,
            )
          : E621AccessData.fallback?.cred;
  static Future<void> addPostToSetHeavyLifter(
      BuildContext context, PostListing postListing,
      [e621.E6Credentials? cred]) async {
    print("Adding ${postListing.id} to a set");
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text("To Be Implemented")),
    // );
    var v = await showDialog<e621.PostSet>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: WSearchSet(
            initialLimit: 10,
            initialPage: null,
            initialSearchCreatorName: "***REMOVED***,
            initialSearchOrder: e621.SetOrder.updatedAt,
            initialSearchName: null,
            initialSearchShortname: null,
            onSelected: (e621.PostSet set) => Navigator.pop(context, set),
            showCreateSetButton: true,
          ),
          // scrollable: true,
        );
      },
    );
    if (v != null) {
      print("Adding ${postListing.id} to set ${v.id}");
      var res = await E621
          .sendRequest(e621.Api.initAddToSetRequest(
            v.id,
            [postListing.id],
            credentials: cred ?? E621AccessData.fallback?.cred,
          ))
          .toResponse();
      if (res.statusCode == 201) {
        print("${postListing.id} successfully added to set ${v.id}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text("${postListing.id} successfully added to set ${v.id}"),
              action: SnackBarAction(
                label: "See Set",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(),
                      body: WPostSearchResults.directResultFromSearch(
                        'set:${v.shortname}',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
      return;
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Set Selected, canceling.")),
      );
      return;
    } else {
      return;
    }
  }
}

class SearchArgs extends JEventArgs {
  final List<String> tags;
  final Set<String> _tagSet;
  SearchArgs({
    required List<String> tags,
    required this.limit,
    required this.pageModifier,
    required this.postId,
    required this.pageNumber,
    required this.username,
    required this.apiKey,
  })  : _tagSet = Set.unmodifiable(tags.toSet()),
        tags = List.unmodifiable(tags);
  Set<String> get tagSet => _tagSet;
  final int limit;
  final String? pageModifier;
  final int? postId;
  final int? pageNumber;
  String? get page =>
      pageNumber?.toString() ??
      (pageModifier != null && postId != null
          ? "$pageModifier$pageNumber"
          : null);
  final String? username;
  final String? apiKey;
}

class SearchResultArgs extends SearchArgs {
  SearchResultArgs({
    this.results,
    required this.responseBody,
    required this.statusCode,
    required super.tags,
    required super.limit,
    required super.pageModifier,
    required super.postId,
    required super.pageNumber,
    required super.username,
    required super.apiKey,
    this.response,
  });
  SearchResultArgs.fromSearchArgs({
    this.results,
    this.response,
    required this.responseBody,
    required this.statusCode,
    required SearchArgs args,
  }) : super(
          tags: args.tags,
          limit: args.limit,
          pageModifier: args.pageModifier,
          postId: args.postId,
          pageNumber: args.pageNumber,
          username: args.username,
          apiKey: args.apiKey,
        );
  final E6Posts? results;
  final String responseBody;
  final StatusCode statusCode;
  final http.BaseResponse? response;
}

class PostActionArgs extends JEventArgs {
  PostActionArgs({
    required E6PostResponse this.post,
    required this.responseBody,
    required this.statusCode,
  }) : postId = post.id;
  PostActionArgs.withoutPost({
    required this.postId,
    required this.responseBody,
    required this.statusCode,
  }) : post = null;
  final E6PostResponse? post;
  final int postId;
  final String responseBody;
  final StatusCode statusCode;
}

enum PostRating with EnumQueryParameter<PostRating> {
  safe,
  questionable,
  explicit;

  // @override
  // PostRating get queryValue => this;
  @override
  String get queryName => "rating";
  @override
  String get query => queryShort;
  @override
  String get queryValueString => queryValueStringShort;
  String get queryValueStringShort => name[0];
  String get queryShort => "$queryName:$queryValueStringShort";
  String get queryValueStringLong => name;
  String get queryLong => "$queryName:$queryValueStringLong";

  static PostRating getFromJsonResponse(String letter) => switch (letter) {
        's' => PostRating.safe,
        'q' => PostRating.questionable,
        'e' => PostRating.explicit,
        _ => throw UnsupportedError("type not supported"),
      };
}

enum PostActions {
  addFav,
  deleteFav,
  upvote,
  downvote,
  addToSet,
  addToPool,
  removeFromSet,
  removeFromPool,
  edit,
  editNotes,
  ;
}

Future<({String username, String apiKey})?> launchLogInDialog(
        BuildContext context,
        [BuildContext Function()? getMountedContext,
        Duration snackbarDuration = const Duration(seconds: 6)]) =>
    showDialog<({String username, String apiKey})>(
      context: context,
      builder: (context) {
        String username = "", apiKey = "";
        return AlertDialog(
          title: const Text("Login"),
          content: Column(
            children: [
              TextField(
                onChanged: (value) => username = value,
                decoration: const InputDecoration(
                  label: Text("Username"),
                  hintText: "Username",
                ),
              ),
              TextField(
                onChanged: (value) => apiKey = value,
                decoration: InputDecoration(
                  // label: Text("API Key"),
                  label: Linkify(
                    text: "API Key (https://e621.net/users/home )",
                    linkStyle: const TextStyle(color: Colors.yellow),
                    style: DefaultTextStyle.of(context).style,
                    onOpen: (link) async =>
                        (await launchUrl(Uri.parse(link.url)))
                            ? print('ALLEGEDLY Could not launch ${link.url}')
                            : "",
                  ),
                  hintText: "API Key",
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              // onPressed: () => Navigator.pop(context, t),
              onPressed: () =>
                  Navigator.pop(context, (username: username, apiKey: apiKey)),
              child: const Text("Accept"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    ).then((v) {
      if (v != null) {
        E621AccessData.withDefaultAssured(
                apiKey: v.apiKey, username: v.username)
            .then((v2) {
          E621AccessData.userData.$ = v2;
          E621AccessData.tryWrite().then<void>(
            (success) => success
                ? ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Successfully stored! Test it!"),
                      duration: snackbarDuration,
                      action: getMountedContext?.call().mounted ?? false
                          ? SnackBarAction(
                              label: "See File Contents",
                              onPressed: () => showSavedE621AccessDataFile(
                                  getMountedContext!()),
                            )
                          : null,
                    ),
                  )
                : "",
          );
        });
      }
      return v;
    });
FutureOr<void> showSavedE621AccessDataFile(BuildContext context) =>
    context.mounted
        ? showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(
                E621AccessData.tryLoadAsStringSync(E621AccessData.userData.$) ??
                    "",
              ),
            ),
          )
        : null;
