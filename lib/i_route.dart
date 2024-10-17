import 'package:e621/e621_models.dart' as e621;
import 'package:flutter/material.dart';
import 'package:fuzzy/main.dart' as main
    show routeLogger, tryParsePathToQuery, tryParsePathToQueryOfList;
import 'package:j_util/collections.dart' show Iterators;

typedef CollectiveRouteParameters = ({
  int? id,
  String? title,
  e621.Pool? pool,
  e621.Post? post,
  e621.PostSet? set,
  e621.WikiPage? wikiPage,
});

@Deprecated("Use RouteParameterResolver")
class RouteParameters {
  final int? id;

  /// Stuff like wiki title.
  final String? name;
  String? get title => name;
  String? get username => name;
  final e621.Artist? artist;
  final e621.ArtistUrl? artistUrl;
  final e621.Comment? comment;
  final e621.ModifiablePostSets? modifiablePostSets;
  final e621.Note? note;
  final e621.Pool? pool;
  final e621.Post? post;
  final e621.PostSet? set;
  final e621.User? user;
  final e621.WikiPage? wikiPage;
  final Map<String, dynamic> parameters;

  const RouteParameters({
    this.id,
    String? name,
    String? title,
    this.artist,
    this.artistUrl,
    this.comment,
    this.modifiablePostSets,
    this.note,
    this.pool,
    this.post,
    this.set,
    this.user,
    this.wikiPage,
    this.parameters = const {},
  }) : name = name ?? title;
  RouteParameters.fromDynamic(
    dynamic obj, {
    int? id,
    String? name,
    this.parameters = const {},
  })  : id = (() {
          int? id2;
          try {
            assert(id == null || (id2 = obj.id) == null || id == obj.id);
            return obj.id;
          } on NoSuchMethodError catch (_) {
            return id;
          } catch (e, s) {
            main.routeLogger
                .warning("The 2 provided ids conflict: $id != $id2", e, s);
            return id ?? obj.id;
          }
        })(),
        name = (() {
          try {
            return obj.name;
          } catch (_) {
            try {
              return obj.title;
            } catch (_) {
              try {
                return obj.username;
              } catch (_) {
                return name;
              }
            }
          }
        })(),
        artist = (() {
          try {
            return obj.artist;
          } catch (_) {
            return null;
          }
        })(),
        artistUrl = (() {
          try {
            return obj.artistUrl;
          } catch (_) {
            return null;
          }
        })(),
        comment = (() {
          try {
            return obj.comment;
          } catch (_) {
            return null;
          }
        })(),
        modifiablePostSets = (() {
          try {
            return obj.modifiablePostSets;
          } catch (_) {
            return null;
          }
        })(),
        note = (() {
          try {
            return obj.note;
          } catch (_) {
            return null;
          }
        })(),
        pool = (() {
          try {
            return obj.pool;
          } catch (_) {
            return null;
          }
        })(),
        post = (() {
          try {
            return obj.post;
          } catch (_) {
            return null;
          }
        })(),
        set = (() {
          try {
            return obj.set;
          } catch (_) {
            return null;
          }
        })(),
        user = (() {
          try {
            return obj.user;
          } catch (_) {
            return null;
          }
        })(),
        wikiPage = (() {
          try {
            return obj.wikiPage;
          } catch (_) {
            return null;
          }
        })();
  RouteParameters.fromRouteSettings(
    RouteSettings settings,
    List<String> routeSegments,
    bool hasStaticPath,
  )   : parameters = IRoute.legacyRouteInit(settings).parameters,
        id = (() {
          int? id, id2;
          try {
            id = IRoute.decodePath(settings, routeSegments, hasStaticPath)
                ?.firstWhere((e) => e is int, orElse: () => null) as int?;
            id2 = id2 = (settings.arguments as dynamic).id;
            assert(id == null || id2 == null || id == id2);
            return id;
          } on NoSuchMethodError catch (_) {
            return id;
          } catch (e, s) {
            main.routeLogger
                .warning("The 2 provided ids conflict: $id != $id2", e, s);
            return id ?? (settings.arguments as dynamic).id;
          }
        })(),
        name = (() {
          String? name, name2;
          try {
            name = IRoute.decodePath(settings, routeSegments, hasStaticPath)
                ?.firstWhere((e) => e is String, orElse: () => null) as String?;
            try {
              name2 = (settings.arguments as dynamic).name;
            } catch (_) {
              try {
                name2 = (settings.arguments as dynamic).title;
              } catch (_) {
                try {
                  name2 = (settings.arguments as dynamic).username;
                } catch (_) {
                  name2 = null;
                }
              }
            }
            assert(name == null || name2 == null || name == name2);
            return name;
          } on NoSuchMethodError catch (_) {
            return name;
          } catch (e, s) {
            main.routeLogger.warning(
                "The 2 provided names conflict: $name != $name2", e, s);
            return name ?? (settings.arguments as dynamic).name;
          }
        })(),
        artist = (() {
          try {
            return (settings.arguments as dynamic).artist;
          } catch (_) {
            return null;
          }
        })(),
        artistUrl = (() {
          try {
            return (settings.arguments as dynamic).artistUrl;
          } catch (_) {
            return null;
          }
        })(),
        comment = (() {
          try {
            return (settings.arguments as dynamic).comment;
          } catch (_) {
            return null;
          }
        })(),
        modifiablePostSets = (() {
          try {
            return (settings.arguments as dynamic).modifiablePostSets;
          } catch (_) {
            return null;
          }
        })(),
        note = (() {
          try {
            return (settings.arguments as dynamic).note;
          } catch (_) {
            return null;
          }
        })(),
        pool = (() {
          try {
            return (settings.arguments as dynamic).pool;
          } catch (_) {
            return null;
          }
        })(),
        post = (() {
          try {
            return (settings.arguments as dynamic).post;
          } catch (_) {
            return null;
          }
        })(),
        set = (() {
          try {
            return (settings.arguments as dynamic).set;
          } catch (_) {
            return null;
          }
        })(),
        user = (() {
          try {
            return (settings.arguments as dynamic).user;
          } catch (_) {
            return null;
          }
        })(),
        wikiPage = (() {
          try {
            return (settings.arguments as dynamic).wikiPage;
          } catch (_) {
            return null;
          }
        })();
  static int? retrieveIdFromArguments(RouteSettings settings) {
    final args = settings.arguments as dynamic;
    try {
      return args.id;
    } catch (_) {
      try {
        return args.postId;
      } catch (_) {
        return null;
      }
    }
  }

