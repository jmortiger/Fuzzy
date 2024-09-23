import 'dart:io';

import 'package:archive/archive.dart'
    if (dart.library.io) 'package:archive/archive_io.dart' as a;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:http/http.dart' as http;
import 'package:e621/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart'
    show LateFinal, LateInstance, LazyInitializer, Platform;
import 'package:flutter/foundation.dart';

// #region Logger
lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("TagDbImport");
// #endregion Logger
const bool DO_NOT_USE_TAG_DB = false;
final tagDb = LateFinal<TagDB>();
Future<TagDB> _core(String vf) {
  _print("Tag Database Decompressed!");
  return TagDB.makeFromCsvString(vf);
}

Future<TagDB> _fromListCallback(List<int> value) {
  return http.ByteStream.fromBytes(value).bytesToString().then(_core);
}

Future<TagDB> _fromUint8ListCallback(Uint8List value) {
  return _fromListCallback(value.toList(growable: false));
}

Future<TagDB> _decodeFromServerCallback(http.StreamedResponse value) {
  // return decompressGzPlainTextStream(value).then(_core);
  return value.stream.toBytes().then((v) => _decodeFromUint8ListCallback(v));
}

Future<TagDB> _decodeFromUint8ListCallback(Uint8List value) {
  return _fromListCallback(
    a.GZipDecoder().decodeBytes(value.toList(growable: false)),
  );
}

Future<TagDB> _decodeFromLocalCallback(ByteData data) {
  return _fromListCallback(a.GZipDecoder().decodeBuffer(a.InputStream(data)));
}

final LateInstance<String> tagDbPathInst = LateInstance();
// String get tagDbPath => tagDbPathInst.isAssigned ? tagDbPathInst.$ : tagDbPathInst.$ = Platform.isWeb ? "assets/tags-2024-06-05.csv.gz" :
const defaultPath = "assets/tags-2024-06-05.csv.gz";
final LazyInitializer<TagDB> tagDbLazy = LazyInitializer(() async {
  if (Platform.isWeb) {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["csv", "csv.gz", "txt"],
    );
    if (r == null) {
      var data = await rootBundle.load(defaultPath);
      _print("Tag Database Loaded!");
      return compute(_decodeFromLocalCallback, data);
    } else {
      _print("Tag Database Loaded!");
      // if (r.names.firstOrNull!.endsWith(".gz")) {
      if (r.files.first.extension == "gz") {
        return compute(_decodeFromUint8ListCallback, r.files.first.bytes!);
      } else {
        _print("Tag Database Decompressed!");
        return compute(_fromUint8ListCallback, r.files.first.bytes!);
      }
    }
  } else {
    if (SearchView.i.tagDbPath != defaultPath) {
      try {
        final f = File(SearchView.i.tagDbPath);
        return await (f.uri.toFilePath().endsWith(".gz")
            ? _decodeFromUint8ListCallback(await f.readAsBytes())
            : _fromListCallback(await f.readAsBytes()));
      } catch (e, s) {
        _logger.severe(e, e, s);
        try {
          var data = await rootBundle.load(defaultPath);
          _print("Tag Database Loaded!");
          return compute(_decodeFromLocalCallback, data);
        } catch (e, s) {
          _logger.severe(e, e, s);
          return E621
              .sendRequest(e621.initDbExportRequest())
              .then((value) => compute(_decodeFromServerCallback, value));
        }
      }
    } else {
      var data = await rootBundle.load(defaultPath);
      _print("Tag Database Loaded!");
      return compute(_decodeFromLocalCallback, data);
    }
    // return E621
    //     .sendRequest(e621.initDbExportRequest())
    //     .then((value) => compute(_decodeFromServerCallback, value));
  }
});

Future<String> getDatabaseFileFromServer() {
  return compute(_getDatabaseFileFromServer, null);
}

Future<String> getDatabaseFileFromCompressedFileIo(File f) =>
    compute(_getDatabaseFileFromCompressedFileIo, f);
Future<String> _getDatabaseFileFromServer(Null _) => E621.sendRequest(e621.initDbExportRequest()).then((value) =>
      value.stream.toBytes().then((v) => http.ByteStream.fromBytes(
              a.GZipDecoder().decodeBytes(v.toList(growable: false)))
          .bytesToString()));

Future<String> _getDatabaseFileFromCompressedFileIo(File f) =>
    f.readAsBytes().then((v) => http.ByteStream.fromBytes(
            a.GZipDecoder().decodeBytes(v.toList(growable: false)))
        .bytesToString());
// Future<String> getDatabaseFileFromCompressedFileBundle(ByteData f) =>
//     f.readAsBytes().then((v) => http.ByteStream.fromBytes(
//             a.GZipDecoder().decodeBytes(v.toList(growable: false)))
//         .bytesToString());
