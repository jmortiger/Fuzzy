import 'package:e621/ui.dart' as e6_color;
import 'package:e621/e621_models.dart' show TagCategory;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/util/html_colors.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/widgets/w_post_thumbnail.dart';
import 'package:fuzzy/log_management.dart' as lm;

// ignore: unnecessary_late
late final _logger = lm.generateLogger("DTextFormatter").logger;

// https://e621.net/help/dtext

const safety = 1000;

/// TODO: Add Setting for dtext section rendering
var renderDTextSectionLeftBorder = true;
var renderDTextSectionBg = false;

// #region Linkifiers
class TagJsonLinkifier extends UrlLinkifier {
  static const root = "e621.net/wiki_pages.json?search%5B" "title%5D=";
  const TagJsonLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    final scheme = "http${options.defaultToHttps ? "s" : ""}://";
    final schemeAnd = "${options.humanize ? "" : scheme}"
        "${options.removeWww ? "" : "www."}";
    return /* super.parse( */
        elements.map(
      (e) {
        final m = DTextMatchers.tagLink.pattern.firstMatch(e.text);
        return m == null
            ? UrlElement(
                // "${scheme}www.$root${convertToLink(e.text)}",
                "$schemeAnd$root${convertToLink(e.text)}",
                e.text,
              )
            : UrlElement(
                // "${scheme}www.$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}",
                "$schemeAnd$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}",
                m.namedGroup("main") ?? m.namedGroup("tag"),
              );
      },
    ).toList() /* ,
        options) */
        ;
  }
}

class TagLinkifier extends UrlLinkifier {
  static const root = "e621.net/wiki_pages/show_or_new?title=";
  const TagLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    final scheme = "http${options.defaultToHttps ? "s" : ""}://";
    final schemeAnd = "${options.humanize ? "" : scheme}"
        "${options.removeWww ? "" : "www."}";
    return /* super.parse( */
        elements.map(
      (e) {
        final m = DTextMatchers.tagLink.pattern.firstMatch(e.text);
        return m == null
            ? UrlElement(
                // "${scheme}www.$root${convertToLink(e.text)}",
                "$schemeAnd$root${convertToLink(e.text)}",
                e.text,
              )
            : UrlElement(
                // "${scheme}www.$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}",
                !DTextMatchers.anchorPattern.hasMatch(
                        (m.namedGroup("tag") ?? m.namedGroup("main"))!)
                    ? "$schemeAnd$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}"
                    : (m.namedGroup("tag") ?? m.namedGroup("main")!).trim(),
                m.namedGroup("main") ?? m.namedGroup("tag"),
              );
      },
    ).toList() /* ,
        options) */
        ;
  }
}

class E6Linkifier extends UrlLinkifier {
  static const root = "e621.net";
  const E6Linkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    final scheme = "http${options.defaultToHttps ? "s" : ""}://";
    final schemeAnd = "${options.humanize ? "" : scheme}"
        "${options.removeWww ? "" : "www."}";
    return /* super.parse( */
        elements.map(
      (e) {
        final m = firstMatches(e.text /* , DTextMatchers.e6Links */);
        return UrlElement(
          switch (m?.$2) {
            DTextMatchers.searchLink =>
              "$schemeAnd$root/posts?tags=${Uri.encodeComponent(
                m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!,
              )}",
            DTextMatchers.postLink => "$schemeAnd$root/posts/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.postChangesLink =>
              "$schemeAnd$root/post_versions?search[post_id]="
                  "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.topicLink => "$schemeAnd$root/forum_topics/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.commentLink => "$schemeAnd$root/comments/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.blipLink => "$schemeAnd$root/blips/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.poolLink => "$schemeAnd$root/pools/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.setLink => "$schemeAnd$root/post_sets/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.takedownLink => "$schemeAnd$root/takedowns/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.recordLink => "$schemeAnd$root/user_feedbacks/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            DTextMatchers.ticketLink => "$schemeAnd$root/ticket/"
                "${m!.$1.namedGroup("data") ?? m.$1.namedGroup("main")!}",
            // _ => throw UnsupportedError("type not supported"),
            _ => "$schemeAnd$root",
          },
          m?.$1.namedGroup("main") ?? e.text,
        );
      },
    ).toList() /* ,
        options) */
        ;
  }
}

