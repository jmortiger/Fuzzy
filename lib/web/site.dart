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
  static const myData = E621AccessData(
      apiKey: "ff340bde96571625c17160818ec0acdf",
      username: "***REMOVED***,
      userAgent: "fuzzy/0.1.0 by ***REMOVED***@gmail.com");
  final String apiKey;
  final String username;
  final String userAgent;

  const E621AccessData({
    required this.apiKey,
    required this.username,
    required this.userAgent,
  }) /*  : userAgent =
            userAgent ?? "fuzzy/${version.itemSafe} by ***REMOVED***@gmail.com" */
  ;
  factory E621AccessData.withDefault({
    required String apiKey,
    required String username,
    String? userAgent,
  }) =>
      E621AccessData(
          apiKey: apiKey,
          username: username,
          userAgent:
              userAgent ?? "fuzzy/${version.itemSafe} by ***REMOVED***@gmail.com");
  JsonOut toJson() => {
        "api_key": apiKey,
        "username": username,
        "user_agent": userAgent,
      };
  factory E621AccessData.fromJson(JsonOut json) => E621AccessData(
        apiKey: json["apiKey"] as String,
        username: json["username"] as String,
        userAgent: json["userAgent"] as String,
      );
}

sealed class E621 extends Site {
  static const String rootUrl = "https://e621.net/";
  static final Uri rootUri = Uri.parse(rootUrl);
  static final Late<E621AccessData> accessData = Late();
  static final ApiEndpoint posts_listing = ApiEndpoint(
      method: HttpMethod.GET,
      uri: Uri.parse("$rootUrl/posts.json"),
      queryParameters: {
        "limit": RequestParameter(
          required: false,
        ),
        "tags": RequestParameter(
          required: false,
        ),
        "page": RequestParameter(
          required: false,
        ),
      },
      headers: {
        "Authorization": RequestParameter(
          required: false,
        )
      });
  E621();
  // static final String filePath = ;
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

enum E621ApiEndpoints {
  dbExportTags, //"/posts.json","GET"
  searchPosts, //"/posts.json","GET"
  uploadNewPost, //"/uploads.json","POST"
  updatePost, //"/posts/<Post_ID>.json","PATCH"
  searchFlags, //"/post_flags.json","GET"
  createNewFlag, //"/post_flags.json","POST"
  voteOnPost, //"/posts/<Post_ID>/votes.json","POST"
  favoritePost, //"/favorites.json","POST"
  deleteFavorite, //"/favorites/<Post_ID>.json","DELETE"
  searchNotes, //"/notes.json","GET"
  createNewNote, //"/notes.json","POST"
  updateAnExistingNote, //"/notes/<Note_ID>.json","PUT"
  deleteNote, //"/notes/<Note_ID>.json","DELETE"
  revertNote, //"/notes/<Note_ID>/revert.json","PUT"
  searchPools, //"/pools.json","GET"
  createNewPool, //"/pools.json","POST"
  updatePool, //"/pools/<Pool_ID>.json","PUT"
  revertPool, //"/pools/<Pool_ID>/revert.json","PUT"
  ;

