import 'dart:async' show FutureOr, Zone;
import 'dart:convert' as dc;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:fuzzy/main.dart';
import 'package:j_util/j_util_full.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:url_launcher/url_launcher.dart';

// #region Logger
lm.Printer get _print => _lRecord.print;
lm.FileLogger get _logger => _lRecord.logger;
// ignore: unnecessary_late
late final _lRecord = lm.generateLogger("Util");
// #endregion Logger

typedef JsonMap = Map<String, dynamic>;
const isDebug = kDebugMode;
final LazyInitializer<PackageInfo> packageInfo = LazyInitializer(
  () => PackageInfo.fromPlatform(),
);
final LazyInitializer<String> version = LazyInitializer(
  () async => (await packageInfo.getItem()).version,
  defaultValue: "VERSION_NUMBER",
);

/// The absolute path to user-accessible data.
final appDataPath = LazyInitializer(() => (Platform.isWeb)
    ? Future.sync(() => "")
    : path.getDownloadsDirectory /* getApplicationDocumentsDirectory */ ().then(
          (value) => value!.absolute.path,
        ));
final devDataString = LazyInitializer<String>(() =>
    (rootBundle.loadString("assets/devData.json")
      ..onError(defaultOnError /* onErrorPrintAndRethrow */)));
final devData = LazyInitializer<JsonMap>(
    () async => dc.jsonDecode(await devDataString.getItem()));
final pref =
    LazyInitializer<SharedPreferences>(() => SharedPreferences.getInstance());
FutureOr<T> onErrorPrintAndRethrow<T>(Object? e, StackTrace stackTrace) {
  _print(e);
  _print(stackTrace);
  throw e!;
}

T defaultOnError<T>(Object? error, StackTrace trace) {
  _print(error);
  return _print(trace) as T;
}

// #region User Message
const useSnackbar = true;

/// Checks if mounted
ScaffoldFeatureController? showUserMessage({
  required BuildContext context,
  required Widget content,
  bool autoHidePrior = true,
  Duration? duration = const Duration(seconds: 2),
  (String label, VoidCallback onTap)? action,
  List<(String label, VoidCallback onTap)>? actions,
  bool addDismissOption = true,
}) =>
    context.mounted
        ? (useSnackbar ? _showUserMessageSnackbar : _showUserMessageBanner)(
            context: context,
            content: content,
            action: action,
            actions: actions,
            autoHidePrior: autoHidePrior,
            duration: duration,
            addDismissOption: addDismissOption,
          )
        : null;

ScaffoldFeatureController _showUserMessageSnackbar({
  required BuildContext context,
  required Widget content,
  bool autoHidePrior = true,
  Duration? duration = const Duration(seconds: 2),
  (String label, VoidCallback onTap)? action,
  List<(String label, VoidCallback onTap)>? actions,
  bool addDismissOption = true,
}) {
  final message = SnackBar(
        content: content,
        duration: duration ?? const Duration(seconds: 4),
        action: _makeSnackBarAction(action, actions),
      ),
      sm = ScaffoldMessenger.of(context);
  if (autoHidePrior) sm.hideCurrentSnackBar();
  return sm.showSnackBar(message);
}

SnackBarAction? _makeSnackBarAction((String label, VoidCallback onTap)? action,
    List<(String label, VoidCallback onTap)>? actions) {
  return (action ?? actions?.firstOrNull) != null
      ? SnackBarAction(
          label: action?.$1 ?? actions!.first.$1,
          onPressed: action?.$2 ?? actions!.first.$2)
      : null;
}

ScaffoldFeatureController _showUserMessageBanner({
  required BuildContext context,
  required Widget content,
  bool autoHidePrior = true,
  Duration? duration = const Duration(seconds: 2),
  (String label, VoidCallback onTap)? action,
  List<(String label, VoidCallback onTap)>? actions,
  bool addDismissOption = true,
}) {
  final message = MaterialBanner(
        content: content,
        actions: _makeBannerAction(action, actions, addDismissOption),
      ),
      sm = ScaffoldMessenger.of(context);
  if (autoHidePrior) sm.hideCurrentMaterialBanner();
  if (duration == null) return sm.showMaterialBanner(message);
  final ret = sm.showMaterialBanner(message);
  Future.delayed(duration, () => ret.close()).ignore();
  return ret;
}

