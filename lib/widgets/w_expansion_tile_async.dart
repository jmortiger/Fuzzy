import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;

// typedef Builder = FutureOr<List<FutureOr<Widget>>> Function();
typedef Builder = FutureOr<List<FutureOr<Widget>>> Function(
    BuildContext context, void Function(void Function()) setState);

/// TODO: Migrate to package.
/// TODO: Add option to show completed children while loading other children.
class WExpansionTileAsync extends StatefulWidget {
  final Widget title;
  final bool initiallyExpanded;
  final bool maintainState;
  final bool? enableFeedback;
  final bool enabled;
  final Widget? leading;
  final Widget? subtitle;
  final void Function(bool)? onExpansionChanged;
  final Widget? trailing;
  final EdgeInsetsGeometry? tilePadding;
  final CrossAxisAlignment? expandedCrossAxisAlignment;
  final Alignment? expandedAlignment;
  final EdgeInsetsGeometry? childrenPadding;
  final Color? backgroundColor;
  final Color? collapsedBackgroundColor;
  final Color? textColor;
  final Color? collapsedTextColor;
  final Color? iconColor;
  final Color? collapsedIconColor;
  final ShapeBorder? shape;
  final ShapeBorder? collapsedShape;
  final Clip? clipBehavior;
  final ListTileControlAffinity? controlAffinity;
  final ExpansionTileController? controller;
  final bool? dense;
  final VisualDensity? visualDensity;
  final double? minTileHeight;
  final AnimationStyle? expansionAnimationStyle;

  final Builder? childrenBuilder;
  final FutureOr<List<FutureOr<Widget>>>? children;
  const WExpansionTileAsync.direct({
    super.key,
    required this.title,
    FutureOr<List<FutureOr<Widget>>> this.children = const <Widget>[],
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.enableFeedback = true,
    this.enabled = true,
    this.leading,
    this.subtitle,
    this.onExpansionChanged,
    this.trailing,
    this.tilePadding,
    this.expandedCrossAxisAlignment,
    this.expandedAlignment,
    this.childrenPadding,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.textColor,
    this.collapsedTextColor,
    this.iconColor,
    this.collapsedIconColor,
    this.shape,
    this.collapsedShape,
    this.clipBehavior,
    this.controlAffinity,
    this.controller,
    this.dense,
    this.visualDensity,
    this.minTileHeight,
    this.expansionAnimationStyle,
  }) : childrenBuilder = null;
  const WExpansionTileAsync.withCallback({
    super.key,
    required this.title,
    required Builder this.childrenBuilder,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.enableFeedback = true,
    this.enabled = true,
    this.leading,
    this.subtitle,
    this.onExpansionChanged,
    this.trailing,
    this.tilePadding,
    this.expandedCrossAxisAlignment,
    this.expandedAlignment,
    this.childrenPadding,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.textColor,
    this.collapsedTextColor,
    this.iconColor,
    this.collapsedIconColor,
    this.shape,
    this.collapsedShape,
    this.clipBehavior,
    this.controlAffinity,
    this.controller,
    this.dense,
    this.visualDensity,
    this.minTileHeight,
    this.expansionAnimationStyle,
  }) : children = null;

  @override
  State<WExpansionTileAsync> createState() => _WExpansionTileAsyncState();
}

