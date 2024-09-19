// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';
import 'package:logging/logging.dart';

import 'util/util.dart' as f_util;
import 'package:http/http.dart' as http;

typedef LogLevel = Level;
typedef Printer = void Function(Object? message,
    [LogLevel logLevel, Object? error, StackTrace? stackTrace, Zone? zone]);
const logFileExt = ".txt";
void Function(Object? message,
    [LogLevel logLevel,
    Object? error,
    StackTrace? stackTrace,
    Zone? zone]) genPrint(
  String fileName, [
  String? className,
  Level level = Level.INFO,
]) =>
    generateLogger(fileName, className: className, level: level).print;
// @Deprecated("Use generateLogger")
// ({Printer print, FileLogger logger}) generateLogger(
//   String fileName, [
//   String? className,
//   Level level = Level.INFO,
//   bool overrideLevelForMobile = true,
// ]) {
//   final l = FileLogger(
//     className ?? fileName,
//     "$fileName.txt",
//     overrideLevelForMobile && !Platform.isDesktop ? Level.ALL : level,
//   );
//   // l.$.level = level ?? Level.INFO;
//   return (
//     print: (Object? message,
//             [LogLevel logLevel = Level.FINEST,
//             Object? error,
//             StackTrace? stackTrace,
//             Zone? zone]) =>
//         l.log(logLevel, message, error, stackTrace, zone),
//     logger: l
//   );
// }
({Printer print, FileLogger logger}) generateLogger(
  String fileName, {
  String? className,
  Level level = Level.INFO,
  bool overrideLevelForMobile = true,
}) {
  final l = FileLogger(
    className ?? fileName,
    "$fileName.txt",
    overrideLevelForMobile && !Platform.isDesktop ? Level.ALL : level,
  );
  // l.$.level = level ?? Level.INFO;
  return (
    print: (Object? message,
            [LogLevel logLevel = Level.FINEST,
            Object? error,
            StackTrace? stackTrace,
            Zone? zone]) =>
        l.log(logLevel, message, error, stackTrace, zone),
    logger: l
  );
}

final logPath = LazyInitializer.immediate(logsPathInit);
Future<String> logsPathInit() async {
  print("logsPathInit called");
  try {
    return Platform.isWeb ? "" : "${await f_util.appDataPath.getItem()}/logs/";
  } catch (e) {
    print("Error in LogManagement.logsPathInit():\n$e");
    return "";
  }
}

const mainFileName = "main";
final mainFile = LateFinal<File?>();
Future<void> init() async {
  hierarchicalLoggingEnabled = true;
  await logPath.getItemAsync().then(
        (v) => Platform.isWeb
            ? null
            : Storable.handleInitStorageAsync(
                "$v$mainFileName-${DateTime.timestamp().toIso8601DateString()}$logFileExt",
              )
          ?..onError(
            (error, stackTrace) => mainFile.$ = null,
          )
          ..then((v2) {
            mainFile.$ = v2;
            return v2?.writeAsString(
                  "\n${DateTime.timestamp().toIso8601String()}",
                  mode: FileMode.append,
                ) ??
                Future.sync(() => null);
          }),
      );
  if (mainFile.$Safe != null) {
    Logger.root.onRecord.listen(
      (event) {
        mainFile.$?.writeAsString(event.message, mode: FileMode.append);
      },
    );
  } else {
    Logger.root.onRecord.listen(
      (e) {
        dev.log(
          e.message,
          time: e.time,
          sequenceNumber: e.sequenceNumber,
          error: e.error,
          level: e.level.value,
          name: e.loggerName,
          stackTrace: e.stackTrace,
          zone: e.zone,
        );
        // mainFile?.writeAsString(e.message, mode: FileMode.append);
      },
    );
  }
}

class FileLogger implements Logger {
  final Logger $;
  final file = LateFinal<File?>();
  FileLogger(
    String name,
    String? fileName, [
    Level level = Level.FINE,
  ]) : $ = Logger(name) /* ,
        _levelOverride = level */
  {
    $.level = Platform.isAndroid ? Level.ALL : level;
    _init(name, fileName);
    $.onRecord.listen(onRecordEvent);
  }
  FileLogger.detached(
    String name, [
    String? fileName,
    Level level = Level.FINE,
  ]) : $ = Logger.detached(name) /* ,
        _levelOverride = level */
  {
    $.level = Platform.isAndroid ? Level.ALL : level;
    _init(name, fileName);
    $.onRecord.listen(onRecordEvent);
  }
  Future<File?> _init(String name, [String? fileName]) =>
      logPath.getItemAsync().then((String v) => Platform.isWeb
          ? null
          : Storable.handleInitStorageAsync("$v${fileName ?? "$name.txt"}")
        ?..then((v2) {
          file.$ = v2;
          return v2?.writeAsString(
                "\n${DateTime.timestamp().toIso8601String()}",
                mode: FileMode.append,
              ) ??
              Future.sync(() => null);
        }).onError((error, stackTrace) => file.$ = null));
  void onRecordEvent(LogRecord e) {
    file.$Safe?.writeAsString(
      "${e.time.toLocal().toIso8601String()} "
      "[${e.level.toString().toUpperCase()}]: "
      "${e.message}\n",
      mode: FileMode.append,
    );
    // dev.log(
    //   e.message,
    //   time: e.time,
    //   sequenceNumber: e.sequenceNumber,
    //   error: e.error,
    //   level: e.level.value,
    //   name: e.loggerName,
    //   stackTrace: e.stackTrace,
    //   zone: e.zone,
    // );
  }