class NamedLinkifier extends UrlLinkifier {
  const NamedLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    return super.parse(
        elements.map(
          (e) {
            final m = DTextMatchers.namedLink.pattern.firstMatch(e.text)!;
            return UrlElement(
              RegExp(util.urlMatcherStr).hasMatch(e.text)
                  ? m.group(2)!
                  : "http${options.defaultToHttps ? "s" : ""}://e621.net"
                      "${m.group(2)!}",
              m.group(1)!,
            );
          },
        ).toList(),
        options);
  }
}
// #endregion Linkifiers

class _Empty extends StatefulWidget {
  final void Function(BuildContext ctx)? onScroll;
  const _Empty({super.key, this.onScroll});

  @override
  State<_Empty> createState() => __EmptyState();
}

class __EmptyState extends State<_Empty> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 0, height: 0);
  // Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Anchor extends StatefulWidget {
  final void Function(BuildContext ctx)? onScroll;
  final ValueListenable<bool>? scrollRequested;
  const _Anchor({super.key, this.onScroll, this.scrollRequested});

  @override
  State<_Anchor> createState() => __AnchorState();
}

class __AnchorState extends State<_Anchor> {
  @override
  void initState() {
    super.initState();
    widget.scrollRequested?.addListener(listener);
  }

  @override
  void dispose() {
    widget.scrollRequested?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 0, height: 0);
  // Widget build(BuildContext context) => const SizedBox.shrink();

  void listener() {
    Scrollable.ensureVisible(context);
    widget.onScroll?.call(context);
  }
}

/// TODO: Scroll to collapsed section?
/// TODO: Pull into library
/// TODO: Add configurability (const matchers & defaults w/ an instanced class with fields that can be overridden)
enum DTextMatchers {
  /// [Ref](https://e621.net/help/dtext#basics)
  bold(
    r"\[b\](?<main>.*?)\[\/b\]",
    TextStyle(fontWeight: FontWeight.bold),
    dotAll: true,
  ),
  italics(
    r"\[i\](?<main>.*?)\[\/i\]",
    TextStyle(fontStyle: FontStyle.italic),
    dotAll: true,
  ),
  strikeThrough(
    r"\[s\](?<main>.*?)\[\/s\]",
    TextStyle(decoration: TextDecoration.lineThrough),
    dotAll: true,
  ),
  underline(
    r"\[u\](?<main>.*?)\[\/u\]",
    TextStyle(decoration: TextDecoration.underline),
    dotAll: true,
  ),
  superscript(
    r"\[sup\](?<main>.*?)\[\/sup\]",
    unimplementedStyle,
    dotAll: true,
  ),
  subscript(
    r"\[sub\](?<main>.*?)\[\/sub\]",
    unimplementedStyle,
    dotAll: true,
  ),
  spoiler(
    r"\[spoilers*\](?<main>.*?)\[\/spoilers*\]",
    unimplementedStyle,
    dotAll: true,
  ),
  codeInline(
    r"`(?<main>.*?)`",
    TextStyle(
      fontFamily: "Consolas",
      fontFamilyFallback: ["Courier New", "monospace"],
    ),
  ),

  /// TODO: Failed on this https://e621.net/wiki_pages/270.json
  /// TODO: Failed on this https://e621.net/show_or_new?title=the_legend_of_zelda

