import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dtext;
import 'package:j_util/e621.dart' as e621;

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

class WikiPageBuilder extends StatefulWidget
    implements IRoute<WikiPageBuilder> {
  static const routeNameString = "/wiki_pages";
  @override
  get routeName => routeNameString;
  final bool isFullPage;
  final String? title;
  final int? id;
  final e621.WikiPage? wikiPage;
  const WikiPageBuilder.fromPage({
    super.key,
    required e621.WikiPage this.wikiPage,
    this.isFullPage = true,
  })  : title = null,
        id = null;
  const WikiPageBuilder.fromTitle({
    super.key,
    required String this.title,
    this.isFullPage = true,
  })  : wikiPage = null,
        id = null;
  const WikiPageBuilder.fromId({
    super.key,
    required int this.id,
    this.isFullPage = true,
  })  : wikiPage = null,
        title = null;

  @override
  State<WikiPageBuilder> createState() => _WikiPageBuilderState();
}

class _WikiPageBuilderState extends State<WikiPageBuilder> {
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
