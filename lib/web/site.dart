import 'dart:convert';

import 'package:flutter/services.dart' as service;
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/util/util.dart';

import 'models/e621/e6_models.dart';

abstract base class Site {
  bool get usesCredentials;
  bool get usesPersistentCredentials;
  bool get mayRequireForegroundCredentialRefresh;
  bool get requiresForegroundCredentials;
}

abstract base class PersistentSite extends Site {
  @override
  bool get usesCredentials => true;
  @override
  bool get usesPersistentCredentials => true;
  @override
  bool get mayRequireForegroundCredentialRefresh;
  @override
  bool get requiresForegroundCredentials;
}

final class E621AccessData {
  // static final devData = E621AccessData(
  //     apiKey: devApiKey, username: devUsername, userAgent: devUserAgent);
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

sealed class E621 extends Site {
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
  // static final String filePath = ;
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
      E621ApiEndpoints.deleteFavorite.getMoreData().genRequest(
        uriModifierParam: {"Post_ID": postId},
        headers: getAuthHeaders(username, apiKey),
      );

  static http.Request initAddFavoriteRequest(
    int postId, {
    String? username,
    String? apiKey,
  }) =>
      E621ApiEndpoints.favoritePost.getMoreData().genRequest(query: {
        "post_id": (0, {"POST_ID": postId}),
      }, headers: getAuthHeaders(username, apiKey));
  static http.Request initSearchRequest({
    String? tags = "jun_kobayashi",
    int limit = 50,
    String? pageModifier, //pageModifier.contains(RegExp(r'a|b'))
    int? postId,
    int? pageNumber,
    String? username,
    String? apiKey,
  }) =>
      E621ApiEndpoints.searchPosts.getMoreData().genRequest(query: {
        "limit": (0, {"LIMIT": limit}),
        "tags": (0, {"SEARCH_STRING": tags}),
        if (postId != null && (pageModifier == 'a' || pageModifier == 'b'))
          "page": (0, {"MODIFIER": pageModifier, "ID": postId}),
        if (pageNumber != null) "page": (1, {"PAGE_NUMBER": pageNumber}),
      }, headers: getAuthHeaders(username, apiKey));
  static http.Request initSearchForLastPageRequest({
    String? tags = "jun_kobayashi",
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
    String? tags = "jun_kobayashi",
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

  static RequestParameterValues? getAuthHeaders(
    String? username,
    String? apiKey,
  ) =>
      (username?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false)
          ? {
              "Authorization": (0, {"USERNAME": username, "API_KEY": apiKey}),
            }
          : accessData.isAssigned
              ? {
                  "Authorization": (
                    0,
                    {
                      "USERNAME": accessData.item.username,
                      "API_KEY": accessData.item.apiKey,
                    }
                  ),
                }
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

/// https://e621.net/wiki_pages/2425
enum E621ApiEndpoints {
  /// PARAMS: none
  dbExportTags,

  /// PARAMS:
  /// QUERY:
  /// * LIMIT
  /// * SEARCH_STRING
  /// * MODIFIER & ID or PAGE_NUMBER
  ///
  searchPosts,

  /// PARAMS:
  uploadNewPost,

  /// PARAMS:
  /// * URL: Pool_ID
  ///
  updatePost,

  /// PARAMS:
  searchFlags,

  /// PARAMS:
  createNewFlag,

  /// PARAMS:
  /// QUERY: USER_ID
  /// Response:
  /// HTTP 403 if the user has hidden their favorites.
  /// HTTP 404 if the specified user_id does not exist or user_id is not specified and the user is not authorized.
  /// 200 otherwise
  favoritesView,

  /// PARAMS:
  /// URL: Post_ID
  voteOnPost,

  /// PARAMS:
  /// URL: Post_ID
  favoritePost,

  /// PARAMS:
  /// URL: Post_ID
  /// Response: none
  deleteFavorite,

  /// PARAMS:
  searchNotes,

  /// PARAMS:
  createNewNote,

  /// PARAMS:
  updateAnExistingNote,

  /// PARAMS:
  deleteNote,

  /// PARAMS:
  revertNote,

  /// PARAMS:
  searchPools,

  /// PARAMS:
  createNewPool,

  /// PARAMS:
  updatePool,

  /// PARAMS:
  revertPool,

  /// PARAMS:
  /// search\[name_matches\]
  /// search\[category\]
  /// search\[order\]
  /// search\[hide_empty\]
  /// search\[has_wiki\]
  /// search\[has_artist\]
  searchTags,
  ;

  ApiEndpoint getMoreData() => switch (this) {
        dbExportTags => ApiEndpoint(
            uri: Uri.parse(
                "${E621.rootUrl}db_export/tags-${_getDbExportDate(DateTime.now())}.csv.gz"),
            method: HttpMethod.get.nameUpper,
            headers: E621ApiEndpoints.baseHeadersAuthOptional,
          ),
        searchPosts => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}posts.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: {
              "limit": RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*LIMIT*",
                    typedGenerator: (Map<String, dynamic>? map) {
                      var t = int.tryParse(map?["LIMIT"]?.toString() ?? "");
                      return ((t != null && (t <= 320) && t >= 1)
                              ? t
                              : (map?["CORRECT_INVALID_VALUES"] ?? false)
                                  ? ((t?.clamp(1, 320)) ?? (320 / 2)).toInt()
                                  : (throw ArgumentError.value(
                                      t,
                                      "map?[\"LIMIT\"]",
                                      "Value must be between 1 & 320 (inclusive).",
                                    )))
                          .toString();
                    },
                  ),
                ],
              ),
              "tags": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*SEARCH_STRING*",
                    typedGenerator: _tagVerifier,
                    validator: _tagValidator,
                  ),
                ],
              ),
              "page": RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*MODIFIER**ID*",
                    typedGenerator: (map) {
                      var m = map?["MODIFIER"] ??
                              (throw ArgumentError.value(
                                map?["MODIFIER"],
                                "map?[\"MODIFIER\"]",
                                "Should be either an 'a' or a 'b'.",
                              )),
                          id = int.tryParse(map?["ID"].toString() ??
                                  (throw ArgumentError.value(
                                    map?["ID"],
                                    "map?[\"ID\"]",
                                    "Should be a num referring to the post_id.",
                                  ))) ??
                              (throw ArgumentError.value(
                                map?["ID"],
                                "map?[\"ID\"]",
                                "Should be a num referring to the post_id.",
                              ));
                      if (m != 'a' && m != 'b') {
                        throw ArgumentError.value(
                          map?["MODIFIER"],
                          "map?[\"MODIFIER\"]",
                          "Should be either an 'a' or a 'b'.",
                        );
                      }
                      return "$m$id";
                    },
                  ),
                  RequestValue(
                    baseString: "*PAGE_NUMBER*",
                    typedGenerator: (map) {
                      var pg = int.tryParse(map?["PAGE_NUMBER"] ??
                              (throw ArgumentError.value(
                                map?["PAGE_NUMBER"],
                                "map?[\"PAGE_NUMBER\"]",
                                "Should be a num referring to the page number.",
                              ))) ??
                          (throw ArgumentError.value(
                            map?["PAGE_NUMBER"],
                            "map?[\"PAGE_NUMBER\"]",
                            "Should be a num referring to the page number.",
                          ));
                      return "$pg";
                    },
                  ),
                ],
              ),
            },
            headers: E621ApiEndpoints.baseHeadersAuthOptional,
          ),
        uploadNewPost => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}uploads.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        updatePost => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}posts/<Post_ID>.json"),
            uriString: "${E621.rootUrl}posts/<Post_ID>.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.patch.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        searchFlags => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}post_flags.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthOptional,
          ),
        createNewFlag => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}post_flags.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        favoritesView => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}favorites.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: E621ApiEndpoints.userIdParamOptional,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        voteOnPost => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}posts/<Post_ID>/votes.json"),
            uriString: "${E621.rootUrl}posts/<Post_ID>/votes.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        favoritePost => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}favorites.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: E621ApiEndpoints.postIdParam,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        deleteFavorite => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}favorites/<Post_ID>.json"),
            uriString: "${E621.rootUrl}favorites/<Post_ID>.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.delete.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        searchNotes => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthOptional,
          ),
        createNewNote => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        updateAnExistingNote => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>.json"),
            uriString: "${E621.rootUrl}notes/<Note_ID>.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        deleteNote => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>.json"),
            uriString: "${E621.rootUrl}notes/<Note_ID>.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.delete.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        revertNote => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>/revert.json"),
            uriString: "${E621.rootUrl}notes/<Note_ID>/revert.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        searchPools => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}pools.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthOptional,
          ),
        createNewPool => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}pools.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        updatePool => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}pools/<Pool_ID>.json"),
            uriString: "${E621.rootUrl}pools/<Pool_ID>.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        revertPool => ApiEndpoint.parameterizedUri(
            // uri: Uri.parse("${E621.rootUrl}pools/<Pool_ID>/revert.json"),
            uriString: "${E621.rootUrl}pools/<Pool_ID>/revert.json",
            uriMatcher: _angleBracketDelimited,
            uriModifier: _uriModder,
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
            headers: E621ApiEndpoints.baseHeadersAuthRequired,
          ),
        // https://e621.net/wiki_pages/2425#tags_listing
        searchTags => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}tags.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: {
              "limit": RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*LIMIT*",
                    typedGenerator: (Map<String, dynamic>? map) {
                      var t = int.tryParse(map?["LIMIT"]?.toString() ?? "");
                      return ((t != null && (t <= 320) && t >= 1)
                              ? t
                              : (map?["CORRECT_INVALID_VALUES"] ?? false)
                                  // Defaults to 75
                                  ? 75 //((t?.clamp(1, 320)) ?? (320 / 2)).toInt()
                                  : (throw ArgumentError.value(
                                      t,
                                      "map?[\"LIMIT\"]",
                                      "Value must be between 1 & 320 (inclusive).",
                                    )))
                          .toString();
                    },
                  ),
                ],
              ),
              "page": RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*MODIFIER**ID*",
                    typedGenerator: (map) {
                      var m = map?["MODIFIER"] ??
                              (throw ArgumentError.value(
                                map?["MODIFIER"],
                                "map?[\"MODIFIER\"]",
                                "Should be either an 'a' or a 'b'.",
                              )),
                          id = int.tryParse(map?["ID"] ??
                                  (throw ArgumentError.value(
                                    map?["ID"],
                                    "map?[\"ID\"]",
                                    "Should be a num referring to the post_id.",
                                  ))) ??
                              (throw ArgumentError.value(
                                map?["ID"],
                                "map?[\"ID\"]",
                                "Should be a num referring to the post_id.",
                              ));
                      if (m != 'a' && m != 'b') {
                        throw ArgumentError.value(
                          map?["MODIFIER"],
                          "map?[\"MODIFIER\"]",
                          "Should be either an 'a' or a 'b'.",
                        );
                      }
                      return "$m$id";
                    },
                  ),
                  RequestValue(
                    baseString: "*PAGE_NUMBER*",
                    typedGenerator: (map) {
                      var pg = int.tryParse(map?["PAGE_NUMBER"] ??
                              (throw ArgumentError.value(
                                map?["PAGE_NUMBER"],
                                "map?[\"PAGE_NUMBER\"]",
                                "Should be a num referring to the page number.",
                              ))) ??
                          (throw ArgumentError.value(
                            map?["PAGE_NUMBER"],
                            "map?[\"PAGE_NUMBER\"]",
                            "Should be a num referring to the page number.",
                          ));
                      return "$pg";
                    },
                  ),
                ],
              ),
              "search[name_matches]": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*SEARCH_STRING*",
                    typedGenerator: _tagVerifier,
                  ),
                ],
              ),
              "search[category]": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*TAG_CATEGORY*",
                    typedGenerator: _tagSearchCategory,
                  ),
                ],
              ),
              "search[order]": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*TAG_ORDER*",
                    typedGenerator: _tagSearchOrder,
                  ),
                ],
              ),
              "search[hide_empty]": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*TAG_HIDE_EMPTY*",
                    typedGenerator: _tagSearchHideEmpty,
                  ),
                ],
              ),
              "search[has_wiki]": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*TAG_HAS_WIKI*",
                    typedGenerator: _tagSearchHasWiki,
                  ),
                ],
              ),
              "search[has_artist]": const RequestParameter(
                required: false,
                validValueGenerators: [
                  RequestValue(
                    baseString: "*TAG_HAS_ARTIST*",
                    typedGenerator: _tagSearchHasArtist,
                  ),
                ],
              ),
            },
            headers: E621ApiEndpoints.baseHeadersAuthOptional,
          ),
        // _ => throw UnsupportedError("type not supported"),
      };
  static Uri _uriModder(
    String baseUri,
    RegExp? matcher,
    Map<String, dynamic> map,
  ) =>
      Uri.parse(matcher == null
          ? baseUri
          : baseUri.replaceAllMapped(
              matcher, (match) => map[match.group(1)].toString()));

  static final _angleBracketDelimited = RegExp(r'<(.*)>');
  @Deprecated("Use _getDbExportDate")
  static String _getDbExportDateManual(DateTime dt) =>
      "${dt.year}-${dt.month < 10 ? "0${dt.month}" : dt.month}"
      "-${dt.day < 10 ? "0${dt.day}" : dt.day}";
  static String _getDbExportDate(DateTime dt) =>
      dt.toIso8601String().substring(0, 10);
  static String _getDbExportDateSafe() => DateTime.now().hour >= 8
      ? _getDbExportDate(DateTime.now())
      : _getDbExportDate(DateTime.now().subtract(const Duration(days: -1)));
  (String, HttpMethod) getData() => switch (this) {
        dbExportTags => (
            "/db_export/tags-${_getDbExportDateSafe()}.csv.gz",
            HttpMethod.get
          ),
        searchPosts => ("/posts.json", HttpMethod.get),
        uploadNewPost => ("/uploads.json", HttpMethod.post),
        updatePost => ("/posts/<Post_ID>.json", HttpMethod.patch),
        searchFlags => ("/post_flags.json", HttpMethod.get),
        createNewFlag => ("/post_flags.json", HttpMethod.post),
        favoritesView => ("/favorites.json", HttpMethod.get),
        voteOnPost => ("/posts/<Post_ID>/votes.json", HttpMethod.post),
        favoritePost => ("/favorites.json", HttpMethod.post),
        deleteFavorite => ("/favorites/<Post_ID>.json", HttpMethod.delete),
        searchNotes => ("/notes.json", HttpMethod.get),
        createNewNote => ("/notes.json", HttpMethod.post),
        updateAnExistingNote => ("/notes/<Note_ID>.json", HttpMethod.put),
        deleteNote => ("/notes/<Note_ID>.json", HttpMethod.delete),
        revertNote => ("/notes/<Note_ID>/revert.json", HttpMethod.put),
        searchPools => ("/pools.json", HttpMethod.get),
        createNewPool => ("/pools.json", HttpMethod.post),
        updatePool => ("/pools/<Pool_ID>.json", HttpMethod.put),
        revertPool => ("/pools/<Pool_ID>/revert.json", HttpMethod.put),
        searchTags => ("/tags.json", HttpMethod.get),
        // _ => throw UnsupportedError("type not supported"),
      };
  static const Map<String, RequestParameter> userAgentParameterMap = {
    "User-Agent": RequestParameter(
      required: true,
      validValueGenerators: [
        RequestValue(
          baseString: "fuzzy/*VERSION* by atotaltirefire@gmail.com",
          // typedGenerator: _userAgentGenerator,
          validator: _userAgentValidator,
        ),
      ],
      // validValues: [E621AccessData.myUserAgent],
    )
  };
  static const _basicAuthGenRV = RequestValue(
      baseString: "Basic `getBasicAuthHeaderValue(*USERNAME*, *API_KEY*)`",
      typedGenerator: _basicAuthGenerator);
  static const Map<String, RequestParameter> accessControlAllowOriginAll = {
    "Access-Control-Allow-Origin": RequestParameter(
      required: true,
      validValues: ["*"],
    ),
  };
  static const Map<String, RequestParameter> authHeaderRequiredParamMap = {
    "Authorization": RequestParameter(
      required: true,
      validValueGenerators: [_basicAuthGenRV],
    )
  };
  static const Map<String, RequestParameter> authHeaderOptionalParamMap = {
    "Authorization": RequestParameter(
      required: false,
      validValueGenerators: [_basicAuthGenRV],
    )
  };
  static const Map<String, RequestParameter> baseHeadersAuthRequired = {
    ...userAgentParameterMap,
    ...authHeaderRequiredParamMap,
    //...accessControlAllowOriginAll,
  };
  static const Map<String, RequestParameter> baseHeadersAuthOptional = {
    ...userAgentParameterMap,
    ...authHeaderOptionalParamMap,
    //...accessControlAllowOriginAll,
  };
  static const Map<String, RequestParameter> postIdParam = {
    "post_id": RequestParameter(
      required: true,
      validValueGenerators: [
        RequestValue(
          baseString: "*POST_ID*",
          validator: _postIdValidator,
        ),
      ],
    )
  };
  static const Map<String, RequestParameter> userIdParamOptional = {
    "user_id": RequestParameter(
      required: false,
      validValueGenerators: [
        RequestValue(
          baseString: "*USER_ID*",
          validator: _postIdValidator,
        ),
      ],
    )
  };
  static const Map<String, RequestParameter> userIdParamRequired = {
    "user_id": RequestParameter(
      required: true,
      validValueGenerators: [
        RequestValue(
          baseString: "*USER_ID*",
          validator: _postIdValidator,
        ),
      ],
    )
  };
  static String _postIdValidator(String replacedParam, dynamic proposedValue) =>
      (int.tryParse(proposedValue.toString()) == null &&
              proposedValue.runtimeType != int)
          ? (throw ArgumentError.value(
              proposedValue,
              'proposedValue',
              "The value must be an integer or string.",
            ))
          : proposedValue!.toString();
  static String _userAgentGenerator(
          Map<String, dynamic>? variableToProposedValue) =>
      variableToProposedValue?["VERSION"]?.toString() ??
      version.itemSafe ??
      "VERSION";
  /* (throw ArgumentError.value(
              variableToProposedValue,
              "variableToProposedValue",
              "Need realtime values for *VERSION*: ",
            )); */
  static String _userAgentValidator(
          String replacedParam, dynamic proposedValue) =>
      _userAgentGenerator({replacedParam: proposedValue});
  static String _basicAuthGenerator(
      Map<String, dynamic>? variableToProposedValue) {
    var u = variableToProposedValue?["USERNAME"]?.toString() ??
            (throw ArgumentError.value(
              variableToProposedValue,
              "variableToProposedValue",
              "Need realtime values for *USERNAME* and *API_KEY*: ",
            )),
        k = variableToProposedValue?["API_KEY"]?.toString() ??
            (throw ArgumentError.value(
              variableToProposedValue,
              "variableToProposedValue",
              "Need realtime values for *API_KEY*: ",
            ));
    return getBasicAuthHeaderValue(u, k);
  }

  // TODO: Implement a verifier for search format
  static String _tagVerifier(Map<String, dynamic>? variableToProposedValue) =>
      (variableToProposedValue?["SEARCH_STRING"]?.toString().isEmpty ?? true)
          ? (throw ArgumentError.value(
              variableToProposedValue?["SEARCH_STRING"],
              'variableToProposedValue?["SEARCH_STRING"]',
              "The value must not be null nor empty.",
            ))
          : variableToProposedValue!["SEARCH_STRING"]!.toString();
  // variableToProposedValue?["SEARCH_STRING"] ??
  // (throw ArgumentError.value(
  //   variableToProposedValue?["SEARCH_STRING"],
  //   "variableToProposedValue?[\"SEARCH_STRING\"]",
  //   "Should be something, even an empty string.",
  // ));
  static String _tagValidator(replacedParam, proposedValue) =>
      (proposedValue?.toString().isEmpty ?? true)
          ? (throw ArgumentError.value(
              proposedValue,
              "proposedValue",
              "The value must not be null nor empty.",
            ))
          : proposedValue.toString();
  static const _tagSearchSafeValue = RequestValue(
    baseString: "*SEARCH_STRING* rating:safe",
    typedGenerator: _tagVerifier,
    validator: _tagValidator,
  );
  static const _tagSearchValue = RequestValue(
    baseString: "*SEARCH_STRING*",
    typedGenerator: _tagVerifier,
    validator: _tagValidator,
  );
  static String _boolOrDefaultBlankSwitch(ParamValueMap? map, String key) =>
      switch (map?[key]) {
        == "true" || == true => "true",
        == "false" || == false => "false",
        bool val => val.toString(),
        _ => "",
      };

  /// Defaults to "" (blank)
  static String _tagSearchHasArtist(ParamValueMap? variableToProposedValue) =>
      E621ApiEndpoints._boolOrDefaultBlankSwitch(
        variableToProposedValue,
        "TAG_HAS_ARTIST",
      );

  /// Defaults to "" (blank)
  static String _tagSearchHasWiki(ParamValueMap? variableToProposedValue) =>
      E621ApiEndpoints._boolOrDefaultBlankSwitch(
        variableToProposedValue,
        "TAG_HAS_WIKI",
      );
  static String _tagSearchCategory(ParamValueMap? variableToProposedValue) =>
      switch (variableToProposedValue?["TAG_CATEGORY"]) {
        == TagCategory.general || == 0 => "0",
        == TagCategory.artist || == 1 => "1",
        == TagCategory.copyright || == 3 => "3",
        == TagCategory.character || == 4 => "4",
        == TagCategory.species || == 5 => "5",
        == TagCategory.invalid || == 6 => "6",
        == TagCategory.meta || == 7 => "7",
        == TagCategory.lore || == 8 => "8",
        _ => "",
      };

  /// Their's defaults to date, mine defaults to count
  static String _tagSearchOrder(ParamValueMap? variableToProposedValue) =>
      switch (variableToProposedValue?["TAG_ORDER"]) {
        == "date" => "date",
        == "name" => "name",
        == "count" => "count",
        _ => "count",
      };

  /// Defaults to true
  static String _tagSearchHideEmpty(ParamValueMap? variableToProposedValue) =>
      switch (variableToProposedValue?["TAG_HIDE_EMPTY"]) {
        == "false" || == false => "false",
        _ => "true",
      };
}
