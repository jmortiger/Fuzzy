import 'dart:async' show FutureOr;
import 'dart:convert' as dc;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:j_util/j_util_full.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:url_launcher/url_launcher.dart';

// #region Logger
lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("Util");
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

ScaffoldFeatureController showUserMessage({
  required BuildContext context,
  required Widget content,
  bool autoHidePrior = true,
  Duration? duration = const Duration(seconds: 2),
  (String label, VoidCallback onTap)? action,
  List<(String label, VoidCallback onTap)>? actions,
}) =>
    // _showUserMessageSnackbar(
    _showUserMessageBanner(
      context: context,
      content: content,
      action: action,
      actions: actions,
      autoHidePrior: autoHidePrior,
      duration: duration,
    );

ScaffoldFeatureController _showUserMessageSnackbar({
  required BuildContext context,
  required Widget content,
  bool autoHidePrior = true,
  Duration? duration = const Duration(seconds: 2),
  (String label, VoidCallback onTap)? action,
  List<(String label, VoidCallback onTap)>? actions,
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
}) {
  final message = MaterialBanner(
        content: content,
        actions: _makeBannerAction(action, actions),
      ),
      sm = ScaffoldMessenger.of(context);
  if (autoHidePrior) sm.hideCurrentMaterialBanner();
  if (duration == null) return sm.showMaterialBanner(message);
  final ret = sm.showMaterialBanner(message);
  Future.delayed(duration, () => ret.close()).ignore();
  return ret;
}

List<Widget> _makeBannerAction((String label, VoidCallback onTap)? action,
    List<(String label, VoidCallback onTap)>? actions) {
  Widget make((String label, VoidCallback onTap) action) => TextButton.icon(
        label: Text(action.$1),
        onPressed: action.$2,
      );
  return [
    if ((action ?? actions) == null || (action == null && actions!.isEmpty))
      TextButton.icon(label: const Text("Ok"), onPressed: () {}),
    if (action != null) make(action),
    if (actions != null) ...actions.map(make)
  ];
}

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

extension StringPrint on String {
  String printMe() {
    _print(this);
    return this;
  }
}

T castMap<T>(dynamic e, int i, Iterable<dynamic> l) => e as T;
final nonNumeric = RegExp(r'[^1234567890]');
final TextInputFormatter numericFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      (nonNumeric.hasMatch(newValue.text)) ? oldValue : newValue,
);
final TextInputFormatter parsableDecimal = getParsableDecimalFormatter();

TextInputFormatter getParsableDecimalFormatter([bool Function(double)? test]) =>
    TextInputFormatter.withFunction(
      (oldValue, newValue) {
        var t = double.tryParse(newValue.text);
        return t != null && (test?.call(t) ?? true) ? newValue : oldValue;
      },
    );

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
// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
RegExp get urlMatcher => RegExp(urlMatcherStr);
const urlMatcherStr = r"(http(?:s)?:\/\/)?"
    r"(www\.){0,1}"
    r"([-a-zA-Z0-9@:%._\+~#=]{1,256})"
    r"\.([a-z]{2,6})\b"
    r"([-a-zA-Z0-9@:%_\+.~#?&//=]*)";
// r"(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)";
RegExp get urlMatcherStrict => RegExp("^$urlMatcherStr\$");
const urlMatcherStrictStr = "^$urlMatcherStr\$";
void defaultOnLinkifyOpen(LinkableElement link) {
  final url = Uri.parse(link.url);
  canLaunchUrl(url).then(
    (value) => value
        ? launchUrl(url)
        : "" /* showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: const Text("Cannot open in browser"),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Ok"))
                          ],
                        ),
                      ) */
    ,
  );
}

const defaultLinkStyle = TextStyle(
  fontStyle: FontStyle.italic,
  color: Colors.amber,
  decoration: TextDecoration.underline,
);

const placeholderPath = "assets/snake_loader.webp";
const placeholder = AssetImage(placeholderPath);
// final deletedPreviewImage = LazyInitializer<Image>(() => rootBundle.load("assets/deleted-preview.png").then((v) => Image.asset(name)))
const deletedPreviewImagePath = "assets/deleted-preview.png";

// class StaticImageData {
//   static const deletedPreview = _DeletedPreview,
//       deleted4x = _Deleted4x,
//       notFoundPreview = _NotFoundPreview,
//       notFound4x = _NotFound4x;
//   // static const deletedPreview = StaticImageRecord(
//   //       path: "assets/deleted-preview.png",
//   //       width: 150,
//   //       height: 150,
//   //     ),
//   //     deleted4x = StaticImageRecord(
//   //       path: "assets/deleted_4x.png",
//   //       width: 600,
//   //       height: 600,
//   //     ),
//   //     notFoundPreview = StaticImageRecord(
//   //       path: "assets/not_found.png",
//   //       width: 150,
//   //       height: 150,
//   //     ),
//   //     notFound4x = StaticImageRecord(
//   //       path: "assets/not_found_4x.png",
//   //       width: 600,
//   //       height: 600,
//   //     );
// }

@immutable
class StaticImageRecord {
  final String path;
  final int width;
  final int height;

  const StaticImageRecord(
      {required this.path, required this.width, required this.height});
}

class StaticImageDataDeletedPreview {
  static const path = "assets/deleted-preview.png", width = 150, height = 150;
}

class StaticImageDataDeleted4x {
  static const path = "assets/deleted_4x.png", width = 600, height = 600;
}

class StaticImageDataNotFoundPreview {
  static const path = "assets/not_found.png", width = 150, height = 150;
}

class StaticImageDataNotFound4x {
  static const path = "assets/not_found_4x.png", width = 600, height = 600;
}
// const staticImageData = (
//   deletedPreview : (
//     path: "assets/deleted-preview.png",
//     width: 150,
//     height: 150,
//   ),
//   deleted4x : (
//     path: "assets/deleted_4x.png",
//     width: 600,
//     height: 600,
//   ),
//   notFoundPreview : (
//     path: "assets/not_found.png",
//     width: 150,
//     height: 150,
//   ),
//   notFound4x : (
//     path: "assets/not_found_4x.png",
//     width: 600,
//     height: 600,
//   ),
// );
// const staticImageData = {
//   "deletedPreview" : {
//     "path": "assets/deleted-preview.png",
//     "width": 150,
//     "height": 150,
//   },
//   "deleted4x" : {
//     "path": "assets/deleted_4x.png",
//     "width": 600,
//     "height": 600,
//   },
//   "notFoundPreview" : {
//     "path": "assets/not_found.png",
//     "width": 150,
//     "height": 150,
//   },
//   "notFound4x" : {
//     "path": "assets/not_found_4x.png",
//     "width": 600,
//     "height": 600,
//   },
// };
