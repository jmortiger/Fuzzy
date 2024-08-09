// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:j_util/j_util_full.dart';
import 'package:j_util/serialization.dart';
import 'package:logging/logging.dart';

import 'util/util.dart' as f_util;

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
    genLogger(fileName, className, level).print;

({Printer print, FileLogger logger}) genLogger(
  String fileName, [
  String? className,
  Level level = Level.INFO,
  bool overrideLevelForMobile = true,
]) {
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
  await logPath.getItem().then(
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
  ]) : $ = Logger(name) {
    $.level = level;
    logPath.getItem().then(
          (v) => Platform.isWeb
              ? null
              : Storable.handleInitStorageAsync("$v$fileName")
            ?..then((v2) {
              file.$ = v2;
              return v2?.writeAsString(
                    "\n${DateTime.timestamp().toIso8601String()}",
                    mode: FileMode.append,
                  ) ??
                  Future.sync(() => null);
            }).onError(
              (error, stackTrace) => file.$ = null,
            ),
        );
    $.onRecord.listen(
      (e) {
        file.$Safe?.writeAsString(
            "${e.time.toLocal().toIso8601String()} [${e.level.toString().toUpperCase()}]: ${e.message}\n",
            mode: FileMode.append);
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
      },
    );
  }
  FileLogger.detached(String name, String? fileName)
      : $ = Logger.detached(name) {
    logPath.getItem().then(
          (v) => Platform.isWeb
              ? null
              : Storable.handleInitStorageAsync("$v$fileName")
            ?..then((v2) {
              file.$ = v2;
              return v2?.writeAsString(
                    "\n${DateTime.timestamp().toIso8601String()}",
                    mode: FileMode.append,
                  ) ??
                  Future.sync(() => null);
            }),
        );
    $.onRecord.listen(
      (event) {
        file.$Safe?.writeAsString(event.message, mode: FileMode.append);
      },
    );
  }

  // #region Overrides
  @override
  Level get level => $.level;
  @override
  set level(Level? v) => $.level = v;

  @override
  Map<String, Logger> get children => $.children;

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
  String get fullName => $.fullName;

  @override
  void info(Object? message, [Object? error, StackTrace? stackTrace]) =>
      $.info(message, error, stackTrace);

  @override
  bool isLoggable(Level value) => $.isLoggable(value);

  @override
  void log(Level logLevel, Object? message,
          [Object? error, StackTrace? stackTrace, Zone? zone]) =>
      $.log(logLevel, message, error, stackTrace, zone);

  @override
  String get name => $.name;

  @override
  Stream<Level?> get onLevelChanged => $.onLevelChanged;

  @override
  Stream<LogRecord> get onRecord => $.onRecord;

  @override
  Logger? get parent => $.parent;

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