  // Level _levelOverride;

  // #region Overrides
  @override
  Level get level => $.level;
  // Level get level => _levelOverride; //$.level;
  @override
  set level(Level? v) => $.level = v;
  // set level(Level? v) {
  //   if (v != null) _levelOverride = v;
  //   if (!Platform.isAndroid) $.level = v;
  // }

  @override
  Map<String, Logger> get children => $.children;

  @override
  String get fullName => $.fullName;

  @override
  String get name => $.name;

  @override
  Stream<Level?> get onLevelChanged => $.onLevelChanged;

  @override
  Stream<LogRecord> get onRecord => $.onRecord;

  @override
  Logger? get parent => $.parent;

  @override
  bool isLoggable(Level value) => $.isLoggable(value);
  // bool isLoggable(Level value) => value >= _levelOverride;

  @override
  void clearListeners() => $.clearListeners();

  @override
  void config(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.config(message, error, stackTrace);

  @override
  void fine(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.fine(message, error, stackTrace);

  @override
  void finer(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.finer(message, error, stackTrace);

  @override
  void finest(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.finest(message, error, stackTrace);

  @override
  void info(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.info(message, error, stackTrace);

  @override
  void log(
    Level logLevel,
    Object? message, [
    Object? error,
    StackTrace? stackTrace,
    Zone? zone,
  ]) =>
      $.log(logLevel, message, error, stackTrace, zone);
  // isLoggable(logLevel)
  //     ? $.log(logLevel, message, error, stackTrace, zone)
  //     : onRecordEvent(LogRecord(
  //         logLevel,
  //         message?.toString() ?? "",
  //         name,
  //       ));

  @override
  void severe(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.severe(message, error, stackTrace);

  @override
  void shout(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.shout(message, error, stackTrace);

  @override
  void warning(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.warning(message, error, stackTrace);
  // #endregion Overrides
}

// #region Logging Helpers
void logRequest(
  http.BaseRequest r,
  Logger logger, [
  Level level = Level.FINEST,
]) {
  logger.log(
    level,
    "${switch (r) {
      http.Request _ => "",
      http.StreamedRequest _ => "Streamed",
      http.MultipartRequest _ => "Multipart",
      _ => "Base",
    }}Request:"
    "\n\t$r"
    "\n\t${r.url}"
    "\n\t${r.url.query}"
    "${r is http.Request ? "\n\t${r.body}" : ""}"
    "\n\t${r.headers}",
  );
}

@Deprecated("Use logResponseSmart")
void logResponse(
  http.BaseResponse r,
  Logger logger, [
  Level level = Level.FINEST,
]) {
  logger.log(
    level,
    "${switch (r) {
      http.Response _ => "",
      http.StreamedResponse _ => "Streamed",
      _ => "Base",
    }}Response:"
    "\n\t$r"
    "${r is http.Response ? "\n\t${r.body}" : ""}"
    "\n\t${r.statusCode}"
    "\n\t${r.reasonPhrase}"
    "\n\t${r.headers}",
  );
}

void logResponseSmart(
  http.BaseResponse r,
  Logger logger, {
  Level baseLevel = Level.FINEST,
  Level nonSuccessLevel = Level.WARNING,
  Level errorLevel = Level.SEVERE,
  Level? overrideLevel,
}) {
  logger.log(
    overrideLevel ??
        (r.statusCodeInfo.isError
            ? errorLevel
            : r.statusCodeInfo.isSuccessful
                ? baseLevel
                : nonSuccessLevel),
    "${switch (r) {
      http.Response _ => "",
      http.StreamedResponse _ => "Streamed",
      _ => "Base",
    }}Response:"
    "\n\t$r"
    "${r is http.Response ? "\n\t${r.body}" : ""}"
    "\n\t${r.statusCode}"
    "\n\t${r.reasonPhrase}"
    "\n\t${r.headers}",
  );
}

extension LogReq on http.BaseRequest {
  void log(
    Logger logger, [
    Level level = Level.FINEST,
  ]) {
    logger.log(
      level,
      "${switch (this) {
        http.Request _ => "",
        http.StreamedRequest _ => "Streamed",
        http.MultipartRequest _ => "Multipart",
        _ => "Base",
      }}Request:"
      "\n\t$this"
      "\n\t$url"
      "\n\t${url.query}"
      "${this is http.Request ? "\n\t${(this as http.Request).body}" : ""}"
      "\n\t$headers",
    );
  }
}

extension LogRes on http.BaseResponse {
  void log(
    Logger logger, {
    Level baseLevel = Level.FINEST,
    Level nonSuccessLevel = Level.WARNING,
    Level errorLevel = Level.SEVERE,
    Level? overrideLevel,
  }) {
    logger.log(
      overrideLevel ??
          (statusCodeInfo.isError
              ? errorLevel
              : statusCodeInfo.isSuccessful
                  ? baseLevel
                  : nonSuccessLevel),
      "${switch (this) {
        http.Response _ => "",
        http.StreamedResponse _ => "Streamed",
        _ => "Base",
      }}Response:"
      "\n\t$this"
      "${this is http.Response ? "\n\t${(this as http.Response).body}" : ""}"
      "\n\t$statusCode"
      "\n\t$reasonPhrase"
      "\n\t$headers",
    );
  }
}
// #endregion Logging Helpers
