import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart'
    if (dart.library.io) 'package:archive/archive_io.dart' as a;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:http/http.dart' as http;
import 'package:e621/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart' show LazyInitializer, Platform;
import 'package:flutter/foundation.dart';

// ignore: unnecessary_late
late final _logger = lm.generateLogger("TagDbImport").logger;
// ignore: constant_identifier_names
const bool DO_NOT_USE_TAG_DB = false;
Future<TagDB> _core(String vf) {
  _logger.finest("Tag Database Decompressed!");
  return compute(TagDB.makeFromCsvString, vf);
}

// #region String
Future<String> _fromList(List<int> data) {
  return http.ByteStream.fromBytes(data).bytesToString();
}

Future<String> _decodeFromServer(http.StreamedResponse data) {
  return data.stream.toBytes().then((v) => _decodeFromList(v));
}

Future<String> _decodeFromList(List<int> data) {
  return _fromList(a.GZipDecoder().decodeBytes(data));
}

Future<String> _decodeFromFileIo(File data) {
  return data.readAsBytes().then(_decodeFromList);
}

Future<String> _decodeFromLocal(ByteData data) {
  return _fromList(a.GZipDecoder().decodeBuffer(a.InputStream(data)));
}

/// TODO: TEST
Future<String> _decodeFromListStream(Stream<List<int>> data) =>
    data.fold(<int>[], (p, e) => p..addAll(e)).then((v) => _decodeFromList(v));

/// Supports `FutureOr`:
/// * Compressed `Stream<List<int>>`
/// * Compressed `ByteData`
/// * Compressed `StreamedResponse`
/// * Compressed & uncompressed `List<int>`/`Uint8List`
/// * Compressed & uncompressed `File`
Future<String> processPlaintextData<T>(
        // T data, bool isCompressed) async =>
        //     T data, bool isCompressed) =>
        // switch (data) {
        T data,
        bool isCompressed) async =>
    switch (data) {
      Stream<List<int>> f => isCompressed
          ? _decodeFromListStream(f)
          : throw UnsupportedError(
              "Uncompressed Stream<List<int>> not supported"),
      ByteData d => isCompressed
          ? _decodeFromLocal(d)
          : throw UnsupportedError("Uncompressed ByteData not supported"),
      Future<http.StreamedResponse> d => isCompressed
          ? d.then((v) => _decodeFromServer(v)) //_decodeFromServer(await d)
          : throw UnsupportedError(
              "Uncompressed Future<StreamedResponse> not supported"),
      http.StreamedResponse d => isCompressed
          ? _decodeFromServer(d)
          : throw UnsupportedError(
              "Uncompressed StreamedResponse not supported"),
      List<int> d => isCompressed ? _decodeFromList(d) : _fromList(d),
      File d => isCompressed ? _decodeFromFileIo(d) : d.readAsString(),
      dynamic f =>
        throw UnsupportedError("type ${f.runtimeType} not supported"),
    };

Future<String> processCompressedPlaintextData<T>(T data) =>
    processPlaintextData(data, true).onError((e, s) {
      _logger.severe(e, e, s);
      return "";
    });
Future<String> processUncompressedPlaintextData<T>(T data) =>
    processPlaintextData(data, false).onError((e, s) {
      _logger.severe(e, e, s);
      return "";
    });

Future<TagDB> processTagDbData<T>(T data, bool isCompressed) =>
    compute((_) => processPlaintextData(data, isCompressed), null).then(_core);
Future<TagDB> processCompressedTagDbData<T>(T data) =>
    processTagDbData(data, true);
Future<TagDB> processUncompressedTagDbData<T>(T data) =>
    processTagDbData(data, false);
// #endregion String

