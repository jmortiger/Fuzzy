import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/log_management.dart' as lm;

// ignore: unnecessary_late
late final _logger = lm.generateLogger("DTextFormatter").logger;

// https://e621.net/help/dtext

const tagLinkStyle = TextStyle(
    fontStyle: FontStyle.italic,
    color: Colors.amber,
    decoration: TextDecoration.underline);

const safety = 100;

// #region Linkifiers
class TagJsonLinkifier extends UrlLinkifier {
  const TagJsonLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    return super.parse(
        elements
            .map(
              (e) => UrlElement(
                "https://e621.net/wiki_pages.json?search%5Btitle%5D=${convertToLink(e.text)}",
                e.text,
              ),
            )
            .toList(),
        options);
  }
}

class TagLinkifier extends UrlLinkifier {
  const TagLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    return super.parse(
        elements
            .map(
              (e) => UrlElement(
                "https://e621.net/wiki_pages/show_or_new?title=${convertToLink(e.text)}",
                e.text,
              ),
            )
            .toList(),
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
  bold(r"\[b\](.*?)\[/b\]", TextStyle(fontWeight: FontWeight.bold)),
  italics(r"\[i\](.*?)\[/i\]", TextStyle(fontStyle: FontStyle.italic)),
  tagLink(
      r"\[\[(.*?)\]\]",
      TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.amber,
        decoration: TextDecoration.underline,
      )),
  strikeThrough(
      r"\[s\](.*?)\[/s\]", TextStyle(decoration: TextDecoration.lineThrough)),
  spoiler(r"\[spoiler\](.*?)\[/spoiler\]", TextStyle(color: Colors.grey)),
  namedLink(
      '"(.*?)":(${util.urlMatcherStr}){1}',
      TextStyle(
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      )),
  h1(r"h1\.(.*)$", TextStyle()),
  h2(r"h2\.(.*)$", TextStyle()),
  h3(r"h3\.(.*)$", TextStyle()),
  h4(r"h4\.(.*)$", TextStyle()),
  h5(r"h5\.(.*)$", TextStyle()),
  h6(r"h6\.(.*)$", TextStyle()),
  // superscript(r"\[sup\](.*?)\[/sup\]", TextStyle()),
  // subscript(r"\[sub\](.*?)\[/sub\]", TextStyle()),
  ;

  final String patternStr;
  final TextStyle style;
  RegExp get pattern => RegExp(patternStr, multiLine: true);
  TextStyle styleFromCtx(BuildContext context) => switch (this) {
        h1 => Theme.of(context).textTheme.headlineLarge ?? style,
        h2 => Theme.of(context).textTheme.headlineMedium ?? style,
        h3 => Theme.of(context).textTheme.headlineSmall ?? style,
        h4 => Theme.of(context).textTheme.labelLarge ?? style,
        h5 => Theme.of(context).textTheme.labelMedium ?? style,
        h6 => Theme.of(context).textTheme.labelSmall ?? style,
        _ => style,
      };
  // TextStyle styleFromDefault(BuildContext context) => switch (this) {
  //   bold || italics || tagLink || strikeThrough || spoiler || namedLink => style,
  //   h1 => Theme.of(context).textTheme.headlineLarge ?? style,
  //   h2 => Theme.of(context).textTheme.headlineMedium ?? style,
  //   h3 => Theme.of(context).textTheme.headlineSmall ?? style,
  //   h4 => Theme.of(context).textTheme.labelLarge ?? style,
  //   h5 => Theme.of(context).textTheme.labelMedium ?? style,
  //   h6 => Theme.of(context).textTheme.labelSmall ?? style,
  // };
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

  InlineSpan buildFromMatch(
      {RegExpMatch? m, List<InlineSpan>? children, BuildContext? ctx}) {
    final style = ctx != null ? styleFromCtx(ctx) : this.style;
    String? text = m?.group(1);
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
}

(RegExpMatch, DTextMatchers)? firstMatches(String dText) {
  (RegExpMatch, DTextMatchers)? m;
  for (var i = 0;
      i < DTextMatchers.values.length &&
          (m = DTextMatchers.values[i].firstMatch(dText)) == null;
      i++) {}

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
    parsed[parsed.length - 1] = util.urlMatcher.hasMatch(before)
        ? LinkifySpan(
            text: before,
            onOpen: util.defaultOnLinkifyOpen,
            linkStyle: util.defaultLinkStyle,
          )
        : TextSpan(text: before);
    parsed.add(m.$2.buildFromMatch(
      m: m.$1,
      children: firstMatches(m.$1.group(1)!) != null
          ? rawParse(m.$1.group(1)!, ctx)
          : null,
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
