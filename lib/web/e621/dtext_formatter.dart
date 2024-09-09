import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/util/html_colors.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:j_util/e621_models.dart';
import 'package:fuzzy/log_management.dart' as lm;

// ignore: unnecessary_late
late final _logger = lm.generateLogger("DTextFormatter").logger;

// https://e621.net/help/dtext

const tagLinkStyle = TextStyle(
    fontStyle: FontStyle.italic,
    color: Colors.amber,
    decoration: TextDecoration.underline);

const safety = 1000;

// #region Linkifiers
class TagJsonLinkifier extends UrlLinkifier {
  static const root = "https://e621.net/wiki_pages.json?search%5Btitle%5D=";
  const TagJsonLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    return super.parse(
        elements.map(
          (e) {
            final m = DTextMatchers.tagLink.pattern.firstMatch(e.text);
            return m == null
                ? UrlElement(
                    "$root${convertToLink(e.text)}",
                    e.text,
                  )
                : UrlElement(
                    "$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}",
                    m.namedGroup("main") ?? m.namedGroup("tag"),
                  );
          },
        ).toList(),
        options);
  }
}

class TagLinkifier extends UrlLinkifier {
  static const root = "https://e621.net/wiki_pages/show_or_new?title=";
  const TagLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    return super.parse(
        elements.map(
          (e) {
            final m = DTextMatchers.tagLink.pattern.firstMatch(e.text);
            return m == null
                ? UrlElement(
                    "$root${convertToLink(e.text)}",
                    e.text,
                  )
                : UrlElement(
                    "$root${convertToLink(m.namedGroup("tag") ?? m.namedGroup("main")!)}",
                    m.namedGroup("main") ?? m.namedGroup("tag"),
                  );
          },
        ).toList(),
        options);
  }
}

class NamedLinkifier extends UrlLinkifier {
  const NamedLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    return super.parse(
        elements
            .map(
              (e) => UrlElement(
                // This fails when using the static matcher. IDK why.
                // util.urlMatcher.hasMatch(e.text)
                RegExp(util.urlMatcherStr).hasMatch(e.text)
                    // ? util.urlMatcher.firstMatch(e.text)!.group(0)!
                    ? DTextMatchers.namedLink.pattern
                        .firstMatch(e.text)!
                        .group(2)!
                    : "https://e621.net"
                        "${DTextMatchers.namedLink.pattern.firstMatch(e.text)!.group(2)!}",
                // "https://e621.net/wiki_pages/show_or_new?title=${convertToLink(e.text)}",
                DTextMatchers.namedLink.pattern.firstMatch(e.text)!.group(1)!,
              ),
            )
            .toList(),
        options);
  }
}

// #endregion Linkifiers
const hexMatcher = "#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3}";
const hexParseMatcher =
    "#(?=[0-9a-fA-F])(?<r>[0-9a-fA-F]{1,2})(?<g>[0-9a-fA-F]{1,2})(?<b>[0-9a-fA-F]{1,2})";

