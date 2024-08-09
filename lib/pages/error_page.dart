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
  const ErrorPage.makeConst(
      {super.key, required this.error, required this.stackTrace});
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: Column(
          children: [
            Text("ERROR: $error"),
            Text("StackTrace: $stackTrace"),
          ],
        ),
      ),
    );
  }
}
