import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/util/util.dart' as util;
// import 'package:fuzzy/log_management.dart' as lm;

// // ignore: unnecessary_late
// late final _logger = lm.generateLogger("DTextFormatter").logger;

// https://e621.net/help/dtext

const tagLinkStyle = TextStyle(
    fontStyle: FontStyle.italic,
    color: Colors.amber,
    decoration: TextDecoration.underline);

const safety = 100;

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
                : m.group(2) == null
                    ? UrlElement(
                        "$root${convertToLink(m.group(1)!)}",
                        m.group(1)!,
                      )
                    : UrlElement(
                        "$root${convertToLink(m.group(2)!)}",
                        m.group(2)!,
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
                    "$root${convertToLink(m.group(1)!)}",
                    m.group(2) == null ? m.group(1)! : m.group(2)!,
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

enum DTextMatchers {
  h1(r"h1\.(.*)$", TextStyle()),
  h2(r"h2\.(.*)$", TextStyle()),
  h3(r"h3\.(.*)$", TextStyle()),
  h4(r"h4\.(.*)$", TextStyle()),
  h5(r"h5\.(.*)$", TextStyle()),
  h6(r"h6\.(.*)$", TextStyle()),
  // header(r"h([1-6])\.(.*)$", TextStyle()),
  bold(r"\[b\](.*?)\[/b\]", TextStyle(fontWeight: FontWeight.bold)),
  italics(r"\[i\](.*?)\[/i\]", TextStyle(fontStyle: FontStyle.italic)),
  strikeThrough(
      r"\[s\](.*?)\[/s\]", TextStyle(decoration: TextDecoration.lineThrough)),
  spoiler(r"\[spoiler\](.*?)\[/spoiler\]", TextStyle(color: Colors.grey)),
  // superscript(r"\[sup\](.*?)\[/sup\]", TextStyle()),
  // subscript(r"\[sub\](.*?)\[/sub\]", TextStyle()),
  tagLink(
      r"\[\[(.*?)(?:\|(.+?)){0,1}\]\]",
      TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.amber,
        decoration: TextDecoration.underline,
      )),
  code(
      r"\[code\](.*?)\[/code\]",
      TextStyle(
        fontFamily: "Consolas",
        fontFamilyFallback: ["Courier New", "monospace"],
      )),
  namedLink(
      '"(.*?)":(${util.urlMatcherStr}){1}',
      TextStyle(
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      )),
  ;

  final String patternStr;
  final TextStyle style;
  RegExp get pattern => RegExp(patternStr, multiLine: true);
  TextStyle styleFromCtx(BuildContext context) => switch (this) {
        h1 =>
          Theme.of(context).textTheme.displayLarge /* headlineLarge */ ?? style,
        h2 => Theme.of(context).textTheme.displayMedium /* headlineMedium */ ??
            style,
        h3 =>
          Theme.of(context).textTheme.displaySmall /* headlineSmall */ ?? style,
        h4 =>
          Theme.of(context).textTheme.headlineLarge /* labelLarge */ ?? style,
        h5 =>
          Theme.of(context).textTheme.headlineMedium /* labelMedium */ ?? style,
        h6 =>
          Theme.of(context).textTheme.headlineSmall /* labelSmall */ ?? style,
        _ => style,
      };
  const DTextMatchers(this.patternStr, this.style);
  (RegExpMatch, DTextMatchers)? firstMatch(String dText) {
    final m = pattern.firstMatch(dText);
    return m == null ? null : (m, this);
  }

  // (RegExpMatch, DTextMatchers, bool couldHaveSubMatches)? firstMatchCheck(String dText) {
  //   final m = pattern.firstMatch(dText);
  //   return m == null ? null : (m, this);
  // }

  (RegExpMatch, String subPattern, DTextMatchers)? firstMatchWithString(
      String dText) {
    final m = pattern.firstMatch(dText);
    return m == null ? null : (m, m.group(1)!, this);
  }

  /* InlineSpan build(
      {String? text, List<InlineSpan>? children, BuildContext? ctx}) {
    final style = ctx != null ? styleFromCtx(ctx) : this.style;
    _logger.info(util.urlMatcherStrict.hasMatch(text ?? ""));
    return this != DTextMatchers.tagLink
        ? util.urlMatcherStrict.hasMatch(text ?? "")
            ? LinkifySpan(
                text: text!,
                linkStyle: style,
                onOpen: util.defaultOnLinkifyOpen,
              )
            : TextSpan(text: text, children: children, style: style)
        : WidgetSpan(
            child: Linkify(
            linkifiers: const [TagLinkifier()],
            text: text!,
            linkStyle: style,
            onOpen: util.defaultOnLinkifyOpen,
          ));
  } */

  InlineSpan _buildFromMatch({
    RegExpMatch? m,
    List<InlineSpan>? children,
    BuildContext? ctx,
  }) {
    final style = ctx != null ? styleFromCtx(ctx) : this.style;
    String? text = getSubPatternFromPotentialMatch(m);
    return this != DTextMatchers.tagLink
        ? this != DTextMatchers.namedLink
            ? RegExp(util.urlMatcherStr).hasMatch(text ?? "")
                ? LinkifySpan(
                    text: text!,
                    linkStyle: style,
                    onOpen: util.defaultOnLinkifyOpen,
                  )
                : TextSpan(text: text, children: children, style: style)
            : LinkifySpan(
                text: m!.group(0)!,
                linkifiers: const [NamedLinkifier()],
                linkStyle: style,
                onOpen: util.defaultOnLinkifyOpen,
              )
        : WidgetSpan(
            child: Linkify(
            linkifiers: const [TagLinkifier()],
            text: text!,
            linkStyle: style,
            onOpen: util.defaultOnLinkifyOpen,
          ));
  }

  InlineSpan buildFromMatchRecursive({
    required RegExpMatch m,
    BuildContext? ctx,
  }) {
    final style = ctx != null ? styleFromCtx(ctx) : this.style;
    String? text = getSubPatternFromPotentialMatch(m);
    bool isChildless = firstMatches(text ?? "") == null;
    return this != DTextMatchers.tagLink
        ? this != DTextMatchers.namedLink
            ? RegExp(util.urlMatcherStr).hasMatch(text ?? "")
                ? LinkifySpan(
                    text: text!,
                    linkStyle: style,
                    onOpen: util.defaultOnLinkifyOpen,
                  )
                : TextSpan(
                    text: isChildless ? text : null,
                    children: isChildless ? null : buildChildrenFromMatch(m: m),
                    style: style,
                  )
            : LinkifySpan(
                text: m.group(0)!,
                linkifiers: const [NamedLinkifier()],
                linkStyle: style,
                onOpen: util.defaultOnLinkifyOpen,
              )
        : WidgetSpan(
            child: Linkify(
            linkifiers: const [TagLinkifier()],
            text: /* text! */ m.group(0)!,
            linkStyle: style,
            onOpen: util.defaultOnLinkifyOpen,
          ));
  }

  String? getSubPatternFromPotentialMatch(RegExpMatch? m) =>
      this != tagLink || (m?.group(2)?.isEmpty ?? true)
          ? m?.group(1)
          : m?.group(2);
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
// (RegExpMatch, DTextMatchers)? firstMatches(String dText) {
//   (RegExpMatch, DTextMatchers)? m;
//   for (var i = 0;
//       i < DTextMatchers.values.length &&
//           (m = DTextMatchers.values[i].firstMatch(dText)) == null;
//       i++) {}

//   return m;
// }

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
  } catch (e) {
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
Map<String, Color> htmlColors = {
  "white": const Color(0xFFFFFFFF),
  "silver": const Color(0xFFC0C0C0),
  "gray": const Color(0xFF808080),
  "black": const Color(0xFF000000),
  "red": const Color(0xFFFF0000),
  "maroon": const Color(0xFF800000),
  "yellow": const Color(0xFFFFFF00),
  "olive": const Color(0xFF808000),
  "lime": const Color(0xFF00FF00),
  "green": const Color(0xFF008000),
  "aqua": const Color(0xFF00FFFF),
  "teal": const Color(0xFF008080),
  "blue": const Color(0xFF0000FF),
  "navy": const Color(0xFF000080),
  "fuchsia": const Color(0xFFFF00FF),
  "purple": const Color(0xFF800080),
};
/* 
TEST TEXT
h4.Hank Howell
Felt inspired to draw some Hank Howell. 
--
🎨 Early access, hi-res & exclusive content like comics on Patreon.
patreon.com/MariArt
MariArt.info
[[American Dragon: Jake Long|Wiki Link]][[American Dragon: Jake Long]]
[b][COM] Helpful Personal Coach[/b]
Thank you "@/fluorinatedfur":https://x.com/fluorinatedfur for commissioning! ^^
------------

Posted earlier on "Patreon":https://www.patreon.com/thekbear
Follow me on "Twitter":https://www.twitter.com/TheKinkBear */