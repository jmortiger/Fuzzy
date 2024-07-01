import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/e621.dart' as e621;

import 'package:fuzzy/log_management.dart' as lm;

final print = lm.genPrint("main");

final class E621AccessData {
  static final devAccessData = LazyInitializer<E621AccessData>(() async =>
      E621AccessData.fromJson((await devData.getItem())["e621"] as JsonOut));
  static String? get devApiKey => devAccessData.itemSafe?.apiKey;
  static String? get devUsername => devAccessData.itemSafe?.username;
  static String? get devUserAgent => devAccessData.itemSafe?.userAgent;
  static final userData = LateFinal<E621AccessData>();
  final String apiKey;
  final String username;
  final String userAgent;
  e621.E6Credentials get cred =>
      e621.E6Credentials(username: username, apiKey: apiKey);
  // e621.E6Credentials get cred => (e621.Api.activeCredentials ??=
  //         e621.E6Credentials(username: username, apiKey: apiKey))
  //     as e621.E6Credentials;

  const E621AccessData({
    required this.apiKey,
    required this.username,
    required this.userAgent,
  });
  factory E621AccessData.withDefault({
    required String apiKey,
    required String username,
    String? userAgent,
  }) =>
      E621AccessData(
          apiKey: apiKey,
          username: username,
          userAgent: userAgent ??
              "fuzzy/${version.itemSafe} by atotaltirefire@gmail.com");
  JsonOut toJson() => {
        "apiKey": apiKey,
        "username": username,
        "userAgent": userAgent,
      };
  factory E621AccessData.fromJson(JsonOut json) => E621AccessData(
        apiKey: json["apiKey"] as String,
        username: json["username"] as String,
        userAgent: json["userAgent"] as String,
      );
  // Map<String,String> generateHeaders() {

  // }
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
  });
  SearchResultArgs.fromSearchArgs({
    this.results,
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
}

class PostActionArgs extends JEventArgs {
  PostActionArgs({
    required E6PostResponse post,
    required this.responseBody,
    required this.statusCode,
  })  : postId = post.id,
        post = post;
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

sealed class E621 extends Site {
  @event
  static final favDeleted = JPureEvent();
  @event
  static final favFailed = JEvent<PostActionArgs>();
  @event
  static final favAdded = JEvent<PostActionArgs>();
  @event
  static final searchBegan = JEvent<SearchArgs>();
  @event
  static final searchEnded = JEvent<SearchResultArgs>();
  @event
  static final nonUserSearchBegan = JEvent<SearchArgs>();
  @event
  static final nonUserSearchEnded = JEvent<SearchResultArgs>();
  static const String rootUrl = "https://e621.net/";
  static final Uri rootUri = Uri.parse(rootUrl);
  static final accessData = LateFinal<E621AccessData>();
  static const int hardRateLimit = 1;
  static const int softRateLimit = 2;
  static const int idealRateLimit = 3;
  static final http.Client client = http.Client();
  static const maxPostsPerSearch = 320;
  static DateTime timeOfLastRequest =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// The (escaped) character used to delimit saved search insertion.
  static const savedSearchInsertionDelimiter = r"#";
  static const savedSearchInsertionEnd =
      r'(?=' + RegExpExt.whitespacePattern + r'+?|$)';

  /// The (escaped) character used to delimit saved search insertion.
  static const delimiter = savedSearchInsertionDelimiter;

  /// Used to inject a saved search entry into a search using the entry's unique ID.
  ///
  /// Lazily expands
  /// #(.+?)(?=[\u2028\n\r\u000B\f\u2029\u0085 ]+?|$)
  // static final savedSearchInsertion = RegExp("$delimiter(.+?)$delimiter");
  // static final savedSearchInsertion = RegExp("$delimiter(.+?)${RegExpExt.whitespace.pattern}");
  static final savedSearchInsertion =
      RegExp("$delimiter(.+?)$savedSearchInsertionEnd");

  /// Used to inject a saved search entry into a search using the entry's unique ID.
  ///
  /// Matches all characters other than [delimiter]
  // static final savedSearchInsertionAlt = RegExp("$delimiter([^$delimiter]+)$delimiter");
  static final savedSearchInsertionAlt =
      RegExp("$delimiter([^$delimiter]+?)$savedSearchInsertionEnd");
  E621();

  static String fillTagTemplate(String tags) {
    print("fillTagTemplate: Before: $tags");
    tags = tags.replaceAllMapped(
      savedSearchInsertion,
      (match) {
        try {
          return SavedDataE6.$Safe?.all
                  .singleWhere((element) => element.uniqueId == match.group(1))
                  .searchString ??
              "";
        } catch (e) {
          return "";
        }
      },
    );
    print("fillTagTemplate: After: $tags");
    tags += AppSettings.i?.blacklistedTags.map((e) => "-$e").foldToString(" ") ?? "";
    print("fillTagTemplate: After Blacklist: $tags");
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

  static const initSearchSetsRequest = e621.Api.initSearchSetsRequest;
  static Future<http.BaseResponse> sendSearchSetsRequest({
    String? searchName,
    String? searchShortname,
    String? searchCreatorName,
    String? searchCreatorId,
    e621.SetOrder? searchOrder,
    int? limit = 75,
    String? page,
    e621.BaseCredentials? credentials,
  }) =>
      sendRequest(e621.Api.initSearchSetsRequest(
        searchName: searchName,
        searchShortname: searchShortname,
        searchCreatorName: searchCreatorName,
        searchOrder: searchOrder,
        limit: limit,
        page: page,
      )).toResponse() /* .then((v) async {
      var t = await http.ByteStream(v.stream.asBroadcastStream()).bytesToString();
      return http.Response(
        t,
        v.statusCode,
        headers: v.headers,
        isRedirect: v.isRedirect,
        persistentConnection: v.persistentConnection,
        reasonPhrase: v.reasonPhrase,
        request: v.request,
      );
    }) */
      ;
  static http.Request initSearchRequest({
    String tags = "",
    int limit = 50,
    String? pageModifier, //pageModifier.contains(RegExp(r'a|b'))
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) =>
      e621.Api.initSearchPostsRequest(
        credentials: getAuth(username, apiKey),
        tags: fillTagTemplate(tags),
        limit: limit,
        page: (postId != null && (pageModifier == 'a' || pageModifier == 'b'))
            ? "$pageModifier$postId"
            : pageNumber != null
                ? "$pageNumber"
                : null,
      );

  static Future<SearchResultArgs> performPostSearch({
    String tags = "",
    int limit = 50,
    String? pageModifier, //pageModifier.contains(RegExp(r'a|b'))
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) async {
    print(tags);
    var a1 = SearchArgs(
        tags: [tags], //tags.split(RegExpExt.whitespace),
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
    );
    searchEnded.invoke(a2);
    return a2;
  }

  static http.Request initSearchForLastPageRequest({
    String tags = "",
    int limit = 50,
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

  static e621.E6Credentials? getAuth(
    String? username,
    String? apiKey,
  ) =>
      (username?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false)
          ? e621.Api.activeCredentials = e621.E6Credentials(
              username: username!,
              apiKey: apiKey!,
            )
          : accessData.isAssigned
              ? accessData.$.cred
              : null;
  static addPostToSetHeavyLifter(
      BuildContext context, PostListing postListing) async {
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
            credentials: E621.accessData.$.cred,
          ))
          .toResponse() as http.Response;
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