  static e621.Post? retrievePostFromArguments(RouteSettings settings) {
    try {
      return (settings.arguments as dynamic).post;
    } catch (_) {
      return null;
    }
  }
}

class RouteParameterResolver {
  final int? _id;
  int? get id => _id ?? int.tryParse(this["id"] ?? "");

  /// Stuff like wiki title.
  final String? _name;
  String? get name => _name ?? this["name"];
  String? get title => _name ?? this["title"];
  String? get username => _name ?? this["username"];
  final e621.Artist? _artist;
  e621.Artist? get artist => _artist;
  // ?? this["artist"];
  final e621.ArtistUrl? _artistUrl;
  e621.ArtistUrl? get artistUrl => _artistUrl;
  // ?? this["artistUrl"];
  final e621.Comment? _comment;
  e621.Comment? get comment => _comment;
  // ?? this["comment"];
  final e621.ModifiablePostSets? _modifiablePostSets;
  e621.ModifiablePostSets? get modifiablePostSets => _modifiablePostSets;
  // ?? this["modifiablePostSets"];
  final e621.Note? _note;
  e621.Note? get note => _note;
  // ?? this["note"];
  final e621.Pool? _pool;
  e621.Pool? get pool => _pool;
  // ?? this["pool"];
  final e621.Post? _post;
  e621.Post? get post => _post;
  // ?? this["post"];
  final e621.PostSet? _set;
  e621.PostSet? get set => _set;
  // ?? this["set"];
  final e621.User? _user;
  e621.User? get user => _user;
  // ?? this["user"];
  final e621.WikiPage? _wikiPage;
  e621.WikiPage? get wikiPage => _wikiPage;
  // ?? this["wikiPage"] ?? this["wiki_page"];
  /// Query parameters
  final Map<String, List<String>> parameters;

