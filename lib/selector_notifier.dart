/* import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;

typedef Builder<S> = Widget Function(
    BuildContext context, S value, Widget? child);
typedef ShouldRebuild<S> = bool Function(S prior, S curr);

/// https://pub.dev/documentation/provider/latest/provider/Selector-class.html
class SelectorNotifier0<S> extends StatefulWidget {
  final S Function(BuildContext context) selector;
  final Builder<S> builder;
  final ShouldRebuild<S> shouldRebuild;
  final Widget? child;
  const SelectorNotifier0({
    super.key,
    required this.selector,
    required this.builder,
    ShouldRebuild<S>? shouldRebuild,
    this.child,
  })  : shouldRebuild = shouldRebuild ?? defaultShouldRebuild;
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}

  static bool defaultShouldRebuild<S>(S prior, S current) =>
      !const DeepCollectionEquality().equals(prior, current);

  @override
  State<SelectorNotifier0<S>> createState() => _SelectorNotifier0State<S>();
}

class SelectorNotifier<N extends ChangeNotifier, S>
    extends SelectorNotifier0<S> {
  final N value;
  SelectorNotifier({
    super.key,
    required S Function(BuildContext context, N value) selector,
    required super.builder,
    super.shouldRebuild,
    super.child,
    required this.value,
  }) : super(selector: ((BuildContext context) => selector(context, value)));
  @override
  void addListener(void Function() listener) => value.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      value.removeListener(listener);

  @override
  State<SelectorNotifier0<S>> createState() => _SelectorNotifier0State<S>();
}

class _SelectorNotifier0State<S> extends State<SelectorNotifier0<S>> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("NotifierSelector");
  // #endregion Logger
  late S currSelection;
  @override
  void initState() {
    super.initState();
    widget.addListener(onChange);
    // currSelection = widget.selector(context/* , value */);
  }

  @override
  void dispose() {
    widget.removeListener(onChange);
    super.dispose();
  }

  void onChange() {
    final n = widget.selector(context /* , value */);
    if (widget.shouldRebuild(currSelection, n)) {
      setState(() {
        currSelection = n;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // currSelection = widget.selector(context/* , value */);
    try {
      return widget.builder(context, currSelection, widget.child);
    } catch (e) {
      currSelection = widget.selector(context /* , value */);
      return widget.builder(context, currSelection, widget.child);
    }
  }
}
 */
