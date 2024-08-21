import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:j_util/platform_finder.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

lm.Printer get _print => _lRecord.print;
lm.FileLogger get _logger => _lRecord.logger;
// ignore: unnecessary_late
late final _lRecord = lm.generateLogger("Intent");
// #endregion Logger
// import 'package:app_links/app_links.dart';

// final _appLinks = AppLinks(); // AppLinks is singleton
// late StreamSubscription<Uri> linkSubscription;
late StreamSubscription<List<SharedFile>> intentDataStreamSubscription;
final List<Uri> requestedUrls = [];

Future<void> initIntentHandling() async {
  if (Platform.isAndroid) {
    // final _navigatorKey = GlobalKey<NavigatorState>();

    // Subscribe to all events (initial link and further)
    // linkSubscription = _appLinks.uriLinkStream.listen((uri) {
    //   // Do something (navigation, ...)
    //   // _navigatorKey.currentState?.pushNamed(uri.fragment);
    //   requestedUrls.add(uri);
    //   print(uri);
    // });
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
      if (u != null) requestedUrls.add(u);
      _print("Failed parsing");
      break;
    case null:
    default:
      _print("Share not handled");
  }
}

bool checkAndLaunch(BuildContext context) {
  if (requestedUrls.isNotEmpty) {
    final u = requestedUrls.removeAt(0);
    final uFormatted = Uri(path: u.path, query: u.query);
    _print("navigating to ${u.toString()} (${uFormatted.toString()})");
    Navigator.pushNamed(context, uFormatted.toString());
    // ScaffoldMessenger.of(context)
    //   ..hideCurrentSnackBar()
    //   ..showSnackBar(SnackBar(content: Text(u.toString())));
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
