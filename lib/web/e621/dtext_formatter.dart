import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/log_management.dart' as lm;

// ignore: unnecessary_late
late final  _logger = lm.generateLogger("DTextFormatter").logger;

// https://e621.net/help/dtext

const boldStyle = TextStyle(fontWeight: FontWeight.bold);
// ignore: unnecessary_late
late final boldPattern = RegExp(boldPatternStr);
const boldPatternStr = r"\[b\](.*?)\[/b\]";
const italicsStyle = TextStyle(fontStyle: FontStyle.italic);
// ignore: unnecessary_late
late final italicsPattern = RegExp(italicsPatternStr);
const italicsPatternStr = r"\[i\](.*?)\[/i\]";
const tagLinkStyle =
    TextStyle(fontStyle: FontStyle.italic, color: Colors.amber);
// ignore: unnecessary_late
late final tagLinkPattern = RegExp(tagLinkPatternStr);
const tagLinkPatternStr = r"\[\[(.*?)\]\]";
const strikeThroughStyle = TextStyle(decoration: TextDecoration.lineThrough);
// ignore: unnecessary_late
late final strikeThroughPattern = RegExp(strikeThroughPatternStr);
const strikeThroughPatternStr = r"\[s\](.*?)\[/s\]";
const spoilerStyle = TextStyle(color: Colors.grey);
// ignore: unnecessary_late
late final spoilerPattern = RegExp(spoilerPatternStr);
const spoilerPatternStr = r"\[spoiler\](.*?)\[/spoiler\]";
const namedLinkStyle = TextStyle(color: Colors.grey);
// ignore: unnecessary_late
late final namedLinkPattern = RegExp(namedLinkPatternStr);
const namedLinkPatternStr = r'"(.*?)":(.*?)';

// const superscriptStyle = TextStyle();
// // ignore: unnecessary_late
// late final superscriptPattern = RegExp(superscriptPatternStr);
// const superscriptPatternStr = r"\[sup\](.*?)\[/sup\]";
// const subscriptStyle = TextStyle();
// // ignore: unnecessary_late
// late final subscriptPattern = RegExp(subscriptPatternStr);
// const subscriptPatternStr = r"\[sub\](.*?)\[/sub\]";

const safety = 100;

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
// class NamedLinkifier extends UrlLinkifier {
//   const NamedLinkifier();
//   @override
//   List<LinkifyElement> parse(
//       List<LinkifyElement> elements, LinkifyOptions options) {
//     return super.parse(
//         elements
//             .map(
//               (e) => UrlElement(
//                 "https://e621.net/wiki_pages/show_or_new?title=${convertToLink(e.text)}",
//                 e.text,
//               ),
//             )
//             .toList(),
//         options);
//   }
// }

enum DTextMatchers {
  bold(boldPatternStr, boldStyle),
  italics(italicsPatternStr, italicsStyle),
  tagLink(tagLinkPatternStr, tagLinkStyle),
  strikeThrough(strikeThroughPatternStr, strikeThroughStyle),
  spoiler(spoilerPatternStr, spoilerStyle),
  // namedLink(namedLinkPatternStr, namedLinkStyle),
  ;

  final String patternStr;
  final TextStyle style;
  RegExp get pattern => RegExp(patternStr);
  const DTextMatchers(this.patternStr, this.style);
  (RegExpMatch, DTextMatchers)? firstMatch(String dText) {
    final m = pattern.firstMatch(dText);
    return m == null ? null : (m, this);
  }

  // (RegExpMatch, String subPattern, DTextMatchers)? firstMatchWithString(
  //     String dText) {
  //   final m = pattern.firstMatch(dText);
  //   return m == null
  //       ? null
  //       : (m, (this != namedLink ? m.group(1) : m.group(2))!, this);
  // }

  InlineSpan build({String? text, List<InlineSpan>? children}) {
    _logger.info(RegExp(util.urlMatcherStr).hasMatch(text ?? ""));
    return this != DTextMatchers.tagLink// && this != DTextMatchers.namedLink
        ? RegExp(util.urlMatcherStr).hasMatch(text ?? "")
            ? LinkifySpan(
                text: text!,
                linkStyle: style,
                onOpen: util.defaultOnLinkifyOpen,
              )
            : TextSpan(text: text, children: children, style: style)
        : WidgetSpan(
            child: SelectableLinkify(
            linkifiers: const [TagLinkifier()],
            text: text!,
            linkStyle: style,
            onOpen: util.defaultOnLinkifyOpen,
          ));
  }

  // InlineSpan buildFromMatch({RegExpMatch? m, List<InlineSpan>? children}) {
  //   String? text = this != namedLink ? m?.group(1) : m?.group(2);
  //   return this != DTextMatchers.tagLink
  //       ? RegExp(util.urlMatcherStr).hasMatch(text ?? "")
  //           ? LinkifySpan(
  //               text: text!,
  //               linkStyle: style,
  //               onOpen: util.defaultOnLinkifyOpen,
  //             )
  //           : TextSpan(text: text, children: children, style: style)
  //       : WidgetSpan(
  //           child: SelectableLinkify(
  //           linkifiers: const [TagLinkifier()],
  //           text: text!,
  //           linkStyle: style,
  //           onOpen: util.defaultOnLinkifyOpen,
  //         ));
  // }
}

(RegExpMatch, DTextMatchers)? firstMatches(String dText) {
  (RegExpMatch, DTextMatchers)? m;
  for (var i = 0;
      i < DTextMatchers.values.length &&
          (m = DTextMatchers.values[i].firstMatch(dText)) == null;
      i++) {}

  return m;
}

// (RegExpMatch, String, DTextMatchers)? firstMatchesWithString(String dText) {
//   (RegExpMatch, String, DTextMatchers)? m;
//   for (var i = 0;
//       i < DTextMatchers.values.length &&
//           (m = DTextMatchers.values[i].firstMatchWithString(dText)) == null;
//       i++) {}

//   return m;
// }

List<InlineSpan> rawParse(String dText) {
  if (util.urlMatcher.hasMatch(dText)) {
    return [
      LinkifySpan(
        text: dText,
        onOpen: util.defaultOnLinkifyOpen,
        linkStyle: tagLinkStyle,
      )
    ];
  }
  List<InlineSpan> parsed = [TextSpan(text: dText)];
  for (var i = 0, m = firstMatches(dText);
      m != null && i < safety;
      ++i, m = firstMatches(dText)) {
    final last = dText;
    final before = last.substring(0, m.$1.start);
    final after = last.substring(m.$1.end);
    parsed[parsed.length - 1] = TextSpan(text: before);
    parsed.add(firstMatches(m.$1.group(1)!) != null
        // ? TextSpan(children: rawParse(m.$1.group(1)!), style: m.$2.style)
        ? m.$2.build(children: rawParse(m.$1.group(1)!))
        : m.$2.build(text: m.$1.group(1)!));
    parsed.add(TextSpan(text: after));
    dText = after;
  }
  return parsed;
}

/// Recurses
///
/// https://e621.net/help/dtext
InlineSpan parse(String dText) {
  return TextSpan(children: rawParse(dText));
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