  String? operator [](String key) => parameters[key]?.firstOrNull;

  const RouteParameterResolver({
    int? id,
    String? name,
    e621.Artist? artist,
    e621.ArtistUrl? artistUrl,
    e621.Comment? comment,
    e621.ModifiablePostSets? modifiablePostSets,
    e621.Note? note,
    e621.Pool? pool,
    e621.Post? post,
    e621.PostSet? set,
    e621.User? user,
    e621.WikiPage? wikiPage,
    this.parameters = const {},
  })  : _id = id,
        _artist = artist,
        _artistUrl = artistUrl,
        _comment = comment,
        _modifiablePostSets = modifiablePostSets,
        _note = note,
        _pool = pool,
        _post = post,
        _set = set,
        _user = user,
        _wikiPage = wikiPage,
        _name = name;
  RouteParameterResolver.fromDynamic(
    dynamic obj, {
    int? id,
    String? name,
    this.parameters = const {},
  })  : _id = (() {
          int? id2;
          try {
            assert(id == null || (id2 = obj.id) == null || id == obj.id);
            return obj.id;
          } on NoSuchMethodError catch (_) {
            return id;
          } catch (e, s) {
            main.routeLogger
                .warning("The 2 provided ids conflict: $id != $id2", e, s);
            return id ?? obj.id;
          }
        })(),
        _name = (() {
          try {
            return obj.name;
          } catch (_) {
            try {
              return obj.title;
            } catch (_) {
              try {
                return obj.username;
              } catch (_) {
                return name;
              }
            }
          }
        })(),
        _artist = (() {
          try {
            return obj.artist;
          } catch (_) {
            return null;
          }
        })(),
        _artistUrl = (() {
          try {
            return obj.artistUrl;
          } catch (_) {
            return null;
          }
        })(),
        _comment = (() {
          try {
            return obj.comment;
          } catch (_) {
            return null;
          }
        })(),
        _modifiablePostSets = (() {
          try {
            return obj.modifiablePostSets;
          } catch (_) {
            return null;
          }
        })(),
        _note = (() {
          try {
            return obj.note;
          } catch (_) {
            return null;
          }
        })(),
        _pool = (() {
          try {
            return obj.pool;
          } catch (_) {
            return null;
          }
        })(),
        _post = (() {
          try {
            return obj.post;
          } catch (_) {
            return null;
          }
        })(),
        _set = (() {
          try {
            return obj.set;
          } catch (_) {
            return null;
          }
        })(),
        _user = (() {
          try {
            return obj.user;
          } catch (_) {
            return null;
          }
        })(),
        _wikiPage = (() {
          try {
            return obj.wikiPage;
          } catch (_) {
            return null;
          }
        })();
  RouteParameterResolver.fromRouteSettings(
    RouteSettings settings,
    List<String> routeSegments, {
    bool hasStaticPath = false,
  })  : parameters = IRoute.legacyRouteInitFull(settings).parameters,
        _id = (() {
          int? id, id2;
          try {
            final thing =
                IRoute.decodePath(settings, routeSegments, hasStaticPath);
            if (thing is List<String>) {
              id = int.tryParse(thing.firstWhere((e) => int.tryParse(e) != null,
                  orElse: () => ""));
            } else {
              id = thing?.firstWhere((e) => e is int, orElse: () => null)
                  as int?;
            }
            id2 = id2 = (settings.arguments as dynamic).id;
            assert(id == null || id2 == null || id == id2);
            return id;
          } on NoSuchMethodError catch (_) {
            return id;
          } catch (e, s) {
            main.routeLogger
                .warning("The 2 provided ids conflict: $id != $id2", e, s);
            return id ?? (settings.arguments as dynamic).id;
          }
        })(),
        _name = (() {
          String? name, name2;
          try {
            name = IRoute.decodePath(settings, routeSegments, hasStaticPath)
                ?.firstWhere((e) => e is String, orElse: () => "") as String;
            if (name == "") name = null;
            try {
              name2 = (settings.arguments as dynamic).name;
            } catch (_) {
              try {
                name2 = (settings.arguments as dynamic).title;
              } catch (_) {
                try {
                  name2 = (settings.arguments as dynamic).username;
                } catch (_) {
                  name2 = null;
                }
              }
            }
            assert(name == null || name2 == null || name == name2);
            return name;
          } on NoSuchMethodError catch (_) {
            return name;
          } catch (e, s) {
            main.routeLogger.warning(
                "The 2 provided names conflict: $name != $name2", e, s);
            return name ?? (settings.arguments as dynamic).name;
          }
        })(),
        _artist = (() {
          try {
            return (settings.arguments as dynamic).artist;
          } catch (_) {
            return null;
          }
        })(),
        _artistUrl = (() {
          try {
            return (settings.arguments as dynamic).artistUrl;
          } catch (_) {
            return null;
          }
        })(),
        _comment = (() {
          try {
            return (settings.arguments as dynamic).comment;
          } catch (_) {
            return null;
          }
        })(),
        _modifiablePostSets = (() {
          try {
            return (settings.arguments as dynamic).modifiablePostSets;
          } catch (_) {
            return null;
          }
        })(),
        _note = (() {
          try {
            return (settings.arguments as dynamic).note;
          } catch (_) {
            return null;
          }
        })(),
        _pool = (() {
          try {
            return (settings.arguments as dynamic).pool;
          } catch (_) {
            return null;
          }
        })(),
        _post = (() {
          try {
            return (settings.arguments as dynamic).post;
          } catch (_) {
            return null;
          }
        })(),
        _set = (() {
          try {
            return (settings.arguments as dynamic).set;
          } catch (_) {
            return null;
          }
        })(),
        _user = (() {
          try {
            return (settings.arguments as dynamic).user;
          } catch (_) {
            return null;
          }
        })(),
        _wikiPage = (() {
          try {
            return (settings.arguments as dynamic).wikiPage;
          } catch (_) {
            return null;
          }
        })();
  static int? retrieveIdFromArguments(RouteSettings settings) {
    final args = settings.arguments as dynamic;
    try {
      return args.id;
    } catch (_) {
      try {
        return args.postId;
      } catch (_) {
        return null;
      }
    }
  }