enum DTextMatchers {
  // h1(r"h1\.(?<main>.*)$", TextStyle()),
  // h2(r"h2\.(?<main>.*)$", TextStyle()),
  // h3(r"h3\.(?<main>.*)$", TextStyle()),
  // h4(r"h4\.(?<main>.*)$", TextStyle()),
  // h5(r"h5\.(?<main>.*)$", TextStyle()),
  // h6(r"h6\.(?<main>.*)$", TextStyle()),
  header(r"h(?<param>[1-6])\.(?<main>.*)$", TextStyle()),
  section(
    r"\[section(?<data>(?<expanded>,expanded)?(?:=(?<title>.*?)))\](?<main>.*?)\[\/section\]",
    TextStyle(/* fontWeight: FontWeight.bold */),
  ),
  bold(r"\[b\](?<main>.*?)\[\/b\]", TextStyle(fontWeight: FontWeight.bold)),
  italics(r"\[i\](?<main>.*?)\[\/i\]", TextStyle(fontStyle: FontStyle.italic)),
  strikeThrough(r"\[s\](?<main>.*?)\[\/s\]",
      TextStyle(decoration: TextDecoration.lineThrough)),
  underline(r"\[u\](?<main>.*?)\[\/u\]",
      TextStyle(decoration: TextDecoration.underline)),
  spoiler(
      r"\[spoiler\](?<main>.*?)\[\/spoiler\]", TextStyle(color: Colors.grey)),
  // superscript(r"\[sup\](?<main>.*?)\[\/sup\]", TextStyle()),
  // subscript(r"\[sub\](?<main>.*?)\[\/sub\]", TextStyle()),
  tagLink(
      // r"\[\[(.*?)(?:\|(.+?)){0,1}\]\]",
      r"\[\[(?:(?<tag>.*?)\|){0,1}(?<main>.+?)\]\]",
      TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.amber,
        decoration: TextDecoration.underline,
      )),
  // color(r"\[color(?:=(?<color>.+?){0,1})\](?<main>.*?)\[\/color\]",
  color(
    r"\[color(?:=(?<param>(?<tagCategory>"
    "${TagCategory.categoryNameRegExpStr}"
    r")|(?<colorName>"
    "$htmlColorsFullMatcher"
    r")|(?<hex>"
    "$hexMatcher"
    r")|.*?){0,1})\](?<main>.*?)\[\/color\]",
    TextStyle(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
    ),
  ),
  code(
      r"\[code\](?<main>.*?)\[\/code\]",
      TextStyle(
        fontFamily: "Consolas",
        fontFamilyFallback: ["Courier New", "monospace"],
      )),
  codeInline(
      r"`(?<main>.*?)`",
      TextStyle(
        fontFamily: "Consolas",
        fontFamilyFallback: ["Courier New", "monospace"],
      )),
  namedLink(
      '"(?<main>.+?)":(?<url>${util.urlMatcherStr}){1}',
      TextStyle(
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      )),
  ;

  final String patternStr;
  final TextStyle style;
  RegExp get pattern => RegExp(patternStr, multiLine: true);
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

  TextStyle styleFromCtxAndMatch(BuildContext context, RegExpMatch m) =>
      switch (this) {
        header => switch (m.namedGroup("param")) {
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
        _ => style,
      };
  const DTextMatchers(this.patternStr, this.style);
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
    final style = ctx != null ? styleFromCtxAndMatch(ctx, m) : this.style;
    String? text = m.namedGroup("main"); //getSubPatternFromPotentialMatch(m);
    bool isChildless = this == DTextMatchers.tagLink ||
        this == DTextMatchers.namedLink ||
        firstMatches(text ?? "") == null;
    return this != DTextMatchers.tagLink
        ? this != DTextMatchers.namedLink
            ? this != DTextMatchers.section
                ? RegExp(util.urlMatcherStr).hasMatch(text ?? "")
                    ? LinkifySpan(
                        text: text!,
                        linkStyle: style,
                        onOpen: util.defaultOnLinkifyOpen,
                      )
                    : TextSpan(
                        text: isChildless ? text : null,
                        children:
                            isChildless ? null : buildChildrenFromMatch(m: m),
                        style: style,
                      )
                : WidgetSpan(
                    child: ExpansionTile(
                    visualDensity: VisualDensity.compact,
                    dense: true,
                    // controlAffinity: ListTileControlAffinity.leading,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    childrenPadding: EdgeInsets.zero,
                    title: IgnorePointer(
                      child: SelectableText(
                        m.namedGroup("title") ?? "",
                        style: style,
                      ),
                    ),
                    initiallyExpanded: m.namedGroup("expanded") != null,
                    children: [
                      Text.rich(TextSpan(
                        text: isChildless ? text : null,
                        children:
                            isChildless ? null : buildChildrenFromMatch(m: m),
                        style: style,
                      ))
                    ],
                  ))
            : LinkifySpan(
                text: m.group(0)!,
                linkifiers: const [NamedLinkifier()],
                linkStyle: style,
                onOpen: util.defaultOnLinkifyOpen,
              )
        : LinkifySpan(
            linkifiers: const [TagLinkifier()],
            text: /* text! */ m.group(0)!,
            linkStyle: style,
            onOpen: util.defaultOnLinkifyOpen,
          );
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

(RegExpMatch, DTextMatchers)? firstMatches(String dText) {
  (RegExpMatch, DTextMatchers)? m;
  int firstIndex = double.maxFinite.toInt();
  for (final r in DTextMatchers.values) {
    final mc = r.firstMatch(dText);
    if ((mc?.$1.start ?? firstIndex) < firstIndex) {
      m = mc;
      firstIndex = mc!.$1.start;
    }
  }

  return m;
}

List<InlineSpan> rawParse(String dText, [BuildContext? ctx]) {
  List<InlineSpan> parsed = [TextSpan(text: dText)];
  for (var i = 0, m = firstMatches(dText);
      m != null && i < safety;
      ++i, m = firstMatches(dText)) {
    final last = dText;
    final before = last.substring(0, m.$1.start);
    final after = last.substring(m.$1.end);
    final beforeUrlMatch = RegExp("(${util.urlMatcherStr})").firstMatch(before);
    parsed.removeLast();
    // parsed[parsed.length - 1] = beforeUrlMatch != null
    parsed.addAll(beforeUrlMatch != null
        ? [
            TextSpan(text: before.substring(0, beforeUrlMatch.start)),
            LinkifySpan(
                text: beforeUrlMatch.group(1)!,
                onOpen: util.defaultOnLinkifyOpen,
                linkStyle: util.defaultLinkStyle,
                options: const LinkifyOptions(looseUrl: true)),
            TextSpan(text: before.substring(beforeUrlMatch.end))
          ]
        : [TextSpan(text: before)]);
    parsed.add(m.$2.buildFromMatchRecursive(
      m: m.$1,
      // children: firstMatches(m.$1.group(1)!) != null
      //     ? rawParse(m.$1.group(1)!, ctx)
      //     : null,
      ctx: ctx,
    ));
    parsed.add(TextSpan(text: after));
    dText = after;
  }
  if (util.urlMatcher.hasMatch(dText)) {
    parsed[parsed.length - 1] = LinkifySpan(
      text: dText,
      onOpen: util.defaultOnLinkifyOpen,
      linkStyle: util.defaultLinkStyle,
    );
  }
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
/* 
TEST TEXT
h4.Hank Howell
[color=pink]I'm pink![/color]
[color=#ff0000]I'm red![/color]
[color=#f00]I'm red![/color]
[color=artist]I'm an artist![/color]
[section]Pretend this is a really large block of text.[/section]

[section=Some Title]This one has a title.[/section]

[section,expanded=Title]This is expanded by default.[/section]
patreon.com/MariArt
MariArt.info
[[American Dragon: Jake Long|Wiki Link]][[American Dragon: Jake Long]]
[b][COM] Helpful Personal Coach[/b]
Thank you "@/fluorinatedfur":https://x.com/fluorinatedfur for commissioning! ^^

Posted earlier on "Patreon":https://www.patreon.com/thekbear
Follow me on "Twitter":https://www.twitter.com/TheKinkBear */