  static String _getDbExportDate(DateTime dt) =>
      "${dt.year}-${dt.month < 10 ? "0${dt.month}" : dt.month}-${dt.day < 10 ? "0${dt.day}" : dt.day}";
  (String, HttpMethod) getData() => switch (this) {
        dbExportTags => (
            "/db_export/tags-${_getDbExportDate(DateTime.now())}.csv.gz",
            HttpMethod.get
          ),
        searchPosts => ("/posts.json", HttpMethod.get),
        uploadNewPost => ("/uploads.json", HttpMethod.post),
        updatePost => ("/posts/<Post_ID>.json", HttpMethod.patch),
        searchFlags => ("/post_flags.json", HttpMethod.get),
        createNewFlag => ("/post_flags.json", HttpMethod.post),
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
        _ => throw UnsupportedError("type not supported"),
      };
  static String _UAG(
      Map<String, /* String */ dynamic>? variableToProposedValue) {
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

  static final Map<String, RequestParameter> userAgent = {
    "User-Agent": const RequestParameter(
      required: true,
      validValueGenerators: [
        RequestValue(
          baseString: "Basic `getBasicAuthHeaderValue(*USERNAME*, *API_KEY*)`",
          typedGenerator: _UAG,
        ),
      ],
    )
  };
  static String _BAH(
      Map<String, /* String */ dynamic>? variableToProposedValue) {
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

  static const _basicAuthGenRV = RequestValue(
      baseString: "Basic `getBasicAuthHeaderValue(*USERNAME*, *API_KEY*)`",
      typedGenerator: _BAH);
  static const Map<String, RequestParameter> authHeaderRequired = {
    "Authorization": RequestParameter(
      required: true,
      validValueGenerators: [_basicAuthGenRV],
    )
  };
  static const Map<String, RequestParameter> authHeaderOptional = {
    "Authorization": RequestParameter(
      required: false,
      validValueGenerators: [_basicAuthGenRV],
    )
  };
  // TODO: Implement a verifier for search format
  static String _tagVerifier(Map<String, dynamic>? variableToProposedValue) =>
      variableToProposedValue?["SEARCH_STRING"] ??
      (throw ArgumentError.value(
        variableToProposedValue?["SEARCH_STRING"],
        "variableToProposedValue?[\"SEARCH_STRING\"]",
        "Should be something, even an empty string.",
      ));
  static const _tagSafetyModifier = RequestValue(
    baseString: "*SEARCH_STRING* rating:safe",
    typedGenerator: _tagVerifier,
  );
  ApiEndpoint getMoreData() => switch (this) {
        dbExportTags => ApiEndpoint(
            uri: Uri.parse(
                "${E621.rootUrl}db_export/tags-${_getDbExportDate(DateTime.now())}.csv.gz"),
            method: HttpMethod.get.nameUpper,
            headers: userAgent
              ..addAll(authHeaderOptional)
              ..putIfAbsent(
                  "Access-Control-Allow-Origin",
                  () => const RequestParameter(
                      required: true, validValues: ["*"])),
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
            },
            headers: userAgent..addAll(authHeaderOptional),
          ),
        uploadNewPost => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}uploads.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
            headers: authHeaderRequired,
          ),
        updatePost => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}posts/<Post_ID>.json"),
            method: HttpMethod.patch.nameUpper,
            queryParameters: null,
          ),
        searchFlags => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}post_flags.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: null,
          ),
        createNewFlag => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}post_flags.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
          ),
        voteOnPost => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}posts/<Post_ID>/votes.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
          ),
        favoritePost => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}favorites.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
          ),
        deleteFavorite => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}favorites/<Post_ID>.json"),
            method: HttpMethod.delete.nameUpper,
            queryParameters: null,
          ),
        searchNotes => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: null,
          ),
        createNewNote => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
          ),
        updateAnExistingNote => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>.json"),
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
          ),
        deleteNote => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>.json"),
            method: HttpMethod.delete.nameUpper,
            queryParameters: null,
          ),
        revertNote => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}notes/<Note_ID>/revert.json"),
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
          ),
        searchPools => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}pools.json"),
            method: HttpMethod.get.nameUpper,
            queryParameters: null,
          ),
        createNewPool => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}pools.json"),
            method: HttpMethod.post.nameUpper,
            queryParameters: null,
          ),
        updatePool => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}pools/<Pool_ID>.json"),
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
          ),
        revertPool => ApiEndpoint(
            uri: Uri.parse("${E621.rootUrl}pools/<Pool_ID>/revert.json"),
            method: HttpMethod.put.nameUpper,
            queryParameters: null,
          ),
        _ => throw UnsupportedError("type not supported"),
      };

  // Search posts,*_*"/posts.json","GET"
  // Upload a new post,*_*"/uploads.json","POST"
  // Update a post,*_*"/posts/<Post_ID>.json","PATCH"
  // Search flags,*_*"/post_flags.json","GET"
  // Create a new flag,*_*"/post_flags.json","POST"
  // Vote on a post,*_*"/posts/<Post_ID>/votes.json","POST"
  // Favorite a post,*_*"/favorites.json","POST"
  // Delete a favorite,*_*"/favorites/<Post_ID>.json","DELETE"
  // Search notes,*_*"/notes.json","GET"
  // Create a new note,*_*"/notes.json","POST"
  // Update an existing note,*_*"/notes/<Note_ID>.json","PUT"
  // Delete a note,*_*"/notes/<Note_ID>.json","DELETE"
  // Revert a note to a previous version,*_*"/notes/<Note_ID>/revert.json","PUT"
  // Search pools,*_*"/pools.json","GET"
  // Create a new pool,*_*"/pools.json","POST"
  // Update pool,*_*"/pools/<Pool_ID>.json","PUT"
  // Revert pool to some previous version,*_*"/pools/<Pool_ID>/revert.json","PUT"
}