  static e621.Post? retrievePostFromArguments(RouteSettings settings) {
    try {
      return (settings.arguments as dynamic).post;
    } catch (_) {
      return null;
    }
  }
}

/// 132 paths w/ params, 9 accept id/name, 123 accept id, all accept only 1 param.
mixin IRoute<T extends Widget /* IRoute<T> */ > {
  static get routeLogger => main.routeLogger;

  /// These 1st path segments can be followed by either an artist's name or their corresponding id.
  static const stringParamRoutes = {
    "avoid_postings",
    "artists",
  };

  /// The 4 int first path segments that accept a successive int param or a path, and the path the can accept.
  static const intParamSegUniqueFollow = {
    "posts": "random",
    "post_sets": "for_select",
    "tags": "preview",
    "users": "upload_limit",
    "wiki_pages": "show_or_new",
  };

  /// Of these, only 4 can have a following path seg that isn't a param.
  /// * `posts` (`random`)
  /// * `post_sets` (`for_select`)
  /// * `tags` (`preview`)
  /// * `users` (`upload_limit`)
  /// * `wiki_pages` (`show_or_new`) custom exception
  static const intParamRoutes = {
    "bans",
    "blips",
    "bulk_update_requests",
    "comments",
    "dmails",
    "email_blacklists",
    "favorites",
    "forum_posts",
    "forum_topics",
    "help",
    "ip_bans",
    "mascots",
    "news_updates",
    "notes",
    "pools",
    "posts",
    // "/moderator/post/posts",
    "post_sets",
    "post_flags",
    "post_replacements",
    "tags",
    "tag_aliases",
    "tag_implications",
    "takedowns",
    "tickets",
    "upload_whitelists",
    "users",
    "user_feedbacks",
    "user_name_change_requests",
    "wiki_pages",
    "wiki_page",
    "wiki_page_versions",
    // "/admin/users",
  };

  /// Both of these are followed by int params.
  /// Of these, only `/admin/users` (`alt_list`) can have a following path seg that isn't a param.
  static const intParamRouteExceptions = {
    "/moderator/post/posts",
    "/admin/users",
  };
  static const intParamRouteExceptionsUniqueFollow = {
    "/admin/users": "alt_list"
  };
  String get routeName;
  List<String> get routeSegments;
  String get routeSegmentsFolded; // => "/${routeSegments.join("/")}";
  bool get hasStaticPath;
  // bool acceptsRoute(RouteSettings settings);
  bool acceptsRoute(RouteSettings settings) {
    parsePathParam(int i, String e) =>
        IRoute.pathParametersMethod[routeSegments[i]]?.call(e);
    final Uri? uri;
    if (settings.name == null ||
        (uri = Uri.tryParse(settings.name!)) == null ||
        uri!.pathSegments.length != routeSegments.length ||
        (hasStaticPath
            ? uri.pathSegments.anyFull((e, i, _) => e != routeSegments[i])
            : uri.pathSegments.anyFull((e, i, _) =>
                e != routeSegments[i] && parsePathParam(i, e) == null))) {
      return false;
    }
    return true;
  }

  Widget generateWidgetForRoute(RouteSettings settings);
  Widget? tryGenerateWidgetForRoute(RouteSettings settings) =>
      acceptsRoute(settings) ? generateWidgetForRoute(settings) : null;

  List? decodeMyPath(RouteSettings settings) =>
      decodePath(settings, routeSegments, hasStaticPath);

  static Param? decodePathParameter<Param>(
    RouteSettings settings,
    final List<String> routeSegmentsConst,
    final bool hasStaticPathConst,
  ) {
    parsePathParam(int i, String e) =>
        IRoute.pathParametersMethod[routeSegmentsConst[i]]?.call(e);
    final Uri? uri;
    if (settings.name == null ||
        (uri = Uri.tryParse(settings.name!)) == null ||
        uri!.pathSegments.length != routeSegmentsConst.length ||
        hasStaticPathConst &&
            uri.pathSegments.anyFull((e, i, _) => e != routeSegmentsConst[i]) ||
        !hasStaticPathConst &&
            uri.pathSegments.anyFull((e, i, _) =>
                e != routeSegmentsConst[i] && parsePathParam(i, e) == null)) {
      return null;
    }
    return uri.pathSegments.foldUntilTrue<Param?>(null, (p, e, i, _) {
      if (e == routeSegmentsConst[i]) return (p, false);
      if (p != null) {
        routeLogger
            .warning("[decodePathParameter] Shouldn't be able to have more"
                " than 1 param in path. Preserving prior param.\n\t"
                "settings.name: ${settings.name}");
        return (p, false);
      }
      final v = parsePathParam(i, e);
      return v == null ? (null, true) : (p ?? v as Param, false);
    });
  }

  static List? decodePath(
    RouteSettings settings,
    final List<String> routeSegmentsConst,
    final bool hasStaticPathConst,
  ) {
    final List<String>? path;
    if (settings.name == null ||
        ((path = Uri.tryParse(settings.name!)?.pathSegments)?.length ?? -1) !=
            routeSegmentsConst.length) {
      return null;
    }
    return hasStaticPathConst
        ? path!.anyFull((e, i, _) => e != routeSegmentsConst[i])
            ? null
            : path as List<dynamic>
        : path!.foldUntilTrue<List?>([], (p, e, i, _) {
            if (e == routeSegmentsConst[i]) return ((p ?? [])..add(e), false);
            final v =
                IRoute.pathParametersMethod[routeSegmentsConst[i]]?.call(e);
            return v == null ? (null, true) : ((p ?? [])..add(v), false);
          });
  }

  static String? encodePath(RouteSettings settings) {
    final Uri? uri;
    if (settings.name == null || (uri = Uri.tryParse(settings.name!)) == null) {
      return null;
    }
    if (uri!.pathSegments.length <= 1) return uri.path;
    switch (uri.pathSegments) {
      case [String first, ...] when intParamRoutes.contains(first):
        if (uri.pathSegments.length > 1) {
          if ((int.tryParse(uri.pathSegments[1]) ?? -1) >= 0) {
            return "/$first/$idPathParameter${uri.path.substring("/$first/${uri.pathSegments[1]}".length)}";
          } else if (intParamSegUniqueFollow[first] == uri.pathSegments[1]) {
            return uri.path;
          } else {
            return null;
          }
        }
        return uri.path;
      case [String first, ...] when stringParamRoutes.contains(first):
        if (uri.pathSegments.length > 1) {
          if ((int.tryParse(uri.pathSegments[1]) ?? -1) >= 0) {
            return "/$first/$namePathParameter${uri.path.substring("/$first/${uri.pathSegments[1]}".length)}";
          } /* else if (intParamSegUniqueFollow[first] == uri.pathSegments[1]) {
            return uri.path;
          } else {
            return null;
          } */
        }
        return uri.path;
      default:
        for (final first in intParamRouteExceptions) {
          if (!uri.path.startsWith(first)) continue;
          final offset = Uri.parse(first).pathSegments.length;
          assert(uri.pathSegments.elementAtOrNull(offset - 1) != null);
          final nextSeg = uri.pathSegments.elementAtOrNull(offset);
          if (nextSeg != null) {
            if ((int.tryParse(nextSeg) ?? -1) >= 0) {
              return "$first/$idPathParameter${uri.path.substring("$first/$nextSeg".length)}";
            } else if (intParamRouteExceptionsUniqueFollow[first] ==
                uri.pathSegments[1]) {
              return uri.path;
            } else {
              return null;
            }
          }
        }
        return uri.path;
    }
    /* return uri.pathSegments.foldUntilTrue<List?>(null, (p, e, i, _) {
      if (e == routeSegmentsConst[i]) return ((p ?? [])..add(e), false);
      final v = parsePathParam(i, e);
      return v == null ? (null, true) : ((p ?? [])..add(v), true);
    }); */
  }

  static bool acceptsRoutePath(
    RouteSettings settings,
    final List<String> routeSegmentsConst,
    final bool hasStaticPathConst,
  ) {
    parsePathParam(int i, String e) =>
        IRoute.pathParametersMethod[routeSegmentsConst[i]]?.call(e);
    final Uri? uri;
    return !(settings.name == null ||
        (uri = Uri.tryParse(settings.name!)) == null ||
        uri!.pathSegments.length != routeSegmentsConst.length ||
        hasStaticPathConst &&
            uri.pathSegments.anyFull((e, i, _) => e != routeSegmentsConst[i]) ||
        !hasStaticPathConst &&
            uri.pathSegments.anyFull((e, i, _) =>
                e != routeSegmentsConst[i] && parsePathParam(i, e) == null));
  }

  /// Same starting point as [acceptsRoutePath], but retrieves either the partially validated uri or a null value.
  static Uri? retrieveValidUri(
    RouteSettings settings,
    final List<String> routeSegmentsConst,
    final bool hasStaticPathConst,
  ) {
    parsePathParam(int i, String e) =>
        IRoute.pathParametersMethod[routeSegmentsConst[i]]?.call(e);
    final Uri? uri;
    if (settings.name == null ||
        (uri = Uri.tryParse(settings.name!)) == null ||
        uri!.pathSegments.length != routeSegmentsConst.length ||
        hasStaticPathConst &&
            uri.pathSegments.anyFull((e, i, _) => e != routeSegmentsConst[i]) ||
        !hasStaticPathConst &&
            uri.pathSegments.anyFull((e, i, _) =>
                e != routeSegmentsConst[i] && parsePathParam(i, e) == null)) {
      return null;
    }
    return uri;
  }

  static ({int? id, Map<String, String> parameters, Uri url}) legacyRouteInit(
      RouteSettings settings) {
    final url = Uri.parse(settings.name!);
    final parameters = main.tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    return (url: url, parameters: parameters, id: id);
  }

  static ({int? id, Map<String, List<String>> parameters, Uri url})
      legacyRouteInitFull(RouteSettings settings) {
    final url = Uri.parse(settings.name!);
    final parameters = main.tryParsePathToQueryOfList(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"]?.firstOrNull ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"]?.firstOrNull ?? "");
    }
    return (url: url, parameters: parameters, id: id);
  }

  /* static baseInit(
    RouteSettings settings, {
    final List<String>? routeSegmentsConst,
  }) {
    if (routeSegmentsConst == null) {
      return RouteParameterResolver.fromRouteSettings(
          settings, routeSegmentsConst ?? []);
    }
    final url = Uri.parse(settings.name!);
    final parameters = main.tryParsePathToQuery(url);
    int? id;
    try {
      id = (settings.arguments as dynamic)?.id ??
          int.tryParse(parameters["id"] ?? "");
    } catch (_) {
      id = int.tryParse(parameters["id"] ?? "");
    }
    return ret(url: url, parameters: parameters, id: id);
  } */

  static const idPathParameter = "!id!",
      namePathParameter = "!name!",
      idOrNamePathParameter = "!idOrName!",
      pathParametersRegex = {
        idPathParameter: r"^[0-9]+$",
        namePathParameter: r"^.+$",
        idOrNamePathParameter: r"^[0-9]+$|^.+$",
      },
      pathParametersMethod = {
        idPathParameter: parseIdParameter,
        namePathParameter: parseNameParameter,
        idOrNamePathParameter: parseIdOrNameParameterUnion,
      };
  // #region PathParsers
  static int? parseIdParameter(String pathSegment) {
    final int r = int.tryParse(pathSegment) ?? -1;
    return r >= 0 ? r : null;
  }

  static String? parseNameParameter(String pathSegment) =>
      pathSegment.isNotEmpty ? pathSegment : null;
  static Object? parseIdOrNameParameter(String pathSegment) {
    final int? r = int.tryParse(pathSegment);
    return (r ?? 1) >= 0 ? r ?? parseNameParameter(pathSegment) : null;
  }

  static StringOrInt? parseIdOrNameParameterUnion(String pathSegment) {
    final int? r = int.tryParse(pathSegment);
    return (r ?? 1) >= 0
        ? (r ?? parseNameParameter(pathSegment)) == null
            ? null
            : StringOrInt(r ?? parseNameParameter(pathSegment))
        : null;
  }
  // #endregion PathParsers
}
// abstract interface class IRouteArguments<T extends IRouteArguments<T>> {

