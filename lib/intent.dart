import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:j_util/collections.dart';
import 'package:j_util/events.dart';
import 'package:j_util/platform_finder.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/util/util.dart' as util;

// ignore: unnecessary_late
late final _logger = lm.generateLogger("Intent").logger;
@Event(name: "IntentReceived")
// ignore: unnecessary_late
late final intentEvent = JEvent<IntentEventArgs>(
    [(a) => a.handleShareIntent() != null ? intentRouteEvent.invoke(a) : ""]);
@Event(name: "IntentRouteReceived")
// ignore: unnecessary_late
late final intentRouteEvent = JEvent<IntentEventArgs>();
late StreamSubscription<List<SharedFile>> intentDataStreamSubscription;
final requestedUrls = ListNotifier<Uri>.empty(growable: true);

/// Must be after
/// * `WidgetsFlutterBinding.ensureInitialized();` (I believe)
Future<String?> initIntentHandling() async {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  // intentDataStreamSubscription =
  //     FlutterSharingIntent.instance.getMediaStream().listen(handleShareIntent);
  intentDataStreamSubscription = FlutterSharingIntent.instance
      .getMediaStream()
      .listen(IntentEventArgs.buildAndFire);
  return handleShareIntent(
      await FlutterSharingIntent.instance.getInitialSharing());
}

String? handleShareIntent(
  List<SharedFile> results, {
  bool returnParseFailures = false,
}) {
  var t = results.firstOrNull;
  switch ((t?.type, t?.value)) {
    case (SharedMediaType.URL, String? t):
    case (SharedMediaType.TEXT, String? t):
      _logger.fine("Share intent received: $t");
      final u = t != null ? Uri.tryParse(t) : null;
      if (u != null) {
        requestedUrls.add(u);
        return t;
      } else {
        _logger.warning("Failed parsing: $t failed to parse; "
            "${returnParseFailures ? "returning anyways" : "not returning"}");
        return returnParseFailures ? t : null;
      }
    case (null, _):
    default:
      _logger.info("Share not handled ${t?.type} $t");
      return null;
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

class IntentRouter extends StatefulWidget {
  final Widget? child;
  const IntentRouter({super.key, this.child});

  @override
  State<IntentRouter> createState() => _IntentRouterState();
}

class _IntentRouterState extends State<IntentRouter> {
  @override
  void initState() {
    super.initState();
    intentRouteEvent.subscribe(onReceived);
  }

  @override
  void dispose() {
    intentRouteEvent.unsubscribe(onReceived);
    super.dispose();
  }

  @EventListener(event: "IntentRouteReceived")
  void onReceived(IntentEventArgs a) => Navigator.pushNamed(context, a.text!);

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

class IntentEventArgs extends JEventArgs {
  final List<SharedFile> results;
  String? get text => handleShareIntent();
  String? get textRaw => results.firstOrNull?.value;
  Uri? get url => Uri.tryParse(textRaw ?? "::Not valid URI::");
  String? get urlCheckedText => url != null ? textRaw : null;
  const IntentEventArgs(this.results);
  factory IntentEventArgs.buildAndFire(
    List<SharedFile> results, [
    JEvent<IntentEventArgs>? event,
  ]) {
    final r = IntentEventArgs(results);
    (event ?? intentEvent).invoke(r);
    return r;
  }
  String? handleShareIntent({bool returnParseFailures = false}) {
    var t = results.firstOrNull;
    switch ((t?.type, t?.value)) {
      case (SharedMediaType.URL, String? t):
      case (SharedMediaType.TEXT, String? t):
        _logger.fine("Share intent received: $t");
        final u = t != null ? Uri.tryParse(t) : null;
        if (u != null) {
          // requestedUrls.add(u);
          return t;
        } else {
          _logger.warning("Failed parsing: $t failed to parse; "
              "${returnParseFailures ? "returning anyways" : "not returning"}");
          return returnParseFailures ? t : null;
        }
      case (null, _):
      default:
        _logger.info("Share not handled ${t?.type} $t");
        return null;
    }
  }
}
