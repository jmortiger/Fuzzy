import 'package:flutter/material.dart';

class ErrorPage extends StatelessWidget {
  final dynamic error;
  final StackTrace? stackTrace;
  const ErrorPage({super.key, this.error, this.stackTrace});

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
