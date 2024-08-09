import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;

class ErrorPage extends StatelessWidget {
  final dynamic error;
  final StackTrace? stackTrace;
  factory ErrorPage({
    Key? key,
    required dynamic error,
    required StackTrace? stackTrace,
    required lm.FileLogger logger,
    Object? message,
    // lm.LogLevel level = lm.LogLevel.SEVERE,
  }) =>
      ErrorPage.logError(
        error: error,
        stackTrace: stackTrace,
        logger: logger,
        message: message,
      );
  const ErrorPage.makeConst({
    super.key,
    required this.error,
    required this.stackTrace,
  });
  ErrorPage.logError({
    super.key,
    required this.error,
    required this.stackTrace,
    required lm.FileLogger logger,
    Object? message,
    // lm.LogLevel level = lm.LogLevel.SEVERE,
  }) {
    logger.severe(message ?? error, error, stackTrace);
  }

  /// If an error occurs, logs the error with the given [logger] and pushes an [ErrorPage] onto the navigator, then rethrows the error.
  static RT? errorCatcher<RT>(
    RT Function() task, {
    required BuildContext context,
    required lm.FileLogger logger,
    Object? message,
  }) {
    try {
      return task();
    } catch (e, s) {
      logger.severe(message ?? e, e, s);
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ErrorPage.makeConst(error: e, stackTrace: s),
          ));
      return null;
    }
  }

  /// If an error occurs, logs the error with the given [logger] and returns an [ErrorPage] representing the error, then rethrows the error.
  static ({
    RT? value,
    Object? e,
    StackTrace? s,
    ErrorPage? page,
  }) errorWrapper<RT>(
    RT Function() task, {
    required lm.FileLogger logger,
    Object? message,
  }) {
    try {
      return (
        value: task(),
        e: null as Object?,
        s: null as StackTrace?,
        page: null as ErrorPage?,
      );
    } catch (e, s) {
      logger.severe(message ?? e, e, s);
      return (
        value: null,
        e: e,
        s: s,
        page: ErrorPage.makeConst(error: e, stackTrace: s),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: SelectableText(error.runtimeType.toString())),
        body: ListView(
          children: [
            SelectableText("ERROR: $error"),
            SelectableText("StackTrace: $stackTrace"),
          ],
        ),
      ),
    );
  }
}
