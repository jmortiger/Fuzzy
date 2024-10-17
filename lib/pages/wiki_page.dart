import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/main.dart';
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dtext;
import 'package:e621/e621.dart' as e621;

class WikiPage extends StatelessWidget {
  final e621.WikiPage wikiPage;
  final bool isFullPage;
  const WikiPage({
    super.key,
    required this.wikiPage,
    this.isFullPage = true,
  });

  @override
  Widget build(BuildContext context) {
    final root = Text.rich(dtext.parse(wikiPage.body, context));
    return isFullPage
        ? Scaffold(
            appBar: AppBar(title: Text(wikiPage.title)),
            body: SafeArea(child: SingleChildScrollView(child: root)),
          )
        : root;
  }
}

typedef WikiPageParameters = ({
  e621.WikiPage? wikiPage,
  int? id,
  String? title
});

class WikiPageByTitleRoute with IRoute<WikiPageLoader> {
  static const routeNameConst = "/wiki_pages",
      routePathConst = "/wiki_pages/show_or_new",
      hasStaticPathConst = true,
      routeSegmentsConst = ["wiki_pages", "show_or_new"];

  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final (:id, :parameters, :url) = IRoute.legacyRouteInit(settings);
    return legacyBuilder(settings, id, url, parameters)!;
  }

  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeName => routeNameConst;
  @override
  get routeSegmentsFolded => routePathConst;
  static Widget? legacyBuilder(RouteSettings settings, int? id, Uri url,
      Map<String, String> parameters) {
    try {
      try {
        final v = (settings.arguments as dynamic).wikiPage!;
        return WikiPage(wikiPage: v);
      } catch (_) {
        final String? title = url.queryParameters["search[title]"] ??
            url.queryParameters["title"] ??
            (settings.arguments as dynamic)?.title;
        if (title != null) {
          return WikiPageLoader.fromTitle(title: title);
        } else {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
          );
          return null;
        }
      }
    } catch (e, s) {
      routeLogger.severe(
        "Routing failure\n"
        "\tRoute: ${settings.name}\n"
        "\tId: $id\n"
        "\tArgs: ${settings.arguments}",
        e,
        s,
      );
      return null;
    }
  }
}

class WikiPageLoader extends StatefulWidget with IRoute<WikiPageLoader> {
  static const routeNameConst = "/wiki_pages",
      routePathConst = "/wiki_pages/${IRoute.idPathParameter}",
      hasStaticPathConst = false,
      routeSegmentsConst = ["wiki_pages", IRoute.idPathParameter];

  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final (:id, :parameters, :url) = IRoute.legacyRouteInit(settings);
    return legacyBuilder(settings, id, url, parameters)!;
  }

  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeName => routeNameConst;
  @override
  get routeSegmentsFolded => routePathConst;
  static Widget? legacyBuilder(RouteSettings settings, int? id, Uri url,
      Map<String, String> parameters) {
    try {
      try {
        final v = (settings.arguments as dynamic).wikiPage!;
        return WikiPage(wikiPage: v);
      } catch (_) {
        id ??= (settings.arguments as WikiPageParameters?)?.id;
        if (id != null) {
          return WikiPageLoader.fromId(id: id);
        } else if ((url.queryParameters["search[title]"] ??
                url.queryParameters["title"] ??
                (settings.arguments as WikiPageParameters?)?.title) !=
            null) {
          return WikiPageLoader.fromTitle(
            title: url.queryParameters["search[title]"] ??
                url.queryParameters["title"] ??
                (settings.arguments as WikiPageParameters).title!,
          );
        } else {
          routeLogger.severe(
            "Routing failure\n"
            "\tRoute: ${settings.name}\n"
            "\tId: $id\n"
            "\tArgs: ${settings.arguments}",
          );
          return null;
        }
      }
    } catch (e, s) {
      routeLogger.severe(
        "Routing failure\n"
        "\tRoute: ${settings.name}\n"
        "\tId: $id\n"
        "\tArgs: ${settings.arguments}",
        e,
        s,
      );
      return null;
    }
  }

  final bool isFullPage;
  final String? title;
  final int? id;
  final e621.WikiPage? wikiPage;

  const WikiPageLoader.fromPage({
    super.key,
    required e621.WikiPage this.wikiPage,
    this.isFullPage = true,
  })  : title = null,
        id = null;
  const WikiPageLoader.fromTitle({
    super.key,
    required String this.title,
    this.isFullPage = true,
  })  : wikiPage = null,
        id = null;
  const WikiPageLoader.fromId({
    super.key,
    required int this.id,
    this.isFullPage = true,
  })  : wikiPage = null,
        title = null;

  @override
  State<WikiPageLoader> createState() => _WikiPageLoaderState();
}

class _WikiPageLoaderState extends State<WikiPageLoader> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WikiPage").logger;
  e621.WikiPage? wikiPage;
  Future<e621.WikiPage?>? f;
  @override
  void initState() {
    super.initState();
    wikiPage = widget.wikiPage;
    if (wikiPage == null) {
      f = e621
          .sendRequest(
            widget.id != null
                ? e621.initWikiGetPageRequest(widget.id!)
                : e621.initWikiSearchRequest(searchTitle: widget.title),
          )
          .then<e621.WikiPage?>(
              (value) => e621.WikiPage.fromRawJson(value.body))
          .onError((e, s) {
        logger.severe(e, e, s);
        return null;
      })
        ..then((v) => setState(() {
              wikiPage = v;
              f?.ignore();
              f = null;
            })).ignore()
        ..ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return f != null
        ? const AspectRatio(aspectRatio: 1, child: CircularProgressIndicator())
        : wikiPage != null
            ? WikiPage(
                wikiPage: wikiPage!,
                isFullPage: widget.isFullPage,
              )
            : const Text("Failed to load");
  }
}
