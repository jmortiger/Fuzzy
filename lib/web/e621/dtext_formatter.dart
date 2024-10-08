import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/web/e621/colors.dart' as e6_color;
import 'package:fuzzy/util/html_colors.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/widgets/w_post_thumbnail.dart';
import 'package:j_util/e621_models.dart';
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
                "$schemeAnd$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}",
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

enum DTextMatchers {
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
    r"\[spoiler\](?<main>.*?)\[\/spoiler\]",
    unimplementedStyle,
    dotAll: true,
  ),
  codeInline(
      r"`(?<main>.*?)`",
      TextStyle(
        fontFamily: "Consolas",
        fontFamilyFallback: ["Courier New", "monospace"],
      )),
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
  namedLink('"(?<main>.+?)":(?<url>${util.urlMatcherStr}){1}', linkStyle),
  tagLink(r"\[\[(?:(?<tag>.*?)\|){0,1}(?<main>.+?)\]\]", linkStyle),
  searchLink(r"{{(?<main>(?<data>.+?))}}", linkStyle),
  postLink(r"(?<main>post #(?<data>[0-9]+))", linkStyle),
  postChangesLink(r"(?<main>post changes #(?<data>[0-9]+))", linkStyle),
  topicLink(r"(?<main>topic #(?<data>[0-9]+))", linkStyle),
  commentLink(r"(?<main>comment #(?<data>[0-9]+))", linkStyle),
  blipLink(r"(?<main>blip #(?<data>[0-9]+))", linkStyle),
  poolLink(r"(?<main>pool #(?<data>[0-9]+))", linkStyle),
  setLink(r"(?<main>set #(?<data>[0-9]+))", linkStyle),
  takedownLink(r"(?<main>takedown #(?<data>[0-9]+))", linkStyle),
  recordLink(r"(?<main>record #(?<data>[0-9]+))", linkStyle),
  ticketLink(r"(?<main>ticket #(?<data>[0-9]+))", linkStyle),
  postThumbnail(r"(?<main>thumb #(?<data>[0-9]+))", unimplementedStyle),
  quote(
    r"\[quote\](?<main>.*?)\[\/quote\]",
    incorrectlyParsedStyle,
    dotAll: true,
  ),
  code(
    r"\[code\]\n?(?<main>.*?)\n?\[\/code\]",
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
  section(
    r"\[section"
    r"(?<data>(?<expanded>,expanded)?(?:=(?<title>.*?))?)?"
    r"\](?<main>.*?)\[\/section\]",
    incorrectlyParsedStyle,
    dotAll: true,
  ),
  ;

  static const e6Links = [searchLink];
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
            "1" =>
              Theme.of(context).textTheme.displayLarge /* headlineLarge */ ??
                  style,
            "2" =>
              Theme.of(context).textTheme.displayMedium /* headlineMedium */ ??
                  style,
            "3" =>
              Theme.of(context).textTheme.displaySmall /* headlineSmall */ ??
                  style,
            "4" => Theme.of(context).textTheme.headlineLarge /* labelLarge */ ??
                style,
            "5" =>
              Theme.of(context).textTheme.headlineMedium /* labelMedium */ ??
                  style,
            "6" => Theme.of(context).textTheme.headlineSmall /* labelSmall */ ??
                style,
            _ => throw UnsupportedError("Header value not supported"),
          },
        color => TextStyle(
            color: m.namedGroup("tagCategory") != null
                ? TagCategory.fromName(m.namedGroup("tagCategory")!).color
                : htmlColorsFull[m.namedGroup("colorName")] ??
                    makeColorFromHexString(m.namedGroup("hex"))!),
        section => Theme.of(context).textTheme.bodyMedium ?? style,
        quote => const TextStyle(),
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

  InlineSpan buildFromMatchRecursive({
    required RegExpMatch m,
    BuildContext? ctx,
  }) {
    const leftBorderWidth = 3.0,
        leftBorderPadding = leftBorderWidth + 2,
        borderRadius = BorderRadius.all(Radius.circular(3.75)),
        sectionBackground = [
          BoxShadow(
            color: e6_color.sectionLighten10,
            spreadRadius: 2,
          ),
        ],
        sectionTileBorderNone = BorderSide(color: Colors.transparent),
        sectionTileBorderShow = Border(
          bottom: sectionTileBorderNone,
          top: sectionTileBorderNone,
          left: BorderSide(
            color: e6_color.dtextSection,
            width: leftBorderWidth,
          ),
        ),
        sectionTileBorderHide = Border(
          bottom: sectionTileBorderNone,
          top: sectionTileBorderNone,
        );
    final style = ctx != null ? retrieveStyle(ctx, m) : this.style;
    String? text = m.namedGroup("main"); //getSubPatternFromPotentialMatch(m);
    bool isChildless = switch (this) {
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
      tagLink => LinkifySpan(
          linkifiers: const [TagLinkifier()],
          text: /* text! */ m.group(0)!,
          linkStyle: style,
          onOpen: util.defaultOnLinkifyOpen,
          // options: const LinkifyOptions(humanize: false),
          options: util.linkifierOptions,
        ),
      namedLink => LinkifySpan(
          text: m.group(0)!,
          linkifiers: const [NamedLinkifier()],
          linkStyle: style,
          onOpen: util.defaultOnLinkifyOpen,
          // options: const LinkifyOptions(humanize: false),
          options: util.linkifierOptions,
        ),
      escapedLink => LinkifySpan(
          text: m.group(1)!,
          linkifiers: const [util.MyLinkifier()],
          linkStyle: style,
          onOpen: util.defaultOnLinkifyOpen,
          // options: const LinkifyOptions(humanize: false),
          options: util.linkifierOptions,
        ),
      code when renderDTextSectionBg || renderDTextSectionLeftBorder =>
        WidgetSpan(
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
                  const EdgeInsets.fromLTRB(leftBorderPadding + 10, 0, 0, 0),
              child: Text.rich(
                parse(m.namedGroup("main")!, ctx),
                style: style,
              ),
            ),
          ),
        ),
      quote when renderDTextSectionBg || renderDTextSectionLeftBorder =>
        WidgetSpan(
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
                  const EdgeInsets.fromLTRB(leftBorderPadding + 10, 0, 0, 0),
              child: Text.rich(
                parse(m.namedGroup("main")!, ctx),
                style: style,
              ),
            ),
          ),
        ),
      section => WidgetSpan(
          child: (() {
            final root = ExpansionTile(
              visualDensity: VisualDensity(
                vertical: VisualDensity.minimumDensity,
                horizontal: VisualDensity.compact.horizontal,
              ),
              shape: renderDTextSectionLeftBorder
                  ? sectionTileBorderShow
                  : sectionTileBorderHide,
              collapsedShape: renderDTextSectionLeftBorder
                  ? sectionTileBorderShow
                  : sectionTileBorderHide,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              controlAffinity: ListTileControlAffinity.leading,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              title: /* Selectable */
                  Text.rich(
                parse(m.namedGroup("title") ?? "", ctx),
                style: style,
              ),
              initiallyExpanded: m.namedGroup("expanded") != null,
              children: [
                Text.rich(TextSpan(
                  text: isChildless ? text : null,
                  children: isChildless
                      ? null
                      : buildChildrenFromMatch(m: m, ctx: ctx),
                  style: style,
                ))
              ],
            ) /* ,
                themeData = ctx != null ? Theme.of(ctx) : null */
                ;
            return /* themeData != null
                ? Theme(
                    data: themeData.copyWith(
                      expansionTileTheme: themeData.expansionTileTheme.copyWith(
                        collapsedBackgroundColor: themeData.colorScheme.surface,
                      ),
                    ),
                    // data: themeData.copyWith(
                    //   dividerColor: themeData.colorScheme.surface,
                    //   dividerTheme: DividerThemeData(
                    //       color: themeData.colorScheme.surface),
                    // ),
                    child: root,
                  )
                :  */
                root;
          })(),
        ),
      // max of 150 for width and height or 1/5 the vertical height
      postThumbnail => WidgetSpan(
          child: WPostThumbnail.withId(
            key: ValueKey((int.parse(m.namedGroup("data")!))),
            id: int.parse(m.namedGroup("data")!),
            maxHeight: 150,
            maxWidth: 150,
            fit: BoxFit.contain,
          ),
        ),
      _ => RegExp(util.urlMatcherStr).hasMatch(text ?? "")
          ? LinkifySpan(
              text: text!,
              linkifiers: const [util.MyLinkifier()],
              linkStyle: style,
              onOpen: util.defaultOnLinkifyOpen,
              // options: const LinkifyOptions(humanize: false),
              options: util.linkifierOptions,
            )
          : TextSpan(
              text: isChildless ? text : null,
              children:
                  isChildless ? null : buildChildrenFromMatch(m: m, ctx: ctx),
              style: style,
            ),
    };
  }

  String? getSubPatternFromPotentialMatch(RegExpMatch? m) =>
      this != tagLink || this != namedLink // || (m?.group(2)?.isEmpty ?? true)
          ? m?.namedGroup("main")
          : m?.namedGroup("main");
  String getSubPatternFromMatch(RegExpMatch m) =>
      getSubPatternFromPotentialMatch(m)!;

  List<InlineSpan> buildChildrenFromMatch(
      {required RegExpMatch m, BuildContext? ctx}) {
    return rawParse(getSubPatternFromMatch(m), ctx);
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

List<InlineSpan> rawParse(String dText, [BuildContext? ctx]) {
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
          onOpen: util.defaultOnLinkifyOpen,
          linkStyle: util.defaultLinkStyle,
          // options: const LinkifyOptions(looseUrl: true)),
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
    ));
    dText = dText.substring(m.$1.end);
  }
  parsed.add(util.urlMatcher.hasMatch(dText)
      ? LinkifySpan(
          text: dText,
          linkifiers: const [util.MyLinkifier()],
          onOpen: util.defaultOnLinkifyOpen,
          linkStyle: util.defaultLinkStyle,
          options: util.linkifierOptions,
        )
      : TextSpan(text: dText));
  return parsed;
}