  /// [Ref](https://e621.net/help/dtext#colors)
  color(
    r"\[color(?:=(?<data>(?<tagCategory>"
    "${TagCategory.categoryNameRegExpStr}"
    r")|(?<colorName>"
    "$htmlColorsFullMatcher"
    r")|(?<hex>#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})|.*?){0,1})\](?<main>.*?)"
    r"\[\/color\]",
    incorrectlyParsedStyle,
    dotAll: true,
  ),
  // bareLink
  escapedLink(r"<(?<main>" "${util.urlMatcherStr}" r".*?)>", linkStyle),
  namedLink('"(?<main>.+?)":(?<url>${util.urlMatcherStr}|/\\S+){1}', linkStyle),
  tagLink(r"\[\[(?:(?<tag>.*?)\|){0,1}(?<main>.+?)\]\]", linkStyle),
  anchor(r"\[(?<data>#.+?)\](?<main>(?<=\]))", incorrectlyParsedStyle),
  searchLink(r"{{(?<main>(?<data>.+?))}}", linkStyle),
  postLink(r"(?<main>post #(?<data>[0-9]+))", linkStyle, caseSensitive: false),
  postChangesLink(r"(?<main>post changes #(?<data>[0-9]+))", linkStyle,
      caseSensitive: false),
  topicLink(r"(?<main>topic #(?<data>[0-9]+))", linkStyle,
      caseSensitive: false),
  commentLink(r"(?<main>comment #(?<data>[0-9]+))", linkStyle,
      caseSensitive: false),
  blipLink(r"(?<main>blip #(?<data>[0-9]+))", linkStyle, caseSensitive: false),
  poolLink(r"(?<main>pool #(?<data>[0-9]+))", linkStyle, caseSensitive: false),
  setLink(r"(?<main>set #(?<data>[0-9]+))", linkStyle, caseSensitive: false),
  takedownLink(r"(?<main>takedown #(?<data>[0-9]+))", linkStyle,
      caseSensitive: false),
  recordLink(r"(?<main>record #(?<data>[0-9]+))", linkStyle,
      caseSensitive: false),
  ticketLink(r"(?<main>ticket #(?<data>[0-9]+))", linkStyle,
      caseSensitive: false),
  postThumbnail(r"(?<main>thumb #(?<data>[0-9]+))", incorrectlyParsedStyle,
      caseSensitive: false),
  // Block formatting
  quote(
    r"\[quote\](?<main>.*?)\[\/quote\]",
    incorrectlyParsedStyle,
    dotAll: true,
  ),
  code(
    // infinite leading newlines are trimmed, 1 trailing newline is trimmed
    r"\[code\]\n*(?<main>.*?)\n?\[\/code\]",
    TextStyle(
      fontFamily: "Consolas",
      fontFamilyFallback: ["Courier New", "monospace"],
    ),
    dotAll: true,
  ),
  header(
    r"^(?:[\t ]*?)h(?<data>[1-6])\.\s?(?<main>.*)$",
    incorrectlyParsedStyle,
    multiLine: true,
    dotAll: false,
  ),

  /// [Ref](https://e621.net/help/dtext#list)
  ///
  /// Leading whitespace only trimmed as a result of HTML whitespace stripping,
  /// pattern 1 makes this consistently trim leading whitespace, pattern 2
  /// makes this consistently fail to match leading whitespace.
  list(
    // r"^[ \t]*?(?<data>\*+)[ \t]+?(?<main>.*?)$",
    r"^(?<data>\*+)[ \t]+?(?<main>.*?)$",
    TextStyle(),
    // dotAll: true,
    multiLine: true,
  ),
  section(
    r"\[section"
    r"(?<data>(?<expanded>,expanded)?(?:=(?<title>.*?))?)?"
    r"\](?<main>.*?)\[\/section\]",
    incorrectlyParsedStyle,
    dotAll: true,
  ),
  // table(
  //   r"\[table\](?<main>.*?)\[\/table\]",
  //   incorrectlyParsedStyle,
  //   dotAll: true,
  // ),
  ;

