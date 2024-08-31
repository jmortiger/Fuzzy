import 'package:archive/archive.dart'
    if (dart.library.io) 'package:archive/archive_io.dart' as archive;
import 'package:flutter/services.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart';
import 'package:flutter/foundation.dart';

// #region Logger
lm.Printer get _print => lRecord.print;
lm.FileLogger get _logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.generateLogger("TagDbImport");
// #endregion Logger
const bool DO_NOT_USE_TAG_DB = true;
final tagDb = LateFinal<TagDB>();
Future<TagDB> _core(String vf) {
  _print("Tag Database Decompressed!");
  return TagDB.makeFromCsvString(vf);
}

Future<TagDB> _androidCallback(http.StreamedResponse value) {
  return decompressGzPlainTextStream(value).then(_core);
}

Future<TagDB> _webCallback(ByteData data) {
  return http.ByteStream.fromBytes(
          archive.GZipDecoder().decodeBuffer(archive.InputStream(data)))
      .bytesToString()
      .then(_core);
}

final LazyInitializer<TagDB> tagDbLazy = LazyInitializer(() async {
  if (Platform.isWeb) {
    var data = await rootBundle.load("assets/tags-2024-06-05.csv.gz");
    _print("Tag Database Loaded!");
    return compute(_webCallback, data);
  } else {
    return E621
        .sendRequest(e621.initDbExportRequest())
        .then((value) => compute(_androidCallback, value));
    // E621ApiEndpoints.dbExportTags
    // .getMoreData()
    // .sendRequest()
    // .then((value) => compute(_androidCallback, value));
  }
});
