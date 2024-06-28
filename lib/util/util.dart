import 'dart:async' show FutureOr;
import 'dart:convert' as dc;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:archive/archive.dart' as archive
  if (dart.library.io) 'package:archive/archive_io.dart';

import 'package:j_util/e621.dart' as e621;

typedef JsonMap = Map<String, dynamic>;
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
              print("Tag Database Decompressed!");
              return TagDB.makeFromCsvString(
                  vf);
            });
Future<TagDB> _webCallback(ByteData data) => http.ByteStream.fromBytes(
            archive.GZipDecoder().decodeBuffer(archive.InputStream(data)))
        .bytesToString()
        .then((vf) {
      print("Tag Database Decompressed!");
      return TagDB.makeFromCsvString(vf);
    });
const bool DO_NOT_USE_TAG_DB = true;
final LazyInitializer<TagDB> tagDbLazy = LazyInitializer(() async {
  if (Platform.isWeb) {
    var data = await rootBundle.load("assets/tags-2024-06-05.csv.gz");
    print("Tag Database Loaded!");
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
FutureOr<T> onErrorPrintAndRethrow<T>(Object? e, StackTrace stackTrace) {
  print(e);
  throw e!;
}
T defaultOnError<T>(Object? error, StackTrace trace) => print(error) as T;

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
    print(this);
    return this;
  }
}
T castMap<T>(dynamic e, int i, Iterable<dynamic> l) => e as T;
final nonNumeric = RegExp(r'[^1234567890]');
TextInputFormatter numericFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) => (RegExp(r'[^1234567890]').hasMatch(newValue.text)) ? oldValue : newValue,
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
/// Annotation
const event = Event();

/// Annotation
class Event {
  const Event();
}

mixin Returns<T> {
  T? returnValue;
}
mixin ReturnsList<T> {
  final List<T> returnValue = <T>[];
}