  // static const e6Links = [searchLink];
  static const blockFormats = [quote, code, header, list, section /*, table*/];
  static const unimplementedStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Colors.blue,
    debugLabel: "DText unimplemented",
  );
  static const incorrectlyParsedStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Colors.yellow,
    debugLabel: "DText incorrectlyParsed",
  );
  static const errorStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Colors.red,
    debugLabel: "DText error",
  );
  static const linkStyle = TextStyle(
    // fontStyle: FontStyle.italic,
    color: e6_color.link,
    decoration: TextDecoration.underline,
  );
  static const anchorPatternStr = r"^\s*?#(?<anchor>.+)$";
  static RegExp get anchorPattern => RegExp(anchorPatternStr);
  final String patternStr;
  final TextStyle style;
  final bool multiLine, caseSensitive, unicode, dotAll;
  const DTextMatchers(
    this.patternStr,
    this.style, {
    this.multiLine = false,
    this.caseSensitive = true,
    this.unicode = false,
    this.dotAll = false,
  });
  RegExp get pattern => RegExp(
        patternStr,
        multiLine: multiLine,
        caseSensitive: caseSensitive,
        unicode: unicode,
        dotAll: dotAll,
      );
  // TextStyle styleFromCtx(BuildContext context) => switch (this) {
  //       h1 =>
  //         Theme.of(context).textTheme.displayLarge /* headlineLarge */ ?? style,
  //       h2 => Theme.of(context).textTheme.displayMedium /* headlineMedium */ ??
  //           style,
  //       h3 =>
  //         Theme.of(context).textTheme.displaySmall /* headlineSmall */ ?? style,
  //       h4 =>
  //         Theme.of(context).textTheme.headlineLarge /* labelLarge */ ?? style,
  //       h5 =>
  //         Theme.of(context).textTheme.headlineMedium /* labelMedium */ ?? style,
  //       h6 =>
  //         Theme.of(context).textTheme.headlineSmall /* labelSmall */ ?? style,
  //       _ => style,
  //     };
  static Color? makeColorFromHexString(String? s) {
    if (s?.isEmpty ?? true) return null;
    if (s![0] == "#") s = s.substring(1);
    if (s.length == 3) s = "${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}";
    final i = int.tryParse("ff$s", radix: 16);
    return (i == null) ? null : Color(i);
  }

  TextStyle retrieveStyle(BuildContext context, RegExpMatch m) =>
      switch (this) {
        header => switch (m.namedGroup("data")) {
            // "1" => Theme.of(context).textTheme.displayLarge ?? style,
            // "2" => Theme.of(context).textTheme.displayMedium ?? style,
            // "3" => Theme.of(context).textTheme.displaySmall ?? style,
            // "4" => Theme.of(context).textTheme.headlineLarge ?? style,
            // "5" => Theme.of(context).textTheme.headlineMedium ?? style,
            // "6" => Theme.of(context).textTheme.headlineSmall ?? style,
            "1" => Theme.of(context).textTheme.headlineLarge ?? style,
            "2" => Theme.of(context).textTheme.headlineMedium ?? style,
            "3" => Theme.of(context).textTheme.headlineSmall ?? style,
            "4" => Theme.of(context).textTheme.titleLarge ?? style,
            "5" => Theme.of(context).textTheme.titleMedium ?? style,
            "6" => Theme.of(context).textTheme.titleSmall ?? style,
            _ => throw UnsupportedError("Header value not supported"),
          },
        color => TextStyle(
            color: m.namedGroup("tagCategory") != null
                ? TagCategory.fromName(m.namedGroup("tagCategory")!).color
                : htmlColorsFull[m.namedGroup("colorName")] ??
                    makeColorFromHexString(m.namedGroup("hex"))!),
        section => Theme.of(context).textTheme.bodyMedium ?? style,
        quote || spoiler => const TextStyle(),
        // subscript => const TextStyle(fontFeatures: [FontFeature.subscripts()]),
        // superscript =>
        //   const TextStyle(fontFeatures: [FontFeature.superscripts()]),
        subscript ||
        superscript =>
          Theme.of(context).textTheme.labelSmall ?? style,
        // subscript || superscript => style.copyWith(
        //     fontSize: Theme.of(context).textTheme.labelSmall?.fontSize,
        //   ),
        _ => style,
      };
  (RegExpMatch, DTextMatchers)? firstMatch(String dText) {
    final m = pattern.firstMatch(dText);
    return m == null ? null : (m, this);
  }

  (RegExpMatch, String subPattern, DTextMatchers)? firstMatchWithString(
      String dText) {
    final m = pattern.firstMatch(dText);
    return m == null ? null : (m, m.namedGroup("main")!, this);
  }

  // static buildAnchorLinkOnOpenWithController(ScrollController scrollController) => (LinkableElement link) => scrollController;
  static buildAnchorLinkOnOpenWithKeys(Map<String, GlobalKey> anchorKeys) =>
      (LinkableElement link) {
        final ctx = anchorKeys[link.url]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx);
      };

  InlineSpan buildFromMatchRecursive({
    required RegExpMatch m,
    BuildContext? ctx,
    // ScrollController? scrollController,
    Map<String, GlobalKey>? anchorKeys,
    Map<String, VoidCallback>? anchorTriggerScrolls,
  }) {
    // #region Constants
    const leftBorderWidth = 3.0,
        leftBorderPadding = leftBorderWidth + 2,
        borderRadius = BorderRadius.all(Radius.circular(3.75)),
        sectionBackground = [
          BoxShadow(color: e6_color.sectionLighten10, spreadRadius: 2),
        ],
        sectionTileBorderNone = BorderSide(color: Colors.transparent),
        sectionTileBorderShow = Border(
          bottom: sectionTileBorderNone,
          top: sectionTileBorderNone,
          left:
              BorderSide(color: e6_color.dtextSection, width: leftBorderWidth),
        ),
        sectionTileBorderHide = Border(
          bottom: sectionTileBorderNone,
          top: sectionTileBorderNone,
        ), // tabText = "		";
        tabText = "    ";
    // #endregion Constants
    getSectionShape() => renderDTextSectionLeftBorder
        ? sectionTileBorderShow
        : sectionTileBorderHide;
    final style = ctx != null ? retrieveStyle(ctx, m) : this.style;
    String? text = m.namedGroup("main");
    bool isChildless = switch (this) {
      anchor ||
      tagLink ||
      namedLink ||
      postLink ||
      postChangesLink ||
      setLink ||
      blipLink ||
      poolLink ||
      topicLink ||
      recordLink ||
      commentLink ||
      ticketLink ||
      takedownLink ||
      postThumbnail =>
        true,
      _ => firstMatches(text ?? "") == null,
    };
    TextSpan defaultParser(String? text) {
      return RegExp(util.urlMatcherStr).hasMatch(text ?? "")
          ? LinkifySpan(
              text: text!,
              linkifiers: const [util.MyLinkifier()],
              linkStyle: style,
              onOpen: ctx != null &&
                      RegExp("e621|e926").hasMatch(RegExp(util.urlMatcherStr)
                          .firstMatch(text)!
                          .group(3)!)
                  ? util.buildDefaultOnE6LinkifyOpen(ctx)
                  : util.defaultOnLinkifyOpen,
              options: util.linkifierOptions,
            )
          : TextSpan(
              text: isChildless ? text : null,
              children: isChildless
                  ? null
                  : buildChildrenFromMatch(
                      m: m,
                      ctx: ctx,
                      anchorKeys: anchorKeys,
                      anchorTriggerScrolls: anchorTriggerScrolls,
                    ),
              style: style,
            );
    }

    return switch (this) {
      searchLink ||
      postLink ||
      postChangesLink ||
      setLink ||
      blipLink ||
      poolLink ||
      topicLink ||
      recordLink ||
      commentLink ||
      ticketLink ||
      takedownLink =>
        LinkifySpan(
          linkifiers: const [E6Linkifier()],
          text: /* text! */ m.group(0)!,
          linkStyle: style,
          style: style,
          // onOpen: util.defaultOnLinkifyOpen,
          // onOpen: util.defaultOnE6LinkifyOpen,
          onOpen: ctx != null
              ? util.buildDefaultOnE6LinkifyOpen(ctx)
              : util.defaultOnLinkifyOpen,
          options: util.linkifierOptions,
        ),
      anchor => anchorKeys != null
          ? (() {
              final data = m.namedGroup("data")!;
              _logger.info("building anchorKey for $data");
              return WidgetSpan(
                  child: _Empty(
                key: anchorKeys[data] = GlobalObjectKey<__EmptyState>(data),
              ));
            })()
          : anchorTriggerScrolls != null
              ? (() {
                  final data = m.namedGroup("data")!,
                      doScroll = ValueNotifier(false);
                  _logger.info("building anchorTrigger for $data");
                  anchorTriggerScrolls[data] =
                      () => doScroll.value = !doScroll.value;
                  return WidgetSpan(child: _Anchor(scrollRequested: doScroll));
                })()
              : const TextSpan(),
      tagLink =>
        !anchorPattern.hasMatch((m.namedGroup("tag") ?? m.namedGroup("main"))!)
            ? LinkifySpan(
                linkifiers: const [TagLinkifier()],
                text: m.group(0)!,
                linkStyle: style,
                onOpen: ctx != null
                    ? util.buildDefaultOnE6LinkifyOpen(ctx)
                    : util.defaultOnLinkifyOpen,
                options: util.linkifierOptions,
              )
            : LinkifySpan(
                linkifiers: const [TagLinkifier()],
                text: m.group(0)!,
                linkStyle: style,
                // onOpen: util.defaultOnLinkifyOpen,
                onOpen: (link) {
                  _logger.info(
                      "Trying to launch ${link.url}/${(m.namedGroup("tag") ?? m.namedGroup("main"))!}");
                  anchorKeys != null
                      ? buildAnchorLinkOnOpenWithKeys(anchorKeys)(link)
                      : anchorTriggerScrolls?[
                              (m.namedGroup("tag") ?? m.namedGroup("main"))!
                                  .trim()]
                          ?.call();
                },
                // onOpen: anchorKeys != null
                //     ? buildAnchorLinkOnOpenWithKeys(anchorKeys)
                //     : anchorTriggerScrolls?[
                //         (m.namedGroup("tag") ?? m.namedGroup("main"))!
                //             .trim()],
                options: util.linkifierOptions,
              ),
      namedLink => LinkifySpan(
          text: m.group(0)!,
          linkifiers: const [NamedLinkifier()],
          linkStyle: style,
          onOpen: ctx != null
              ? util.buildDefaultOnE6LinkifyOpen(ctx)
              : util.defaultOnLinkifyOpen,
          options: util.linkifierOptions,
        ),
      escapedLink => LinkifySpan(
          text: m.group(1)!,
          linkifiers: const [util.MyLinkifier()],
          linkStyle: style,
          onOpen: ctx != null
              ? util.buildDefaultOnE6LinkifyOpen(ctx)
              : util.defaultOnLinkifyOpen,
          options: util.linkifierOptions,
        ),
      code when renderDTextSectionBg || renderDTextSectionLeftBorder =>
        WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: renderDTextSectionLeftBorder
                  ? const Border(
                      left: BorderSide(
                        color: e6_color.dtextCode,
                        width: leftBorderWidth,
                      ),
                    )
                  : null,
              boxShadow: renderDTextSectionBg ? sectionBackground : null,
              borderRadius: borderRadius,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(leftBorderPadding + 10, 10, 10, 10),
              child: Text.rich(
                TextSpan(
                    children: rawParse(
                  m.namedGroup("main")!,
                  ctx: ctx,
                  anchorKeys: anchorKeys,
                  anchorTriggerScrolls: anchorTriggerScrolls,
                )),
                style: style,
                softWrap: true,
                maxLines: null,
              ),
            ),
          ),
        ),
      quote when renderDTextSectionBg || renderDTextSectionLeftBorder =>
        WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: renderDTextSectionLeftBorder
                  ? const Border(
                      left: BorderSide(
                        color: e6_color.dtextQuote,
                        width: leftBorderWidth,
                      ),
                    )
                  : null,
              boxShadow: renderDTextSectionBg ? sectionBackground : null,
              borderRadius: borderRadius,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(leftBorderPadding + 10, 10, 10, 10),
              child: Text.rich(
                TextSpan(
                    children: rawParse(
                  m.namedGroup("main")!,
                  ctx: ctx,
                  anchorKeys: anchorKeys,
                  anchorTriggerScrolls: anchorTriggerScrolls,
                )),
                style: style,
                softWrap: true,
                maxLines: null,
              ),
            ),
          ),
        ),
      section => WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: ExpansionTile(
            visualDensity: VisualDensity(
              vertical: VisualDensity.minimumDensity,
              horizontal: VisualDensity.compact.horizontal,
            ),
            shape: getSectionShape(),
            collapsedShape: getSectionShape(),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            controlAffinity: ListTileControlAffinity.leading,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            title: /* Selectable */
                Text.rich(
              TextSpan(
                  children: rawParse(
                m.namedGroup("title") ?? "",
                ctx: ctx,
                anchorKeys: anchorKeys,
                anchorTriggerScrolls: anchorTriggerScrolls,
              )),
              style: style,
            ),
            initiallyExpanded: m.namedGroup("expanded") != null,
            children: [
              Flexible(
                flex: 0,
                child: Text.rich(TextSpan(
                  text: isChildless ? text : null,
                  children: isChildless
                      ? null
                      : buildChildrenFromMatch(
                          m: m,
                          ctx: ctx,
                          anchorKeys: anchorKeys,
                          anchorTriggerScrolls: anchorTriggerScrolls,
                        ),
                  style: style,
                )),
              )
            ],
          ),
        ),
      postThumbnail => WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: WPostThumbnail.withId(
            key: ValueKey((int.parse(m.namedGroup("data")!))),
            id: int.parse(m.namedGroup("data")!),
            maxHeight: 150,
            maxWidth: 150,
            fit: BoxFit.contain,
          ),
        ),
      list => defaultParser(
          "${List.generate(m.namedGroup("data")!.length, (index) => tabText).reduce((p, c) => "$p$c")} • $text"),
      superscript => WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: Transform.translate(
              offset: const Offset(0, -4),
              child: Text.rich(
                defaultParser(text),
                textScaler: const TextScaler.linear(.7),
              ))),
      subscript => WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: Transform.translate(
              offset: const Offset(0, 2),
              child: Text.rich(
                defaultParser(text),
                textScaler: const TextScaler.linear(.7),
              ))),
      spoiler => WidgetSpan(
          // alignment: PlaceholderAlignment.top,
          child: (() {
            bool isRevealed = false;
            return StatefulBuilder(
              builder: (context, setState) => GestureDetector(
                child: Text.rich(
                  defaultParser(text),
                  style: isRevealed
                      ? style
                      : const TextStyle(
                          color: Colors.black,
                          backgroundColor: Colors.black,
                        ),
                ),
                onTap: () => setState(() => isRevealed = !isRevealed),
              ),
            );
          })(),
        ),
      _ => defaultParser(text),
    };
  }

  String? getSubPatternFromPotentialMatch(RegExpMatch? m) =>
      this != tagLink || this != namedLink // || (m?.group(2)?.isEmpty ?? true)
          ? m?.namedGroup("main")
          : m?.namedGroup("main");
  String getSubPatternFromMatch(RegExpMatch m) =>
      getSubPatternFromPotentialMatch(m)!;

  List<InlineSpan> buildChildrenFromMatch({
    required RegExpMatch m,
    BuildContext? ctx,
    Map<String, GlobalKey>? anchorKeys,
    Map<String, VoidCallback>? anchorTriggerScrolls,
  }) {
    return rawParse(
      getSubPatternFromMatch(m),
      ctx: ctx,
      anchorKeys: anchorKeys,
      anchorTriggerScrolls: anchorTriggerScrolls,
    );
  }
}

