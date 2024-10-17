import 'dart:async';
import 'dart:convert';
import 'package:fuzzy/util/util.dart' hide pref;
import 'package:fuzzy/util/shared_preferences.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';
import 'package:fuzzy/log_management.dart' as lm;

/// TODO: Allow multiple accounts
/// TODO: Replace with e621 lib access data class
final class E621AccessData with Storable<E621AccessData> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("E621AccessData");
  // #endregion Logger
  @Deprecated("Don't use directly, use fallbackForced")
  static final devAccessData = LazyInitializer<E621AccessData?>(
      () async => E621AccessData.fromJson((await devData.getItem())?["e621"]));
  @Deprecated("Don't use directly, use fallbackForced")
  static String? get devApiKey => devAccessData.$Safe?.apiKey;
  @Deprecated("Don't use directly, use fallbackForced")
  static String? get devUsername => devAccessData.$Safe?.username;
  @Deprecated("Don't use directly, use fallbackForced")
  static String? get devUserAgent => devAccessData.$Safe?.userAgent;
  static bool useLoginData = true;
  static bool toggleUseLoginData() => useLoginData = !useLoginData;

  /// TODO: refactor behind fallback.
  @Deprecated("Don't use directly, use forcedUserData")
  static final userData = LateInstance<E621AccessData>();
  static E621AccessData allowedUserData = useLoginData
      ? forcedUserData
      : (throw "useLoginData == false; you need to force use login data");
  static E621AccessData? allowedUserDataSafe =
      useLoginData ? forcedUserDataSafe : null;

  /// Disregards state of [useLoginData].
  static E621AccessData forcedUserData =
      // ignore: deprecated_member_use_from_same_package
      isDebug ? (userData.$Safe ?? devAccessData.$Safe)! : userData.$;

  /// Disregards state of [useLoginData].
  static E621AccessData? forcedUserDataSafe =
      // ignore: deprecated_member_use_from_same_package
      userData.$Safe ?? (isDebug ? devAccessData.$Safe : null);

  /// Disregards state of [useLoginData].
  static FutureOr<E621AccessData>? forcedUserDataAsync =
      // ignore: deprecated_member_use_from_same_package
      userData.$Safe ??
          (isDebug
              // ignore: deprecated_member_use_from_same_package
              ? devAccessData.getItem() as FutureOr<E621AccessData>
              : null);
  static const fileName = "credentials.json";
  static final filePathFull = LazyInitializer<String>(
    () async =>
        (!Platform.isWeb) ? "${(await appDataPath.getItem())}/$fileName" : "",
  );
  static Future<String?> tryLoadAsStringAsync([E621AccessData? data]) async {
    return Platform.isWeb
        ? (await pref.getItem()).getString(localStorageKey)
        : await (await Storable.tryGetStorageAsync(
            await filePathFull.getItem(),
          ))
            ?.readAsString();
  }

  static String? tryLoadAsStringSync(/* [E621AccessData? data] */) {
    return Platform.isWeb
        ? pref.$Safe?.getString(localStorageKey)
        : Storable.tryGetStorageSync(
            filePathFull.$Safe ?? "",
          )?.readAsStringSync();
  }

  static Future<E621AccessData?> tryLoad() async {
    // ignore: deprecated_member_use_from_same_package
    if (isDebug) await devAccessData.getItem();
    if (Platform.isWeb) {
      var t = (await pref.getItem()).getString(localStorageKey);
      logger.warning("From Local Storage: $t");
      // ignore: deprecated_member_use_from_same_package
      if (t != null) return userData.$ = E621AccessData.fromJson(jsonDecode(t));
    }
    var t = await (await Storable.tryGetStorageAsync(
      await filePathFull.getItem(),
    ))
        ?.readAsString();
    if (t == null) {
      logger.warning(
        "Failed to load:"
        "\tfileName: $fileName"
        "\tfilePathFull: ${filePathFull.$Safe}",
      );
      return null;
    }
    try {
      // ignore: deprecated_member_use_from_same_package
      return userData.$ = E621AccessData.fromJson(jsonDecode(t));
    } catch (e) {
      logger.warning(
        "No Credential Data",
      );
      return null;
    }
  }

  static void _failedToDoIoLog(E621AccessData? data,
          [String operation = "load"]) =>
      logger.warning(
        "Failed to $operation: $data"
        "\n\tfileName: $fileName"
        "\n\tfilePathFull: ${filePathFull.$Safe}"
        "\n\tisAssigned: ${data?.isAssigned}"
        "\n\texistsSafe: ${data?.existsSafe}",
      );
  static const localStorageKey = "e6Access";
  static Future<bool> tryWriteToLocalStorage(E621AccessData data) =>
      pref.getItemAsync().then((v) => v.setString(
            localStorageKey,
            jsonEncode(data.toJson()),
          ));
  static Future<bool> tryClearFromLocalStorage(E621AccessData data) =>
      pref.getItemAsync().then((v) => v.setString(localStorageKey, ""));

  static Future<bool> tryWrite([E621AccessData? data]) async {
    // ignore: deprecated_member_use_from_same_package
    data ??= userData.$Safe;
    if (data != null) {
      if (Platform.isWeb) {
        logger.info("Can't access file storage on web. "
            "Attempting with Local Storage.");
        return tryWriteToLocalStorage(data);
      }
      if (!data.isAssigned) {
        logger.warning(
            "data.file.isAssigned was false. Attempting initialization");
        await data.initStorageAsync(filePathFull.getItem()).onError(
              (e, s) => logger.warning("Failed to initialize Storable", e, s),
            );
      }
      return data.tryWriteAsync(flush: true)
        ..then<void>((v) {
          if (!v) _failedToDoIoLog(data);
        });
    } else {
      _failedToDoIoLog(data);
      return false;
    }
  }

  static Future<bool> tryClear([E621AccessData? data]) async {
    // ignore: deprecated_member_use_from_same_package
    data ??= userData.$Safe;
    if (data != null) {
      if (Platform.isWeb) {
        logger.info("Can't access file storage on web. "
            "Attempting with Local Storage.");
        return tryClearFromLocalStorage(data);
      }
      if (!data.isAssigned) {
        logger.warning(
            "data.file.isAssigned was false. Attempting initialization");
        await data.initStorageAsync(filePathFull.getItem()).onError(
              (e, s) => logger.warning("Failed to initialize Storable", e, s),
            );
      }
      return data.tryClearAsync(/* flush: true */)
        ..then<void>((v) {
          if (!v) _failedToDoIoLog(data, "clear");
        });
    } else {
      _failedToDoIoLog(data);
      return false;
    }
  }

  Future<bool> tryClearSelf() async {
    if (Platform.isWeb) {
      logger.info("Can't access file storage on web. "
          "Attempting with Local Storage.");
      return tryClearFromLocalStorage(this);
    }
    if (!isAssigned) {
      logger.warning("file.isAssigned was false. Attempting initialization");
      await initStorageAsync(filePathFull.getItem()).onError(
        (e, s) => logger.warning("Failed to initialize Storable", e, s),
      );
    }
    return tryClearAsync(/* flush: true */)
      ..then<void>((v) {
        if (!v) _failedToDoIoLog(this, "clear");
      });
  }

  static final E621AccessData errorData = E621AccessData.nonSaved(
    apiKey: "INVALID",
    username: "INVALID",
    userAgent: "INVALID",
  );
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
    !Platform.isWeb
        ? initStorageAsync(filePathFull.getItem()).onError(
            (e, s) => logger.log(
                Platform.isWeb ? lm.LogLevel.FINEST : lm.LogLevel.WARNING,
                "Failed to initialize Storable",
                e,
                s),
          )
        : pref.$Safe;
  }
  /* const  */ E621AccessData.nonSaved({
    required this.apiKey,
    required this.username,
    required this.userAgent,
  });
  factory E621AccessData.withDefault({
    required String apiKey,
    required String username,
    String? userAgent,
  }) =>
      E621AccessData(
          apiKey: apiKey,
          username: username,
          userAgent: userAgent ??
              "fuzzy/${version.$Safe} by atotaltirefire@gmail.com");
  static Future<E621AccessData> withDefaultAssured({
    required String apiKey,
    required String username,
    String? userAgent,
  }) async =>
      E621AccessData(
          apiKey: apiKey,
          username: username,
          userAgent: userAgent ??
              "fuzzy/${await version.getItem()} by atotaltirefire@gmail.com");
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
