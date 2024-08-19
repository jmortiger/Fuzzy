import 'dart:async' show FutureOr;
import 'dart:convert' as dc;

import 'package:archive/archive.dart' as archive
  if (dart.library.io) 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:logging/logging.dart';
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
final appDataPath =
    LazyInitializer(() => (Platform.isWeb) 
      ? Future.sync(() => "") 
      : path.getDownloadsDirectory/* getApplicationDocumentsDirectory */().then(
          (value) => value!.absolute.path,
        ));
final devDataString = LazyInitializer<String>(() => (rootBundle.loadString("assets/devData.json")
                ..onError(defaultOnError /* onErrorPrintAndRethrow */)));
final devData = LazyInitializer<JsonMap>(() async => dc.jsonDecode(await devDataString.getItem()));
final tagDb = LateFinal<TagDB>();
Future<TagDB> _androidCallback(http.StreamedResponse value) => decompressGzPlainTextStream(value).then((vf) {
              _print("Tag Database Decompressed!");
              return TagDB.makeFromCsvString(
                  vf);
            });
Future<TagDB> _webCallback(ByteData data) => http.ByteStream.fromBytes(
            archive.GZipDecoder().decodeBuffer(archive.InputStream(data)))
        .bytesToString()
        .then((vf) {
      _print("Tag Database Decompressed!");
      return TagDB.makeFromCsvString(vf);
    });
const bool DO_NOT_USE_TAG_DB = true;
final LazyInitializer<TagDB> tagDbLazy = LazyInitializer(() async {
  if (Platform.isWeb) {
    var data = await rootBundle.load("assets/tags-2024-06-05.csv.gz");
    _print("Tag Database Loaded!");
    return compute(_webCallback, data);
  } else {
    return 
        E621.sendRequest(e621.Api.initDbExportRequest())
        .then((value) => compute(_androidCallback, value));
        // E621ApiEndpoints.dbExportTags
        // .getMoreData()
        // .sendRequest()
        // .then((value) => compute(_androidCallback, value));
  }
});
final pref = LazyInitializer<SharedPreferences>(() => SharedPreferences.getInstance());
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
final List<SnackBar Function(BuildContext context)> snackbarBuilderMessageQueue = <SnackBar Function(BuildContext context)>[];

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
  (oldValue, newValue) => (nonNumeric.hasMatch(newValue.text)) ? oldValue : newValue,
  );
final TextInputFormatter parsableDecimal = getParsableDecimalFormatter();

TextInputFormatter getParsableDecimalFormatter([bool Function(double)? test]) => TextInputFormatter.withFunction(
  (oldValue, newValue) {
    var t = double.tryParse(newValue.text);
    return t != null && (test?.call(t) ?? true) ? newValue : oldValue;
  },
);

TextEditingController? defaultSelection(String? defaultValue) => defaultValue?.isEmpty ?? true
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
      : TextScaler.linear(WidgetsBinding.instance.platformDispatcher.textScaleFactor);

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
void logRequest(
    http.Request r,
    Logger logger, [
    Level level = Level.FINEST,
  ]) {
  logger.log(
    level,
    "Request:"
    "\n\t$r"
    "\n\t${r.url}"
    "\n\t${r.url.query}"
    "\n\t${r.body}"
    "\n\t${r.headers}",
  );
}
void logResponse(
    http.Response v,
    Logger logger, [
    Level level = Level.FINEST,
  ]) {
  logger.log(
    level,
    "Response:"
    "\n\t$v"
    "\n\t${v.body}"
    "\n\t${v.statusCode}"
    "\n\t${v.headers}",
  );
}
// final deletedPreviewImage = LazyInitializer<Image>(() => rootBundle.load("assets/deleted-preview.png").then((v) => Image.asset(name)))
const deletedPreviewImagePath = "assets/deleted-preview.png";