List<Widget> _makeBannerAction(
  (String label, VoidCallback onTap)? action,
  List<(String label, VoidCallback onTap)>? actions, [
  bool addDismissOption = true,
]) {
  Widget make((String label, VoidCallback onTap) action) => TextButton.icon(
        label: Text(action.$1),
        onPressed: action.$2,
      );
  return [
    if (addDismissOption ||
        (action ?? actions) == null ||
        (action == null && actions!.isEmpty))
      TextButton.icon(label: const Text("Ok"), onPressed: () {}),
    if (action != null) make(action),
    if (actions != null) ...actions.map(make)
  ];
}
// #endregion User Message

VoidCallback generateAlertDialog<DialogOutput>(
  BuildContext context, {
  Widget? content,
  List<Widget>? actions,
  FutureOr<void> Function(DialogOutput? value)? onOutputCallback,
}) {
  return () {
    var t = showDialog<DialogOutput>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: content,
          actions: actions,
        );
      },
    );
    if (onOutputCallback != null) {
      t.then<void>(onOutputCallback);
    }
  };
}

dynamic colorToJson(Color c) => c.value;
Color colorFromJson(json) => Color(json as int);

/// For easy chaining
extension StringPrint on String {
  /// For easy chaining
  String printMe({
    lm.LogLevel level = lm.LogLevel.FINEST,
    Object? error,
    StackTrace? stackTrace,
    Zone? zone,
    lm.FileLogger? logger,
  }) {
    (logger ?? _logger).log(level, this, error, stackTrace, zone);
    return this;
  }
}

// #region TextInputFormatter
RegExp get nonNumeric => RegExp(r'[^0-9]');
// final nonNumeric = RegExp(r'[^1234567890]');
// ignore: unnecessary_late
late final numericFormatter = TextInputFormatter.withFunction(
  (old, newV) => nonNumeric.hasMatch(newV.text) ? old : newV,
);
// ignore: unnecessary_late
late final TextInputFormatter parsableDecimal = getParsableDecimalFormatter();

TextInputFormatter getParsableDecimalFormatter([bool Function(double)? test]) =>
    TextInputFormatter.withFunction(
      (oldValue, newValue) {
        var t = double.tryParse(newValue.text);
        return t != null && (test?.call(t) ?? true) ? newValue : oldValue;
      },
    );
// #endregion TextInputFormatter

TextEditingController? defaultSelection(String? defaultValue) =>
    defaultValue?.isEmpty ?? true
        ? null
        : TextEditingController.fromValue(TextEditingValue(
            text: defaultValue!,
            selection: TextSelection(
              baseOffset: 0,
              extentOffset: defaultValue.length,
            ),
          ));

Size calculateTextSize({
  required String text,
  required TextStyle style,
  BuildContext? context,
}) {
  final textScaler = context != null
      ? MediaQuery.of(context).textScaler
      : TextScaler.linear(
          WidgetsBinding.instance.platformDispatcher.textScaleFactor);

  final TextDirection textDirection =
      context != null ? Directionality.of(context) : TextDirection.ltr;

  final TextPainter textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout(minWidth: 0, maxWidth: double.infinity);

  return textPainter.size;
}

const fullPageSpinner = Scaffold(
  body: SafeArea(child: Column(children: [spinnerExpanded])),
);
const spinnerExpanded = Expanded(
  child: AspectRatio(
    aspectRatio: 1,
    child: CircularProgressIndicator(),
  ),
);
// #region Url and Link Stuff
const commonTopLevelDomainStr = "com|org|gov|net|edu|jp|us|au|uk|tv"; //|mil|xxx
// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
RegExp get urlMatcher => RegExp(urlMatcherStr);

