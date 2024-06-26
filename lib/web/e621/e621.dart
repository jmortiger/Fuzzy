import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' as service;
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/site.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/e621.dart' as e621;

final class E621AccessData {
  static final devData = LazyInitializer<E621AccessData>(() async =>
      E621AccessData.fromJson((jsonDecode(
              await (service.rootBundle.loadString("assets/devData.json")
                ..onError(defaultOnError /* onErrorPrintAndRethrow */)))
          as JsonOut)["e621"] as JsonOut));
  static String? get devApiKey => devData.itemSafe?.apiKey;
  static String? get devUsername => devData.itemSafe?.username;
  static String? get devUserAgent => devData.itemSafe?.userAgent;
  // static get devData => _devData;
  static final userData = LateFinal<E621AccessData>();
  final String apiKey;
  final String username;
  final String userAgent;
  e621.E6Credentials get cred =>
      e621.E6Credentials(username: username, apiKey: apiKey);

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
  E621();

  static String fillTagTemplate(String tags) {
    print("fillTagTemplate: SaveData = ${SavedDataE6.$Safe?.all.map((e) => (e as dynamic).toJson())}");
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
    return tags;
  }
  // static final String filePath = ;
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
      // E621ApiEndpoints.deleteFavorite.getMoreData().genRequest(
      //   uriModifierParam: {"Post_ID": postId},
      //   headers: getAuthHeaders(username, apiKey),
      // );
      e621.Api.initDeleteFavoriteRequest(
        postId: postId,
        credentials: E621AccessData.devData.$.cred,
      );
  static Future<http.StreamedResponse> sendDeleteFavoriteRequest(
    int postId, {
    String? username,
    String? apiKey,
  }) {
    return sendRequest(initDeleteFavoriteRequest(postId,
            username: username, apiKey: apiKey))
        .then((v) {
      v.stream.asBroadcastStream().last.then((v1) => favDeleted.invoke());
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
      // E621ApiEndpoints.favoritePost.getMoreData().genRequest(query: {
      //   "post_id": (0, {"POST_ID": postId}),
      // }, headers: getAuthHeaders(username, apiKey));
      e621.Api.initCreateFavoriteRequest(
        postId: postId,
        credentials: getAuth(username, apiKey),
      );

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
    String tags = "", //"jun_kobayashi",
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
  /* E621ApiEndpoints.searchPosts.getMoreData().genRequest(query: {
        "limit": (0, {"LIMIT": limit}),
        "tags": (0, {"SEARCH_STRING": tags}),
        if (postId != null && (pageModifier == 'a' || pageModifier == 'b'))
          "page": (0, {"MODIFIER": pageModifier, "ID": postId}),
        if (pageNumber != null) "page": (1, {"PAGE_NUMBER": pageNumber}),
      }, headers: getAuthHeaders(username, apiKey)); */
  static Future<SearchResultArgs> performPostSearch({
    String tags = "",
    int limit = 50,
    String? pageModifier, //pageModifier.contains(RegExp(r'a|b'))
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) async {
    var a1 = SearchArgs(
        tags: tags.split(RegExpExt.whitespace),
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

  // static RequestParameterValues? getAuthHeaders(
  //   String? username,
  //   String? apiKey,
  // ) =>
  //     (username?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false)
  //         ? {
  //             "Authorization": (0, {"USERNAME": username, "API_KEY": apiKey}),
  //           }
  //         : accessData.isAssigned
  //             ? {
  //                 "Authorization": (
  //                   0,
  //                   {
  //                     "USERNAME": accessData.item.username,
  //                     "API_KEY": accessData.item.apiKey,
  //                   }
  //                 ),
  //               }
  //             : null;
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
  // static Future<({int firstIdLastPage, int lastId, int pages})>
  //     findPagesOfResults({
  //   required String tags,
  //   required int limit,
  //   // String? pageModifier,//pageModifier.contains(RegExp(r'a|b'))
  //   // int? postId,
  //   // int? pageNumber,
  //   String? username,
  //   String? apiKey,
  // }) async {
  //   var response = await initSearchRequest(
  //           tags: tags, limit: limit + 1, username: username, apiKey: apiKey)
  //       .send();
  //   var results = jsonDecode(await response.stream.bytesToString());
  //   if (results["posts"].isEmpty) {
  //     return (pages: 0, lastId: 0, firstIdLastPage: 0);
  //   } else if (results["posts"].length <
  //       int.parse(response.request?.url.queryParameters["limit"] ?? "0")) {
  //     var first = (results["posts"][0].id as int);
  //     var last = (results["posts"].last.id as int);
  //     return (pages: 1, lastId: last, firstIdLastPage: first);
  //   } else {
  //     // UNFINISHED
  //     return (pages: -1, lastId: 0, firstIdLastPage: 0);
  //   }
  // }
  // static http.Request initSearchRequest({
  //   String? tags = "jun_kobayashi",
  //   int limit = 50,
  //   String? page,
  //   String? username,
  //   String? apiKey,
  // }) =>
  //     E621ApiEndpoints.searchPosts.getMoreData().genRequest(query: {
  //       "limit": (0, {"LIMIT": limit}),
  //       "tags": (0, {"SEARCH_STRING": tags}),
  //       if (page != null) "page": (page.contains(RegExp(r'a|b')) ? 0 : 1, page.contains(RegExp(r'a|b')) ? {"MODIFIER": page[0], "ID" : page.substring(1)}:{"PAGE_NUMBER":page}),
  //     }, headers: getAuthHeaders(username, apiKey));
}

enum PostRating {
  safe,
  questionable,
  explicit;

  static PostRating getFromJsonResponse(String letter) => switch (letter) {
        's' => PostRating.safe,
        'q' => PostRating.questionable,
        'e' => PostRating.explicit,
        _ => throw UnsupportedError("type not supported"),
      };
}

/// TODO: Kill the overhead of the ApiEndpoint thing
/// https://e621.net/wiki_pages/2425
// enum E621ApiEndpoints {
//   /// PARAMS: none
//   dbExportTags,

//   /// PARAMS:
//   /// QUERY:
//   /// * LIMIT
//   /// * SEARCH_STRING
//   /// * MODIFIER & ID or PAGE_NUMBER
//   ///
//   searchPosts,

//   /// PARAMS:
//   uploadNewPost,

//   /// PARAMS:
//   /// * URL: Pool_ID
//   ///
//   updatePost,

//   /// PARAMS:
//   searchFlags,

//   /// PARAMS:
//   createNewFlag,

//   /// PARAMS:
//   /// QUERY: USER_ID
//   /// Response:
//   /// HTTP 403 if the user has hidden their favorites.
//   /// HTTP 404 if the specified user_id does not exist or user_id is not specified and the user is not authorized.
//   /// 200 otherwise
//   favoritesView,

//   /// PARAMS:
//   /// URL: Post_ID
//   voteOnPost,

//   /// PARAMS:
//   /// URL: Post_ID
//   favoritePost,

//   /// PARAMS:
//   /// URL: Post_ID
//   /// Response: none
//   deleteFavorite,

//   /// PARAMS:
//   searchNotes,

//   /// PARAMS:
//   createNewNote,

//   /// PARAMS:
//   updateAnExistingNote,

//   /// PARAMS:
//   deleteNote,

//   /// PARAMS:
//   revertNote,

//   /// PARAMS:
//   searchPools,

//   /// PARAMS:
//   createNewPool,

//   /// PARAMS:
//   updatePool,

//   /// PARAMS:
//   revertPool,

//   /// PARAMS:
//   /// search\[name_matches\]
//   /// search\[category\]
//   /// search\[order\]
//   /// search\[hide_empty\]
//   /// search\[has_wiki\]
//   /// search\[has_artist\]
//   searchTags,
//   ;

//   ApiEndpoint getMoreData() => switch (this) {
//         dbExportTags => ApiEndpoint(
//             uri: Uri.parse(
//                 "${E621.rootUrl}db_export/tags-${_getDbExportDate(DateTime.now())}.csv.gz"),
//             method: HttpMethod.get.nameUpper,
//             headers: E621ApiEndpoints.baseHeadersAuthOptional,
//           ),
//         searchPosts => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}posts.json"),
//             method: HttpMethod.get.nameUpper,
//             queryParameters: {
//               "limit": RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*LIMIT*",
//                     typedGenerator: (Map<String, dynamic>? map) {
//                       var t = int.tryParse(map?["LIMIT"]?.toString() ?? "");
//                       return ((t != null && (t <= 320) && t >= 1)
//                               ? t
//                               : (map?["CORRECT_INVALID_VALUES"] ?? false)
//                                   ? ((t?.clamp(1, 320)) ?? (320 / 2)).toInt()
//                                   : (throw ArgumentError.value(
//                                       t,
//                                       "map?[\"LIMIT\"]",
//                                       "Value must be between 1 & 320 (inclusive).",
//                                     )))
//                           .toString();
//                     },
//                   ),
//                 ],
//               ),
//               "tags": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*SEARCH_STRING*",
//                     typedGenerator: _tagVerifier,
//                     validator: _tagValidator,
//                   ),
//                 ],
//               ),
//               "page": RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*MODIFIER**ID*",
//                     typedGenerator: (map) {
//                       var m = map?["MODIFIER"] ??
//                               (throw ArgumentError.value(
//                                 map?["MODIFIER"],
//                                 "map?[\"MODIFIER\"]",
//                                 "Should be either an 'a' or a 'b'.",
//                               )),
//                           id = int.tryParse(map?["ID"].toString() ??
//                                   (throw ArgumentError.value(
//                                     map?["ID"],
//                                     "map?[\"ID\"]",
//                                     "Should be a num referring to the post_id.",
//                                   ))) ??
//                               (throw ArgumentError.value(
//                                 map?["ID"],
//                                 "map?[\"ID\"]",
//                                 "Should be a num referring to the post_id.",
//                               ));
//                       if (m != 'a' && m != 'b') {
//                         throw ArgumentError.value(
//                           map?["MODIFIER"],
//                           "map?[\"MODIFIER\"]",
//                           "Should be either an 'a' or a 'b'.",
//                         );
//                       }
//                       return "$m$id";
//                     },
//                   ),
//                   RequestValue(
//                     baseString: "*PAGE_NUMBER*",
//                     typedGenerator: (map) {
//                       var pg = int.tryParse(map?["PAGE_NUMBER"] ??
//                               (throw ArgumentError.value(
//                                 map?["PAGE_NUMBER"],
//                                 "map?[\"PAGE_NUMBER\"]",
//                                 "Should be a num referring to the page number.",
//                               ))) ??
//                           (throw ArgumentError.value(
//                             map?["PAGE_NUMBER"],
//                             "map?[\"PAGE_NUMBER\"]",
//                             "Should be a num referring to the page number.",
//                           ));
//                       return "$pg";
//                     },
//                   ),
//                 ],
//               ),
//             },
//             headers: E621ApiEndpoints.baseHeadersAuthOptional,
//           ),
//         uploadNewPost => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}uploads.json"),
//             method: HttpMethod.post.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         updatePost => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}posts/<Post_ID>.json"),
//             uriString: "${E621.rootUrl}posts/<Post_ID>.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.patch.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         searchFlags => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}post_flags.json"),
//             method: HttpMethod.get.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthOptional,
//           ),
//         createNewFlag => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}post_flags.json"),
//             method: HttpMethod.post.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         favoritesView => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}favorites.json"),
//             method: HttpMethod.get.nameUpper,
//             queryParameters: E621ApiEndpoints.userIdParamOptional,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         voteOnPost => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}posts/<Post_ID>/votes.json"),
//             uriString: "${E621.rootUrl}posts/<Post_ID>/votes.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.post.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         favoritePost => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}favorites.json"),
//             method: HttpMethod.post.nameUpper,
//             queryParameters: E621ApiEndpoints.postIdParam,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         deleteFavorite => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}favorites/<Post_ID>.json"),
//             uriString: "${E621.rootUrl}favorites/<Post_ID>.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.delete.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         searchNotes => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}notes.json"),
//             method: HttpMethod.get.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthOptional,
//           ),
//         createNewNote => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}notes.json"),
//             method: HttpMethod.post.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         updateAnExistingNote => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>.json"),
//             uriString: "${E621.rootUrl}notes/<Note_ID>.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.put.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         deleteNote => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>.json"),
//             uriString: "${E621.rootUrl}notes/<Note_ID>.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.delete.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         revertNote => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>/revert.json"),
//             uriString: "${E621.rootUrl}notes/<Note_ID>/revert.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.put.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         searchPools => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}pools.json"),
//             method: HttpMethod.get.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthOptional,
//           ),
//         createNewPool => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}pools.json"),
//             method: HttpMethod.post.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         updatePool => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}pools/<Pool_ID>.json"),
//             uriString: "${E621.rootUrl}pools/<Pool_ID>.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.put.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         revertPool => ApiEndpoint.parameterizedUri(
//             // uri: Uri.parse("${E621.rootUrl}pools/<Pool_ID>/revert.json"),
//             uriString: "${E621.rootUrl}pools/<Pool_ID>/revert.json",
//             uriMatcher: _angleBracketDelimited,
//             uriModifier: _uriModder,
//             method: HttpMethod.put.nameUpper,
//             queryParameters: null,
//             headers: E621ApiEndpoints.baseHeadersAuthRequired,
//           ),
//         // https://e621.net/wiki_pages/2425#tags_listing
//         searchTags => ApiEndpoint(
//             uri: Uri.parse("${E621.rootUrl}tags.json"),
//             method: HttpMethod.get.nameUpper,
//             queryParameters: {
//               "limit": RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*LIMIT*",
//                     typedGenerator: (Map<String, dynamic>? map) {
//                       var t = int.tryParse(map?["LIMIT"]?.toString() ?? "");
//                       return ((t != null && (t <= 320) && t >= 1)
//                               ? t
//                               : (map?["CORRECT_INVALID_VALUES"] ?? false)
//                                   // Defaults to 75
//                                   ? 75 //((t?.clamp(1, 320)) ?? (320 / 2)).toInt()
//                                   : (throw ArgumentError.value(
//                                       t,
//                                       "map?[\"LIMIT\"]",
//                                       "Value must be between 1 & 320 (inclusive).",
//                                     )))
//                           .toString();
//                     },
//                   ),
//                 ],
//               ),
//               "page": RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*MODIFIER**ID*",
//                     typedGenerator: (map) {
//                       var m = map?["MODIFIER"] ??
//                               (throw ArgumentError.value(
//                                 map?["MODIFIER"],
//                                 "map?[\"MODIFIER\"]",
//                                 "Should be either an 'a' or a 'b'.",
//                               )),
//                           id = int.tryParse(map?["ID"] ??
//                                   (throw ArgumentError.value(
//                                     map?["ID"],
//                                     "map?[\"ID\"]",
//                                     "Should be a num referring to the post_id.",
//                                   ))) ??
//                               (throw ArgumentError.value(
//                                 map?["ID"],
//                                 "map?[\"ID\"]",
//                                 "Should be a num referring to the post_id.",
//                               ));
//                       if (m != 'a' && m != 'b') {
//                         throw ArgumentError.value(
//                           map?["MODIFIER"],
//                           "map?[\"MODIFIER\"]",
//                           "Should be either an 'a' or a 'b'.",
//                         );
//                       }
//                       return "$m$id";
//                     },
//                   ),
//                   RequestValue(
//                     baseString: "*PAGE_NUMBER*",
//                     typedGenerator: (map) {
//                       var pg = int.tryParse(map?["PAGE_NUMBER"] ??
//                               (throw ArgumentError.value(
//                                 map?["PAGE_NUMBER"],
//                                 "map?[\"PAGE_NUMBER\"]",
//                                 "Should be a num referring to the page number.",
//                               ))) ??
//                           (throw ArgumentError.value(
//                             map?["PAGE_NUMBER"],
//                             "map?[\"PAGE_NUMBER\"]",
//                             "Should be a num referring to the page number.",
//                           ));
//                       return "$pg";
//                     },
//                   ),
//                 ],
//               ),
//               "search[name_matches]": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*SEARCH_STRING*",
//                     typedGenerator: _tagVerifier,
//                   ),
//                 ],
//               ),
//               "search[category]": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*TAG_CATEGORY*",
//                     typedGenerator: _tagSearchCategory,
//                   ),
//                 ],
//               ),
//               "search[order]": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*TAG_ORDER*",
//                     typedGenerator: _tagSearchOrder,
//                   ),
//                 ],
//               ),
//               "search[hide_empty]": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*TAG_HIDE_EMPTY*",
//                     typedGenerator: _tagSearchHideEmpty,
//                   ),
//                 ],
//               ),
//               "search[has_wiki]": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*TAG_HAS_WIKI*",
//                     typedGenerator: _tagSearchHasWiki,
//                   ),
//                 ],
//               ),
//               "search[has_artist]": const RequestParameter(
//                 required: false,
//                 validValueGenerators: [
//                   RequestValue(
//                     baseString: "*TAG_HAS_ARTIST*",
//                     typedGenerator: _tagSearchHasArtist,
//                   ),
//                 ],
//               ),
//             },
//             headers: E621ApiEndpoints.baseHeadersAuthOptional,
//           ),
//         // _ => throw UnsupportedError("type not supported"),
//       };
//   static Uri _uriModder(
//     String baseUri,
//     RegExp? matcher,
//     Map<String, dynamic> map,
//   ) =>
//       Uri.parse(matcher == null
//           ? baseUri
//           : baseUri.replaceAllMapped(
//               matcher, (match) => map[match.group(1)].toString()));

//   static final _angleBracketDelimited = RegExp(r'<(.*)>');
//   @Deprecated("Use _getDbExportDate")
//   static String _getDbExportDateManual(DateTime dt) =>
//       "${dt.year}-${dt.month < 10 ? "0${dt.month}" : dt.month}"
//       "-${dt.day < 10 ? "0${dt.day}" : dt.day}";
//   static String _getDbExportDate(DateTime dt) =>
//       dt.toIso8601String().substring(0, 10);
//   static String _getDbExportDateSafe() => DateTime.now().hour >= 8
//       ? _getDbExportDate(DateTime.now())
//       : _getDbExportDate(DateTime.now().subtract(const Duration(days: -1)));
//   (String, HttpMethod) getData() => switch (this) {
//         dbExportTags => (
//             "/db_export/tags-${_getDbExportDateSafe()}.csv.gz",
//             HttpMethod.get
//           ),
//         searchPosts => ("/posts.json", HttpMethod.get),
//         uploadNewPost => ("/uploads.json", HttpMethod.post),
//         updatePost => ("/posts/<Post_ID>.json", HttpMethod.patch),
//         searchFlags => ("/post_flags.json", HttpMethod.get),
//         createNewFlag => ("/post_flags.json", HttpMethod.post),
//         favoritesView => ("/favorites.json", HttpMethod.get),
//         voteOnPost => ("/posts/<Post_ID>/votes.json", HttpMethod.post),
//         favoritePost => ("/favorites.json", HttpMethod.post),
//         deleteFavorite => ("/favorites/<Post_ID>.json", HttpMethod.delete),
//         searchNotes => ("/notes.json", HttpMethod.get),
//         createNewNote => ("/notes.json", HttpMethod.post),
//         updateAnExistingNote => ("/notes/<Note_ID>.json", HttpMethod.put),
//         deleteNote => ("/notes/<Note_ID>.json", HttpMethod.delete),
//         revertNote => ("/notes/<Note_ID>/revert.json", HttpMethod.put),
//         searchPools => ("/pools.json", HttpMethod.get),
//         createNewPool => ("/pools.json", HttpMethod.post),
//         updatePool => ("/pools/<Pool_ID>.json", HttpMethod.put),
//         revertPool => ("/pools/<Pool_ID>/revert.json", HttpMethod.put),
//         searchTags => ("/tags.json", HttpMethod.get),
//         // _ => throw UnsupportedError("type not supported"),
//       };
//   static const Map<String, RequestParameter> userAgentParameterMap = {
//     "User-Agent": RequestParameter(
//       required: true,
//       validValueGenerators: [
//         RequestValue(
//           baseString: "fuzzy/*VERSION* by atotaltirefire@gmail.com",
//           // typedGenerator: _userAgentGenerator,
//           validator: _userAgentValidator,
//         ),
//       ],
//       // validValues: [E621AccessData.myUserAgent],
//     )
//   };
//   static const _basicAuthGenRV = RequestValue(
//       baseString: "Basic `getBasicAuthHeaderValue(*USERNAME*, *API_KEY*)`",
//       typedGenerator: _basicAuthGenerator);
//   static const Map<String, RequestParameter> accessControlAllowOriginAll = {
//     "Access-Control-Allow-Origin": RequestParameter(
//       required: true,
//       validValues: ["*"],
//     ),
//   };
//   static const Map<String, RequestParameter> authHeaderRequiredParamMap = {
//     "Authorization": RequestParameter(
//       required: true,
//       validValueGenerators: [_basicAuthGenRV],
//     )
//   };
//   static const Map<String, RequestParameter> authHeaderOptionalParamMap = {
//     "Authorization": RequestParameter(
//       required: false,
//       validValueGenerators: [_basicAuthGenRV],
//     )
//   };
//   static const Map<String, RequestParameter> baseHeadersAuthRequired = {
//     ...userAgentParameterMap,
//     ...authHeaderRequiredParamMap,
//     //...accessControlAllowOriginAll,
//   };
//   static const Map<String, RequestParameter> baseHeadersAuthOptional = {
//     ...userAgentParameterMap,
//     ...authHeaderOptionalParamMap,
//     //...accessControlAllowOriginAll,
//   };
//   static const Map<String, RequestParameter> postIdParam = {
//     "post_id": RequestParameter(
//       required: true,
//       validValueGenerators: [
//         RequestValue(
//           baseString: "*POST_ID*",
//           validator: _postIdValidator,
//         ),
//       ],
//     )
//   };
//   static const Map<String, RequestParameter> userIdParamOptional = {
//     "user_id": RequestParameter(
//       required: false,
//       validValueGenerators: [
//         RequestValue(
//           baseString: "*USER_ID*",
//           validator: _postIdValidator,
//         ),
//       ],
//     )
//   };
//   static const Map<String, RequestParameter> userIdParamRequired = {
//     "user_id": RequestParameter(
//       required: true,
//       validValueGenerators: [
//         RequestValue(
//           baseString: "*USER_ID*",
//           validator: _postIdValidator,
//         ),
//       ],
//     )
//   };
//   static String _postIdValidator(String replacedParam, dynamic proposedValue) =>
//       (int.tryParse(proposedValue.toString()) == null &&
//               proposedValue.runtimeType != int)
//           ? (throw ArgumentError.value(
//               proposedValue,
//               'proposedValue',
//               "The value must be an integer or string.",
//             ))
//           : proposedValue!.toString();
//   static String _userAgentGenerator(
//           Map<String, dynamic>? variableToProposedValue) =>
//       variableToProposedValue?["VERSION"]?.toString() ??
//       version.itemSafe ??
//       "VERSION";
//   /* (throw ArgumentError.value(
//               variableToProposedValue,
//               "variableToProposedValue",
//               "Need realtime values for *VERSION*: ",
//             )); */
//   static String _userAgentValidator(
//           String replacedParam, dynamic proposedValue) =>
//       _userAgentGenerator({replacedParam: proposedValue});
//   static String _basicAuthGenerator(
//       Map<String, dynamic>? variableToProposedValue) {
//     var u = variableToProposedValue?["USERNAME"]?.toString() ??
//             (throw ArgumentError.value(
//               variableToProposedValue,
//               "variableToProposedValue",
//               "Need realtime values for *USERNAME* and *API_KEY*: ",
//             )),
//         k = variableToProposedValue?["API_KEY"]?.toString() ??
//             (throw ArgumentError.value(
//               variableToProposedValue,
//               "variableToProposedValue",
//               "Need realtime values for *API_KEY*: ",
//             ));
//     return getBasicAuthHeaderValue(u, k);
//   }

//   // TODO: Implement a verifier for search format
//   static String _tagVerifier(Map<String, dynamic>? variableToProposedValue) =>
//       (variableToProposedValue?["SEARCH_STRING"]?.toString().isEmpty ?? true)
//           ? (throw ArgumentError.value(
//               variableToProposedValue?["SEARCH_STRING"],
//               'variableToProposedValue?["SEARCH_STRING"]',
//               "The value must not be null nor empty.",
//             ))
//           : variableToProposedValue!["SEARCH_STRING"]!.toString();
//   // variableToProposedValue?["SEARCH_STRING"] ??
//   // (throw ArgumentError.value(
//   //   variableToProposedValue?["SEARCH_STRING"],
//   //   "variableToProposedValue?[\"SEARCH_STRING\"]",
//   //   "Should be something, even an empty string.",
//   // ));
//   static String _tagValidator(replacedParam, proposedValue) =>
//       (proposedValue?.toString().isEmpty ?? true)
//           ? (throw ArgumentError.value(
//               proposedValue,
//               "proposedValue",
//               "The value must not be null nor empty.",
//             ))
//           : proposedValue.toString();
//   static const _tagSearchSafeValue = RequestValue(
//     baseString: "*SEARCH_STRING* rating:safe",
//     typedGenerator: _tagVerifier,
//     validator: _tagValidator,
//   );
//   static const _tagSearchValue = RequestValue(
//     baseString: "*SEARCH_STRING*",
//     typedGenerator: _tagVerifier,
//     validator: _tagValidator,
//   );
//   static String _boolOrDefaultBlankSwitch(ParamValueMap? map, String key) =>
//       switch (map?[key]) {
//         == "true" || == true => "true",
//         == "false" || == false => "false",
//         bool val => val.toString(),
//         _ => "",
//       };

//   /// Defaults to "" (blank)
//   static String _tagSearchHasArtist(ParamValueMap? variableToProposedValue) =>
//       E621ApiEndpoints._boolOrDefaultBlankSwitch(
//         variableToProposedValue,
//         "TAG_HAS_ARTIST",
//       );

//   /// Defaults to "" (blank)
//   static String _tagSearchHasWiki(ParamValueMap? variableToProposedValue) =>
//       E621ApiEndpoints._boolOrDefaultBlankSwitch(
//         variableToProposedValue,
//         "TAG_HAS_WIKI",
//       );
//   static String _tagSearchCategory(ParamValueMap? variableToProposedValue) =>
//       switch (variableToProposedValue?["TAG_CATEGORY"]) {
//         == TagCategory.general || == 0 => "0",
//         == TagCategory.artist || == 1 => "1",
//         == TagCategory.copyright || == 3 => "3",
//         == TagCategory.character || == 4 => "4",
//         == TagCategory.species || == 5 => "5",
//         == TagCategory.invalid || == 6 => "6",
//         == TagCategory.meta || == 7 => "7",
//         == TagCategory.lore || == 8 => "8",
//         _ => "",
//       };

//   /// Their's defaults to date, mine defaults to count
//   static String _tagSearchOrder(ParamValueMap? variableToProposedValue) =>
//       switch (variableToProposedValue?["TAG_ORDER"]) {
//         == "date" => "date",
//         == "name" => "name",
//         == "count" => "count",
//         _ => "count",
//       };

//   /// Defaults to true
//   static String _tagSearchHideEmpty(ParamValueMap? variableToProposedValue) =>
//       switch (variableToProposedValue?["TAG_HIDE_EMPTY"]) {
//         == "false" || == false => "false",
//         _ => "true",
//       };
// }
