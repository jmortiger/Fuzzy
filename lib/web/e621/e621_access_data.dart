import 'dart:async';
import 'dart:convert';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';
import 'package:fuzzy/log_management.dart' as lm;

final class E621AccessData with Storable<E621AccessData> {
  // #region Logger
  static late final lRecord = lm.genLogger("E621AccessData");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  static final devAccessData = LazyInitializer<E621AccessData>(() async =>
      E621AccessData.fromJson((await devData.getItem())["e621"] as JsonOut));
  static String? get devApiKey => devAccessData.itemSafe?.apiKey;
  static String? get devUsername => devAccessData.itemSafe?.username;
  static String? get devUserAgent => devAccessData.itemSafe?.userAgent;
  static final userData = LateInstance<E621AccessData>();
  static const fileName = "credentials.json";
  static final filePathFull = LazyInitializer<String>(
    () async =>
        (!Platform.isWeb) ? "${(await appDataPath.getItem())}/$fileName" : "",
  );
  static Future<E621AccessData?> tryLoad() async {
    if (Platform.isWeb) {
      var t = (await pref.getItem()).getString(localStorageKey);
      if (t != null) return E621AccessData.fromJson(jsonDecode(t));
    }
    var t = await (await Storable.tryGetStorageAsync(
      await filePathFull.getItem(),
    ))
        ?.readAsString();
    if (t == null) {
      logger.warning(
        "Failed to load:"
        "\tfileName: $fileName"
        "\tfilePathFull: ${filePathFull.itemSafe}",
      );
      return null;
    }
    return userData.$ = E621AccessData.fromJson(jsonDecode(t));
  }

  static void _failedToLoadLog(E621AccessData? data) => logger.warning(
        "Failed to load: $data"
        "\n\tfileName: $fileName"
        "\n\tfilePathFull: ${filePathFull.itemSafe}"
        "\n\tfile.isAssigned: ${data?.file.isAssigned}"
        "\n\tfile.itemSafe?.existsSync(): "
        "${data?.file.itemSafe?.existsSync()}",
      );
  static const localStorageKey = "e6Access";
  static Future<bool> tryWrite([E621AccessData? data]) async {
    if (Platform.isWeb) {
      logger.info("Can't access file storage on web. "
          "Local Storage solution not implemented.");
      return false;
    }
    data ??= userData.itemSafe;
    if (data != null) {
      if (Platform.isWeb) {
        return (await pref.getItem()).setString(
          localStorageKey,
          jsonEncode(data.toJson()),
        );
      }
      if (!data.file.isAssigned) {
        logger.warning(
            "data.file.isAssigned was false. Attempting initialization");
        data.initStorageAsync(filePathFull.getItem()).onError(
              (e, s) => logger.warning("Failed to initialize Storable", e, s),
            );
      }
      return data.tryWriteAsync(flush: true)
        ..then<void>((v) {
          if (!v) _failedToLoadLog(data);
        });
    } else {
      _failedToLoadLog(data);
      return false;
    }
  }

  final String apiKey;
  final String username;
  final String userAgent;
  e621.E6Credentials get cred =>
      e621.E6Credentials(username: username, apiKey: apiKey);

  /* const  */ E621AccessData({
    required this.apiKey,
    required this.username,
    required this.userAgent,
  }) {
    initStorageAsync(filePathFull.getItem()).onError(
      (e, s) => logger.log(
          Platform.isWeb ? lm.LogLevel.FINER : lm.LogLevel.WARNING,
          "Failed to initialize Storable",
          e,
          s),
    );
  }
  factory E621AccessData.withDefault({
    required String apiKey,
    required String username,
    String? userAgent,
  }) =>
      E621AccessData(
          apiKey: apiKey,
          username: username,
          userAgent: userAgent ??
              "fuzzy/${version.itemSafe} by atotaltirefire@gmail.com");
  JsonOut toJson() => {
        "apiKey": apiKey,
        "username": username,
        "userAgent": userAgent,
      };
  factory E621AccessData.fromJson(JsonOut json) => E621AccessData(
        apiKey: json["apiKey"] as String,
        username: json["username"] as String,
        userAgent: json["userAgent"] as String,
      );
  // Map<String,String> generateHeaders() {

  // }
}
