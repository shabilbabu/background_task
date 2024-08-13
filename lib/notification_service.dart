import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:task_background/channel_key.dart';

///*Manage app notifications
class NotificationServices {
  ///*
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/transparent',
      [
        NotificationChannel(
          channelKey: ChannelKeys.mainChannelKey,
          channelName: 'Main Notifications',
          channelDescription: 'This channel for managing main notifications',
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );
    await _getToken;
    // await iconBadging;
    FirebaseMessaging.onBackgroundMessage(NotificationServices.handleBackGroundMessage);
    _handleForeGroundMessage();
  }

  //* Handle foreground messages from here
  static void _handleForeGroundMessage() {
    FirebaseMessaging.onMessage.listen((msg) async {
      if (msg.notification?.title != null && msg.notification?.body != null) {
        await createNotification(title: msg.notification?.title ?? '', body: '[foreground] ${msg.notification?.body}');
      }
    });
  }

  ///* Handle foreground messages from here
  static Future<void> get _getToken async {
    final token = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      print('FCM Token is : $token');
    }
  }

  ///* Checking notification service .
  ///* If notificat is'nt .It will ask permission
  static Future<bool> handlePermission() async {
    var isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    if (!isAllowed) {
      await openAppSettings();
    }
    return isAllowed;
  }

  ///*
  @pragma('vm:entry-point')
  static Future<void> createNotification({required String title, required String body, String? channelKey}) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().microsecondsSinceEpoch.remainder(100000),
        channelKey: channelKey ?? ChannelKeys.mainChannelKey,
        title: title,
        body: body,
        badge: 12,
      ),
    );
  }

  ///*
  @pragma('vm:entry-point')
  static Future<void> handleBackGroundMessage(RemoteMessage msg) async {
    if (kDebugMode) {
      print('message form firebase [BackGround] : ${msg.notification?.title}');
    }
    await createNotification(title: msg.notification?.title ?? '', body: '[BackGround] ${msg.notification?.body}');
  }

  // ///*
  // static Future<void> get iconBadging async {
  //   // AwesomeNotifications().
  //   await AwesomeNotifications().setGlobalBadgeCounter(10);
  // }

  // ///  *********************************************
  // ///     INITIALIZATION METHODS
  // ///  *********************************************

  // static Future<void> initializeRemoteNotifications() async {
  //   await AwesomeNotificationsFcm().initialize(
  //     onFcmSilentDataHandle: mySilentDataHandle,
  //     onFcmTokenHandle: myFcmTokenHandle,
  //     onNativeTokenHandle: myNativeTokenHandle,
  //     debug: kDebugMode,
  //   );
  // }

  // ///  *********************************************
  // ///     REMOTE NOTIFICATION EVENTS
  // ///  *********************************************

  // /// Use this method to execute on background when a silent data arrives
  // /// (even while terminated)
  // @pragma('vm:entry-point')
  // static Future<void> mySilentDataHandle(FcmSilentData silentData) async {
  //   write('"SilentData": $silentData');

  //   if (silentData.createdLifeCycle != NotificationLifeCycle.Foreground) {
  //     write('bg');
  //   } else {
  //     write('FOREGROUND');
  //   }
  // }

  // /// Use this method to detect when a new fcm token is received
  // @pragma('vm:entry-point')
  // static Future<void> myFcmTokenHandle(String token) async {
  //   write('FCM Token:"$token"');
  // }

  // /// Use this method to detect when a new native token is received
  // @pragma('vm:entry-point')
  // static Future<void> myNativeTokenHandle(String token) async {
  //   write('Native Token:"$token"');
  // }
}
