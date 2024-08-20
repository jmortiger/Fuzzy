import 'package:flutter/material.dart';

/// Page indicator for desktop and web platforms.
///
/// On Desktop and Web, drag gesture for horizontal scrolling in a PageView is disabled by default.
/// You can defined a custom scroll behavior to activate drag gestures,
/// see https://docs.flutter.dev/release/breaking-changes/default-scroll-behavior-drag.
///
/// In this sample, we use a TabPageSelector to navigate between pages,
/// in order to build natural behavior similar to other desktop applications.
///
/// From [PageView docs][1].
///
/// [1]: https://api.flutter.dev/flutter/widgets/PageView-class.html#widgets.PageView.1
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.tabController,
    required this.currentPageIndex,
    required this.onUpdateCurrentPageIndex,
  });

  final int currentPageIndex;
  final TabController tabController;
  final void Function(int) onUpdateCurrentPageIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      // child: ListView (
      //   scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            splashRadius: 16.0,
            padding: EdgeInsets.zero,
            onPressed: () {
              if (currentPageIndex == 0) return;
              onUpdateCurrentPageIndex(currentPageIndex - 1);
            },
            icon: const Icon(
              Icons.arrow_left_rounded,
              size: 32.0,
            ),
          ),
          TabPageSelector(
            controller: tabController,
            color: colorScheme.surface,
            selectedColor: colorScheme.primary,
          ),
          IconButton(
            splashRadius: 16.0,
            padding: EdgeInsets.zero,
            onPressed: () {
              if (currentPageIndex == tabController.length - 1) return;
              onUpdateCurrentPageIndex(currentPageIndex + 1);
            },
            icon: const Icon(
              Icons.arrow_right_rounded,
              size: 32.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom page indicator & navigator.
///
/// Adapted from [PageView docs][1].
///
/// [1]: https://api.flutter.dev/flutter/widgets/PageView-class.html#widgets.PageView.1
class IndeterminatePageIndicator extends StatelessWidget {
  const IndeterminatePageIndicator({
    super.key,
    /* required  */ this.tabController,
    required this.currentPageIndex,
    required this.onUpdateCurrentPageIndex,
    required this.determineNextPage, // = _defaultNext,
    this.determinePriorPage = _defaultPrior,
    this.pageIndicator,
    this.isExpanded = true,
    this.padding = const EdgeInsets.all(8.0),
  }) : pageIndicatorBuilder = null;
  const IndeterminatePageIndicator.builder({
    super.key,
    /* required  */ this.tabController,
    required this.currentPageIndex,
    required this.onUpdateCurrentPageIndex,
    required this.determineNextPage, // = _defaultNext,
    this.determinePriorPage = _defaultPrior,
    this.pageIndicatorBuilder,
    this.isExpanded = true,
    this.padding = const EdgeInsets.all(8.0),
  }) : pageIndicator = null;

  // static int? _defaultNext(int currentPageIndex/* , TabController tabController */) =>
  //     (currentPageIndex == tabController.length - 1)
  //         ? null
  //         : currentPageIndex + 1;
  static int? _defaultPrior(
          int currentPageIndex /* , TabController tabController */) =>
      (currentPageIndex == 0) ? null : currentPageIndex - 1;

  final int currentPageIndex;
  final TabController? tabController;
  final void Function(int newPageIndex, int oldPageIndex)
      onUpdateCurrentPageIndex;
  final int? Function(int currentPageIndex /* , TabController controller */)?
      determineNextPage;
  final int? Function(int currentPageIndex /* , TabController controller */)?
      determinePriorPage;
  final Widget? Function(BuildContext cxt, int currentPageIndex)?
      pageIndicatorBuilder;
  final Widget? pageIndicator;
  final bool isExpanded;
  final EdgeInsetsGeometry? padding;

  Widget? _getPageIndicator(BuildContext cxt, int currentPageIndex) =>
      pageIndicator ?? pageIndicatorBuilder?.call(cxt, currentPageIndex);

  @override
  Widget build(BuildContext context) {
    final int? priorIndex =
            determinePriorPage?.call(currentPageIndex /* , tabController */),
        nextIndex =
            determineNextPage?.call(currentPageIndex /* , tabController */);
    Widget? indicator = _getPageIndicator(context, currentPageIndex);
    if (isExpanded && indicator != null) indicator = Expanded(child: indicator);
    // final root = ListView (
    //   scrollDirection: Axis.horizontal,
    final root = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          splashRadius: 16.0,
          padding: EdgeInsets.zero,
          onPressed: priorIndex != null
              ? () => onUpdateCurrentPageIndex(priorIndex, currentPageIndex)
              : null,
          icon: const Icon(
            Icons.arrow_left_rounded,
            size: 32.0,
          ),
        ),
        if (indicator != null) indicator,
        IconButton(
          splashRadius: 16.0,
          padding: EdgeInsets.zero,
          onPressed: nextIndex != null
              ? () => onUpdateCurrentPageIndex(nextIndex, currentPageIndex)
              : null,
          icon: const Icon(
            Icons.arrow_right_rounded,
            size: 32.0,
          ),
        ),
      ],
    );
    return padding != null
        ? Padding(
            padding: padding!,
            child: root,
          )
        : root;
  }
}
