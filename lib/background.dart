// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final logger =
        await lm.init().then((v) => lm.generateLogger("background").logger);
    try {
      switch (taskName) {
        case SubscriptionManager.batchTaskName:
          SubscriptionManager.initAndCheckSubscriptions(logger: logger);
          break;
      }
      return Future.value(true);
    } catch (e, s) {
      logger.severe(e, e, s);
      return Future.value(false);
    }
  });
}

/// Must be after
/// * `WidgetsFlutterBinding.ensureInitialized();` (I believe)
///
/// TODO: Notifications
Future<void> init() async {
  // await flutterLocalNotificationsPlugin.initialize(initializationSettings,
  //     onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
  await Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
      SubscriptionManager.batchTaskName, SubscriptionManager.batchTaskName,
      frequency: SubscriptionManager.frequency,
      existingWorkPolicy: ExistingWorkPolicy.replace);
}

final registerOneOffTask = Workmanager().registerOneOffTask;
final registerPeriodicTask = Workmanager().registerPeriodicTask;

// FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();
// // initialize the plugin. app_icon needs to be a added as a drawable resource to the Android head project
// const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('app_icon');
// final DarwinInitializationSettings initializationSettingsDarwin =
//     DarwinInitializationSettings(
//         onDidReceiveLocalNotification: onDidReceiveLocalNotification);
// final LinuxInitializationSettings initializationSettingsLinux =
//     LinuxInitializationSettings(defaultActionName: 'Open notification');
// final InitializationSettings initializationSettings = InitializationSettings(
//   android: initializationSettingsAndroid,
//   iOS: initializationSettingsDarwin,
//   macOS: initializationSettingsDarwin,
//   linux: initializationSettingsLinux,
// );
// void onDidReceiveLocalNotification(
//     int id, String? title, String? body, String? payload) {}

// void onDidReceiveNotificationResponse(NotificationResponse details) {}
