import 'package:e621/e621_api.dart' as e621;
import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/util/util.dart' as util;

/// TODO: Replace gesture detector w/ inkwell for hover anim?
class UserIdentifier extends StatelessWidget {
  final int id;

  /// The user name
  final String? name;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  const UserIdentifier({
    super.key,
    required this.id,
    this.name,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: "Open User #$id",
        child: GestureDetector(
          onTap: () => util.defaultTryLaunchE6Url(
              context: context, url: e621.baseUri.replace(path: "users/$id")),
          child: Text(
            name ?? "#$id",
            style: style,
            strutStyle: strutStyle,
            textAlign: textAlign,
            textDirection: textDirection,
            locale: locale,
            softWrap: softWrap,
            overflow: overflow,
            textScaler: textScaler,
            maxLines: maxLines,
            semanticsLabel: semanticsLabel,
            textWidthBasis: textWidthBasis,
            textHeightBehavior: textHeightBehavior,
            selectionColor: selectionColor,
          ),
        ),
      );
}

class TextLauncher extends StatelessWidget {
  static void Function(BuildContext context) makeLaunchSearchOnTap(
          String searchString,
          {int? limit,
          String? page}) =>
      (context) => Navigator.pushNamed(context,
          "/posts?tags=$searchString${limit != null ? "&limit=$limit" : ""}${page != null ? "&page=$page" : ""}",
          arguments: RouteParameterResolver(parameters: {
            "tags": [searchString],
            if (limit != null) "limit": ["$limit"],
            if (page != null) "page": [page]
          }));
  final String text;
  final void Function(BuildContext context) onTap;
  final String? tooltip;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  const TextLauncher({
    super.key,
    required this.text,
    required this.onTap,
    this.tooltip,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    var gestureDetector = GestureDetector(
      onTap: () => onTap(context),
      child: Text(
        text,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      ),
    );
    return tooltip != null
        ? Tooltip(
            message: tooltip,
            child: gestureDetector,
          )
        : gestureDetector;
  }
}
