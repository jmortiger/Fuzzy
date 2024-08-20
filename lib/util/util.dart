import 'dart:async' show FutureOr;
import 'dart:convert' as dc;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:j_util/j_util_full.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuzzy/log_management.dart' as lm;

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

final List<SnackBar> snackbarMessageQueue = <SnackBar>[];
final List<SnackBar Function(BuildContext context)>
    snackbarBuilderMessageQueue = <SnackBar Function(BuildContext context)>[];

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
  body: SafeArea(child: Column(children: [exArCpi])),
);
const exArCpi = Expanded(
  child: AspectRatio(
    aspectRatio: 1,
    child: CircularProgressIndicator(),
  ),
);

const placeholderPath = "assets/snake_loader.webp";
const placeholder = AssetImage(placeholderPath);
// final deletedPreviewImage = LazyInitializer<Image>(() => rootBundle.load("assets/deleted-preview.png").then((v) => Image.asset(name)))
const deletedPreviewImagePath = "assets/deleted-preview.png";