// }
// abstract interface class IQueryArguments<T extends IQueryArguments<T>> extends IRouteArguments<IQueryArguments> {

// }
mixin IRouteReturns<T extends IRouteReturns<T, RetVal>, RetVal> on Widget {}
mixin IRouteReturnsStateless<T extends IRouteReturnsStateless<T, RetVal>,
    RetVal> on StatelessWidget implements IRouteReturns<T, RetVal> {
  @protected
  void doReturn(BuildContext context, RetVal returnValue) =>
      Navigator.pop(context, returnValue);
}
mixin IRouteReturnsStateful<T extends IRouteReturnsStateful<T, RetVal>, RetVal>
    on StatefulWidget implements IRouteReturns<T, RetVal> {
  @override
  State<IRouteReturnsStateful<T, RetVal>> createState();
}
mixin IRouteReturnsState<T extends IRouteReturnsStateful<T, RetVal>, RetVal>
    on State<IRouteReturnsStateful<T, RetVal>> {
  @protected
  void doReturn(BuildContext context, RetVal returnValue) =>
      Navigator.pop(context, returnValue);
}

final class StringOrInt extends StringOrIntNullable {
  @override
  get $ => _i ?? _s!;
  @override
  set $(v) {
    switch (v) {
      case int i:
        _i = i;
        _s = null;
        break;
      case String s:
        _s = s;
        _i = null;
        break;
      default:
        throw ArgumentError.value(v, "v", "Must be int or String");
    }
  }

  StringOrInt(super.v) : super();
  static StringOrInt? checked(v) {
    try {
      return StringOrInt(v);
    } catch (_) {
      return null;
    }
  }
}

final class StringOrIntNullable {
  int? _i;
  String? _s;
  get $ => _i ?? _s;
  set $(v) {
    switch (v) {
      case int i:
        _i = i;
        _s = null;
        break;
      case String s:
        _s = s;
        _i = null;
        break;
      case null:
        _s = _i = null;
        break;
      default:
        throw ArgumentError.value(v, "v", "Must be int, String, or null");
    }
  }

  StringOrIntNullable(v) {
    $ = v;
  }
  @override
  bool operator ==(Object other) =>
      other == $ || other is StringOrIntNullable && other.$ == $;

  @override
  int get hashCode => Object.hash(_i, _s);
}