(RegExpMatch, DTextMatchers)? firstMatches(
  String dText, [
  Iterable<DTextMatchers> toSearch = DTextMatchers.values,
]) {
  (RegExpMatch, DTextMatchers)? m;
  int firstIndex = double.maxFinite.toInt();
  for (final r in toSearch) {
    final mc = r.firstMatch(dText);
    if ((mc?.$1.start ?? firstIndex) < firstIndex) {
      m = mc;
      firstIndex = mc!.$1.start;
    }
  }

  return m;
}

List<InlineSpan> rawParse(
  String dText, {
  BuildContext? ctx,
  Map<String, GlobalKey>? anchorKeys,
  Map<String, VoidCallback>? anchorTriggerScrolls,
}) {
  // anchorKeys ??= {};
  anchorTriggerScrolls ??= {};
  List<InlineSpan> parsed = [/* TextSpan(text: dText) */];
  for (var i = 0, m = firstMatches(dText);
      m != null && i < safety;
      ++i, m = firstMatches(dText)) {
    var before = dText.substring(0, m.$1.start);
    var beforeUrlMatch = RegExp("(${util.urlMatcherStr})").firstMatch(before);
    while (beforeUrlMatch != null) {
      parsed.addAll([
        TextSpan(text: before.substring(0, beforeUrlMatch.start)),
        LinkifySpan(
          text: beforeUrlMatch.group(1)!,
          linkifiers: const [util.MyLinkifier()],
          onOpen: ctx != null
              ? util.buildDefaultOnE6LinkifyOpen(ctx)
              : util.defaultOnLinkifyOpen,
          linkStyle: util.defaultLinkStyle,
          options: util.linkifierOptions,
        ),
      ]);
      before = before.substring(beforeUrlMatch.end);
      beforeUrlMatch = RegExp("(${util.urlMatcherStr})").firstMatch(before);
    }
    parsed.add(TextSpan(text: before));
    parsed.add(m.$2.buildFromMatchRecursive(
      m: m.$1,
      ctx: ctx,
      anchorKeys: anchorKeys,
      anchorTriggerScrolls: anchorTriggerScrolls,
    ));
    dText = dText.substring(m.$1.end);
  }
  parsed.add(util.urlMatcher.hasMatch(dText)
      ? LinkifySpan(
          text: dText,
          linkifiers: const [util.MyLinkifier()],
          onOpen: ctx != null
              ? util.buildDefaultOnE6LinkifyOpen(ctx)
              : util.defaultOnLinkifyOpen,
          linkStyle: util.defaultLinkStyle,
          options: util.linkifierOptions,
        )
      : TextSpan(text: dText));
  return parsed;
}

/// Recurses
///
/// https://e621.net/help/dtext
InlineSpan parse(
  String dText, [
  BuildContext? ctx,
  Map<String, GlobalKey>? anchorKeys,
  Map<String, VoidCallback>? anchorTriggerScrolls,
]) =>
    TextSpan(
        children: rawParse(
      dText,
      ctx: ctx,
      anchorKeys: anchorKeys,
      anchorTriggerScrolls: anchorTriggerScrolls,
    ));

/// Recurses
///
/// https://e621.net/help/dtext
InlineSpan tryParse(
  String dText, {
  BuildContext? ctx,
  TextStyle errorStyle = const TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: Colors.red,
  ),
}) {
  try {
    return parse(dText, ctx);
  } catch (e, s) {
    _logger.warning("Failed to parse DText $dText", e, s);
    return TextSpan(text: dText, style: errorStyle);
  }
}

String convertToLink(String link) => link
    .replaceAllMapped(
      RegExp(r"(\s)([A-Za-z])"),
      (match) => "_${match.group(2)!.toLowerCase()}",
    )
    .replaceAllMapped(
      RegExp(r"([A-Z])"),
      (match) => match.group(1)!.toLowerCase(),
    );