class _WExpansionTileAsyncState extends State<WExpansionTileAsync> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WExpansionTileAsync");
  // #endregion Logger
  bool hasChildren = false;
  late List<Widget> children;
  late Future<List<Widget>>? future;
  List<Widget> _onError(Object e, StackTrace s) {
    logger.severe(e, e, s);
    return const <Widget>[];
  }

  void _onFutureComplete(List<Widget> v) {
    setState(() {
      children = v;
      future = null;
      hasChildren = true;
    });
  }

  @override
  void initState() {
    super.initState();
    switch (widget.children) {
      case List<Widget> c:
        children = c;
        future = null;
        hasChildren = true;
        break;
      case Future<List<Widget>> c:
        future = c.onError(_onError)..then(_onFutureComplete).ignore();
        break;
      case List<Future<Widget>> c:
        future = Future.wait(c).onError(_onError)
          ..then(_onFutureComplete).ignore();
        break;
      case Future<List<Future<Widget>>> c:
        future = c.then((v) => Future.wait(v)).onError(_onError)
          ..then(_onFutureComplete).ignore();
        break;
      case List<FutureOr<Widget>> c:
        final f = List.generate(
            c.length,
            (i) => c[i] is Future<Widget>
                ? c[i] as Future<Widget>
                : Future.sync(() => c[i]));
        future = Future.wait(f).onError(_onError)
          ..then(_onFutureComplete).ignore();
        break;
      case Future<List<FutureOr<Widget>>> v:
        future = v.then((c) {
          final f = List.generate(
              c.length,
              (i) => c[i] is Future<Widget>
                  ? c[i] as Future<Widget>
                  : Future.sync(() => c[i]));
          return Future.wait(f).onError(_onError);
        })
          ..then(_onFutureComplete).ignore();
        break;
      case null:
        switch (widget.childrenBuilder!(context, setState)) {
          case List<Widget> c:
            children = c;
            future = null;
            hasChildren = true;
            break;
          case Future<List<Widget>> c:
            future = c.onError(_onError)..then(_onFutureComplete).ignore();
            break;
          case List<Future<Widget>> c:
            future = Future.wait(c).onError(_onError)
              ..then(_onFutureComplete).ignore();
            break;
          case Future<List<Future<Widget>>> c:
            future = c.then((v) => Future.wait(v)).onError(_onError)
              ..then(_onFutureComplete).ignore();
            break;
          case List<FutureOr<Widget>> c:
            final f = List.generate(
                c.length,
                (i) => c[i] is Future<Widget>
                    ? c[i] as Future<Widget>
                    : Future.sync(() => c[i]));
            future = Future.wait(f).onError(_onError)
              ..then(_onFutureComplete).ignore();
            break;
          case Future<List<FutureOr<Widget>>> v:
            future = v.then((c) {
              final f = List.generate(
                  c.length,
                  (i) => c[i] is Future<Widget>
                      ? c[i] as Future<Widget>
                      : Future.sync(() => c[i]));
              return Future.wait(f).onError(_onError);
            })
              ..then(_onFutureComplete).ignore();
            break;
        }
        break;
    }
  }

  @override
  void dispose() {
    future?.ignore();
    future = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logger.info("Building");
    final et = ExpansionTile(
      title: widget.title,
      backgroundColor: widget.backgroundColor,
      childrenPadding: widget.childrenPadding,
      clipBehavior: widget.clipBehavior,
      collapsedBackgroundColor: widget.collapsedBackgroundColor,
      collapsedIconColor: widget.collapsedIconColor,
      collapsedShape: widget.collapsedShape,
      collapsedTextColor: widget.collapsedTextColor,
      controlAffinity: widget.controlAffinity,
      controller: widget.controller,
      dense: widget.dense,
      enableFeedback: widget.enableFeedback,
      enabled: widget.enabled,
      expandedAlignment: widget.expandedAlignment,
      expandedCrossAxisAlignment: widget.expandedCrossAxisAlignment,
      expansionAnimationStyle: widget.expansionAnimationStyle,
      iconColor: widget.iconColor,
      initiallyExpanded: widget.initiallyExpanded,
      leading: widget.leading,
      maintainState: widget.maintainState,
      minTileHeight: widget.minTileHeight,
      onExpansionChanged: widget.onExpansionChanged,
      shape: widget.shape,
      subtitle: widget.subtitle,
      textColor: widget.textColor,
      tilePadding: widget.tilePadding,
      trailing: widget.trailing,
      visualDensity: widget.visualDensity,
      children: /* future != null */
          !hasChildren ? [const CircularProgressIndicator()] : children,
    );
    return hasChildren && future != null
        ? Stack(
            children: [
              et,
              const Positioned.fill(child: CircularProgressIndicator())
            ],
          )
        : et;
  }
}
