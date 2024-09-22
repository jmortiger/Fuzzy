import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:j_util/collections.dart';
import 'package:j_util/platform_finder.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/util/util.dart' as util;

// #region Logger
lm.Printer get _print => _lRecord.print;
lm.FileLogger get _logger => _lRecord.logger;
// ignore: unnecessary_late
late final _lRecord = lm.generateLogger("Intent");
// #endregion Logger

late StreamSubscription<List<SharedFile>> intentDataStreamSubscription;
final requestedUrls = ListNotifier<Uri>.empty(true);

Future<void> initIntentHandling() async {
  if (Platform.isAndroid) {
    handleShareIntent(await FlutterSharingIntent.instance.getInitialSharing());
    intentDataStreamSubscription = FlutterSharingIntent.instance
        .getMediaStream()
        .listen(handleShareIntent);
  }
}

void handleShareIntent(List<SharedFile> f) {
  var t = f.firstOrNull;
  switch (t?.type) {
    case SharedMediaType.URL:
    case SharedMediaType.TEXT:
      _print("Share intent received: ${t!.value}");
      final u = Uri.tryParse(t.value!);
      if (u != null) {
        requestedUrls.add(u);
      } else {
        _logger.warning("Failed parsing: ${t.value} failed to parse");
      }
      break;
    case null:
    default:
      _logger.info("Share not handled ${t?.type} $t");
  }
}

bool checkAndLaunch(BuildContext context) {
  if (requestedUrls.isNotEmpty) {
    final u = requestedUrls.removeAt(0);
    final uFormatted = Uri(path: u.path, query: u.query);
    final message = "Navigating to ${u.toString()} (${uFormatted.toString()})";
    _logger.info(message);
    util.showUserMessage(context: context, content: Text(message));
    Navigator.pushNamed(context, uFormatted.toString());
    // showDialog(
    //   context: context,
    //   builder: (context) {
    //     return AlertDialog(
    //       content: ,
    //     );
    //   },
    // );
    return true;
  } else {
    return false;
  }
}