/// Requires at least one of these:
/// * A scheme of `http(s)`
/// * `www.`
/// * One of the values in [commonTopLevelDomainStr]
const urlMatcherStr =
    r"(?:(http(?:s)?:\/\/)|(?=www\.)|(?=(?:www\.)?(?:[-a-zA-Z0-9@:%._\+~#=]{1,256}?\.(?:"
    "$commonTopLevelDomainStr"
    r")\b)))"
    r"(www\.)?"
    r"([-a-zA-Z0-9@:%._\+~#=]{1,256})"
    r"\.([a-z]{2,6})\b"
    r"([-a-zA-Z0-9@:%_\+.~#?&//=]*)";
const urlMatcherOldStr = r"(http(?:s)?:\/\/)?"
    r"(www\.){0,1}"
    r"([-a-zA-Z0-9@:%._\+~#=]{1,256})"
    r"\.([a-z]{2,6})\b"
    r"([-a-zA-Z0-9@:%_\+.~#?&//=]*)";
// r"(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)";
RegExp get urlMatcherStrict => RegExp("^$urlMatcherStr\$");
const urlMatcherStrictStr = "^$urlMatcherStr\$";
const linkifierOptions = LinkifyOptions(
  humanize: false,
  removeWww: false,
  looseUrl: false,
  excludeLastPeriod: true,
  defaultToHttps: true,
);
Future<bool?> defaultTryLaunchUrl(Uri url, {BuildContext? ctx}) =>
    canLaunchUrl(url).then<bool?>((value) => value
        ? launchUrl(url)
        : ctx != null && ctx.mounted
            ? showDialog<bool?>(
                context: ctx,
                builder: (ctx2) => AlertDialog(
                  content: const Text("Cannot open in browser"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2),
                      child: const Text("Ok"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2, launchUrl(url)),
                      child: const Text("Try anyway"),
                    ),
                  ],
                ),
              )
            : null);

Future<bool?> defaultOnLinkifyOpen(LinkableElement link) {
  final url = Uri.parse(link.url);
  return canLaunchUrl(url).then<bool?>(
    (value) => value ? launchUrl(url) : null,
  );
}

Future<bool?>? defaultOnE6LinkifyOpen(
    LinkableElement link, BuildContext context) {
  if (supportedFirstPathSegments.contains(
        Uri.tryParse(link.url)?.pathSegments.first,
      ) &&
      context.mounted) {
    Navigator.pushNamed(context, link.url);
    return null;
  }
  return defaultOnLinkifyOpen(link);
}

void Function(LinkableElement) buildInAppOnE6LinkifyOpen(
        BuildContext context) =>
    (LinkableElement link) => defaultOnE6LinkifyOpen(link, context);
void Function(LinkableElement) buildDefaultOnE6LinkifyOpen(
        BuildContext context) =>
    (LinkableElement link) {
      if (supportedFirstPathSegments.contains(
            Uri.tryParse(link.url)?.pathSegments.first,
          ) &&
          context.mounted) {
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Launch In App")),
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Launch In Browser")),
            ],
          ),
        ).then((v) => switch (v) {
              // true => defaultOnE6LinkifyOpen(link, context),
              true => context.mounted
                  ? Navigator.pushNamed(context, link.url)
                  : defaultOnLinkifyOpen(link),
              false => defaultOnLinkifyOpen(link),
              null => null,
            });
      } else {
        defaultOnLinkifyOpen(link);
      }
    };

class MyLinkifier extends UrlLinkifier {
  const MyLinkifier();
  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    final scheme = "http${options.defaultToHttps ? "s" : ""}://";
    return /* super.parse( */
        elements.expand(
      (e) {
        final p = RegExp(urlMatcherStr)
            .allMatches(e.text)
            .fold((<LinkifyElement>[], 0), (p, m) {
          return (
            p.$1
              ..addAll([
                TextElement(e.text.substring(p.$2, m.start)),
                UrlElement(
                  "${m.group(1) ?? scheme}"
                      // "www."
                      "${options.removeWww ? "" : m.group(2) ?? ""}"
                      "${m.group(3)}.${m.group(4)}"
                      "${options.excludeLastPeriod ? m.group(5)?.replaceAll(
                            RegExp(r"\.$"),
                            "",
                          ) : m.group(5)}",
                  "${options.humanize ? "" : m.group(1) ?? ""}"
                      // "${options.removeWww ? "" : "www."}"
                      "${options.removeWww ? "" : m.group(2) ?? ""}"
                      "${m.group(3)}.${m.group(4)}"
                      "${options.excludeLastPeriod ? m.group(5)?.replaceAll(
                            RegExp(r"\.$"),
                            "",
                          ) : m.group(5)}",
                )
              ]),
            m.end
          );
        });
        return p.$1..add(TextElement(e.text.substring(p.$2)));
      },
    ).toList() /* ,
        options) */
        ;
  }
}