/// Recurses
///
/// https://e621.net/help/dtext
InlineSpan parse(String dText, [BuildContext? ctx]) {
  return TextSpan(children: rawParse(dText, ctx));
}

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
      RegExp(r"(\s)([A-Z])"),
      (match) => "_${match.group(2)!.toLowerCase()}",
    )
    .replaceAllMapped(
      RegExp(r"([A-Z])"),
      (match) => match.group(1)!.toLowerCase(),
    );
// #region Test Text
const testText = """
[section=Headers]
h1.h1
h2. h2
h3.h3
h4. h4
h5.h5
h6. h6
[/section]
[section=Colors]
[color=pink]I'm pink![/color]
[color=#ff0000]I'm red![/color]
[color=#f00]I'm red too![/color]
[color=artist]I'm an artist![/color]
[color=green]I span
2 lines![/color]
[/section]
patreon.com/MariArt
MariArt.info
[i]Italics [b]and bolded [color=red]and red[/color][/b] text[/i]
[sup]Superscript[/sup][sub]Subscript[/sub][spoiler]Spoiler[/spoiler]
[quote]Quote[/quote]
[code]std::cout << "Code Block!";[/code]
`std::cout << "Code Inline!";`
[section,expanded=Lists & Tables]
* Item 1
* Item 2
** Item 2A
** Item 2B
* Item 3
[table]
  [thead]
    [tr]
      [th] header [/th]
      [th] header [/th]
      [th] header [/th]
    [/tr]
  [/thead]
  [tbody]
    [tr]
      [td] column [/td]
      [td] column [/td]
      [td] column [/td]
    [/tr]
    [tr]
      [td] column [/td]
      [td] column [/td]
      [td] column [/td]
    [/tr]
  [/tbody]
[/table]
[/section]
[section=Links]
[[American Dragon: Jake Long|Wiki Link]] [[American Dragon: Jake Long]]
Tag search
{{jun_kobayashi rating:s}}
Post Link
post #3796501
Post changes
post changes #3796501
Forum Topic
topic #1234
Comment
comment #12345
Blip
blip #1234
Pool
pool #1234
Set
set #1
takedown request
takedown #1
feedback record
record #14
ticket
ticket #1234
thumb
thumb #3796501
Thank you "@/BaskyCase":https://x.com/BaskyCase & "@/nyaruh1":https://x.com/nyaruh1 for "Tennis Ace":https://wotbasket.itch.io/tennis-ace
"Twitter":https://x.com/tennisace_vn
On "Patreon":https://www.patreon.com/tennisace
whole
https://www.patreon.com/tennisace
w/o www.
https://patreon.com/tennisace
w/o scheme
www.patreon.com/tennisace
w/o scheme & www.
patreon.com/tennisace
escaped
<https://wotbasket.itch.io/tennis-ace>
back to back https://x.com/tennisace_vn w/ text in between https://x.com/tennisace_vn that could https://x.com/tennisace_vn confuse the parser
[/section]
[section]Pretend this is a really large block of text.[/section]
[section=Titled]This one has a title.[/section]
[section,expanded=Titled And Expanded]This is expanded and titled.[/section]
[section,expanded]This is expanded by default.[/section]""";
// #endregion Test Text