const defaultPath = "assets/tags-2024-06-05.csv.gz";
final LazyInitializer<TagDB> tagDbLazy = LazyInitializer(() async {
  try {
    if (Platform.isWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["csv", "csv.gz", "txt"],
      );
      if (r == null) {
        var data = await rootBundle.load(defaultPath);
        _logger.finest("Tag Database Loaded!");
        return await compute(processCompressedTagDbData, data);
      } else {
        _logger.finest("Tag Database Loaded!");
        // if (r.names.firstOrNull!.endsWith(".gz")) {
        if (r.files.first.extension == "gz") {
          return await compute(
              processCompressedTagDbData, r.files.first.bytes!);
        } else {
          _logger.finest("Tag Database Decompressed!");
          return await compute(
              processUncompressedTagDbData, r.files.first.bytes!);
        }
      }
    } else {
      if (SearchView.i.tagDbPath != defaultPath) {
        try {
          final f = File(SearchView.i.tagDbPath), t = await f.readAsBytes();
          _logger.finest("Tag Database Loaded!");
          if (f.uri.toFilePath().endsWith(".gz")) {
            return await compute(processCompressedTagDbData, t);
          } else {
            _logger.finest("Tag Database Decompressed!");
            return await compute(processUncompressedTagDbData, t);
          }
        } catch (e, s) {
          _logger.severe(e, e, s);
          try {
            final data = await rootBundle.load(defaultPath);
            _logger.finest("Tag Database Loaded!");
            return await compute(processCompressedTagDbData, data);
          } catch (e, s) {
            _logger.severe(e, e, s);
            return await compute(
              processCompressedTagDbData,
              await E621.sendRequest(e621.initDbExportTagsGet()),
            );
          }
        }
      } else {
        final data = await rootBundle.load(defaultPath);
        _logger.finest("Tag Database Loaded!");
        return await compute(processCompressedTagDbData, data);
      }
    }
  } catch (e, s) {
    _logger.severe(e, e, s);
    try {
      final data = await rootBundle.load(defaultPath);
      _logger.finest("Tag Database Loaded!");
      return await compute(processCompressedTagDbData, data);
    } catch (e, s) {
      _logger.severe(e, e, s);
      return await compute(
        processCompressedTagDbData,
        await E621.sendRequest(e621.initDbExportTagsGet()),
      );
    }
  }
});

Future<String> getDatabaseFileFromServer() async =>
    processCompressedPlaintextData(
        await E621.sendRequest(e621.initDbExportTagsGet()));
// Future<String> getDatabaseFileFromServer() async => compute(
//     processCompressedPlaintextData,
//     await E621.sendRequest(e621.initDbExportTagsGet()));

Future<String> getDatabaseFileFromCompressedFileIo(File f) =>
    compute(processCompressedPlaintextData, f);

/// TODO: TEST
Future<String> getDatabaseFileFromCompressedStream(Stream<List<int>> f) =>
    compute(processCompressedPlaintextData, f);

/// TODO: TEST
Future<String> getDatabaseFileFromCompressedBytes(Uint8List f) =>
    compute(processCompressedPlaintextData, f);

/* Future<String> _getDatabaseFileFromCompressedBytes(Uint8List f) =>
    http.ByteStream.fromBytes(
            a.GZipDecoder().decodeBytes(f.toList(growable: false)))
        .bytesToString();
Future<String> _getDatabaseFileFromServer(Null _) =>
    E621.sendRequest(e621.initDbExportTagsGet()).then((value) => value.stream
        .toBytes()
        .then((v) => http.ByteStream.fromBytes(
                a.GZipDecoder().decodeBytes(v.toList(growable: false)))
            .bytesToString()));

Future<String> _getDatabaseFileFromCompressedFileIo(File f) =>
    f.readAsBytes().then((v) => http.ByteStream.fromBytes(
            a.GZipDecoder().decodeBytes(v.toList(growable: false)))
        .bytesToString());
Future<String> _getDatabaseFileFromCompressedStream(Stream<List<int>> f) =>
    f.fold(<int>[], (p, e) => p..addAll(e)).then((v) =>
        http.ByteStream.fromBytes(a.GZipDecoder().decodeBytes(v))
            .bytesToString()); */