const defaultLinkStyle = TextStyle(
  fontStyle: FontStyle.italic,
  color: Colors.amber,
  decoration: TextDecoration.underline,
);
// #endregion Url and Link Stuff

T? contextCheck<T>(
  BuildContext? context,
  T Function(BuildContext) ifTrue, [
  T? Function(BuildContext?)? ifFalse,
]) =>
    context != null && context.mounted
        ? ifTrue(context)
        : ifFalse?.call(context) ?? null as T?;
ButtonStyle? modifyTextButtonStyle(
  BuildContext context, {
  WidgetStateProperty<TextStyle?>? textStyle,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? foregroundColor,
  WidgetStateProperty<Color?>? overlayColor,
  WidgetStateProperty<Color?>? shadowColor,
  WidgetStateProperty<Color?>? surfaceTintColor,
  WidgetStateProperty<double?>? elevation,
  WidgetStateProperty<EdgeInsetsGeometry?>? padding,
  WidgetStateProperty<Size?>? minimumSize,
  WidgetStateProperty<Size?>? fixedSize,
  WidgetStateProperty<Size?>? maximumSize,
  WidgetStateProperty<Color?>? iconColor,
  WidgetStateProperty<double?>? iconSize,
  WidgetStateProperty<BorderSide?>? side,
  WidgetStateProperty<OutlinedBorder?>? shape,
  WidgetStateProperty<MouseCursor?>? mouseCursor,
  VisualDensity? visualDensity,
  MaterialTapTargetSize? tapTargetSize,
  Duration? animationDuration,
  bool? enableFeedback,
  AlignmentGeometry? alignment,
  InteractiveInkFeatureFactory? splashFactory,
  Widget Function(BuildContext, Set<WidgetState>, Widget?)? backgroundBuilder,
  Widget Function(BuildContext, Set<WidgetState>, Widget?)? foregroundBuilder,
}) =>
    Theme.of(context).textButtonTheme.style?.copyWith(
          textStyle: textStyle,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          overlayColor: overlayColor,
          shadowColor: shadowColor,
          surfaceTintColor: surfaceTintColor,
          elevation: elevation,
          padding: padding,
          minimumSize: minimumSize,
          fixedSize: fixedSize,
          maximumSize: maximumSize,
          iconColor: iconColor,
          iconSize: iconSize,
          side: side,
          shape: shape,
          mouseCursor: mouseCursor,
          visualDensity: visualDensity,
          tapTargetSize: tapTargetSize,
          animationDuration: animationDuration,
          enableFeedback: enableFeedback,
          alignment: alignment,
          splashFactory: splashFactory,
          backgroundBuilder: backgroundBuilder,
          foregroundBuilder: foregroundBuilder,
        );

/// If [delay] is null, uses `Future.sync`; otherwise, uses `Future.delayed`
Stream<E> toListStream<E>(Iterable<E> collection, {Duration? delay}) async* {
  for (var i = collection.iterator;
      i.moveNext();
      await (delay != null ? Future.delayed(delay) : Future.sync(() {}))) {
    yield i.current;
  }
}

//   Iterable<E> collection, {
//   // bool growable = true,
//   Duration? delay,
Future<List<E>> toListAsync<E>(Iterable<E> collection) async {
  final r = <E>[], i = collection.iterator;
  for (var loop = await Future.microtask(() => i.moveNext()),
          e = loop ? await Future.microtask(() => i.current) : null;
      loop;
      loop = await Future.microtask(() => i.moveNext()),
      e = loop ? await Future.microtask(() => i.current) : null) {
    r.add(e as E);
  }
  return r;
  // return growable ? r : r.toList(growable: false);
}
