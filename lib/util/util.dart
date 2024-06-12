import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/web/site.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:archive/archive.dart' as archive
  if (dart.library.io) 'package:archive/archive_io.dart';

typedef JsonMap = Map<String, dynamic>;
final LazyInitializer<PackageInfo> packageInfo = LazyInitializer(
  () => PackageInfo.fromPlatform(),
);
final LazyInitializer<String> version = LazyInitializer(
  () async => (await packageInfo.getItem()).version,
  defaultValue: "VERSION_NUMBER",
);

final LazyInitializer<String> appDataPath =
    LazyInitializer(() => path.getApplicationDocumentsDirectory().then(
          (value) => value.absolute.path,
        ));

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
    return E621ApiEndpoints.dbExportTags
        .getMoreData()
        .sendRequest()
        .then((value) => compute(_androidCallback, value));
  }
});
