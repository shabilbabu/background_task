import 'dart:convert';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_background/firebase_options.dart';
import 'package:task_background/notification_service.dart';
import 'package:workmanager/workmanager.dart';

const String _serverToken = 'AAAAJjM1rQs:APA91bHYUUTA5nIBBfvR_nJ5oHck8pns5wP0gGWnIXOzk_r9c-ntuh6COvB15DTCh1tTSY9c6DUtlKzKJmypVhqnOCvMOYx1gavCn4wnx2_4Z1FVPaiNyWgC3sVano3EdQaT29D2JzWu';
const String _fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';

Future<bool> _handleLocationPermission() async {
  PermissionStatus? status;
  status = await Permission.location.request();
  log('Status print : $status');
  if (status == PermissionStatus.granted) {
    return true;
  } else if (status == PermissionStatus.denied) {
    // Permissions are denied, try requesting permissions again
    return false;
  } else if (status == PermissionStatus.permanentlyDenied) {
    // Permissions are permanently denied, navigate to settings
    await openAppSettings();
    return false;
  }

  return false;
}

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    ///Making shared pref instance for get firebase token
    final local = await SharedPreferences.getInstance();

    ///Get firebase token for sent notification
    final token = local.getString('firebase_token');

    ///If there is no token can't make background execution
    if (token?.isEmpty ?? false) {
      return false;
    }

    log('call back -> firebase token is : $token');

    ///Taking user current location for send to firebse
    final position = Position(
      longitude: 123,
      latitude: 123,
      timestamp: DateTime.now(),
      accuracy: 32,
      altitude: 32,
      altitudeAccuracy: 32,
      heading: 32,
      headingAccuracy: 2,
      speed: 32,
      speedAccuracy: 32,
    );

    try {
      // final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      log('call back -> location is : ${position.latitude} ${position.longitude}');

      final res = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverToken',
        },
        body: jsonEncode(
          {
            'notification': {
              'body': 'location : ${position.latitude} ${position.longitude}',
              'title': 'Location',
            },
            'priority': 'high',
            'to': token,
          },
        ),
      );
      log('call back -> response statusCode : ${res.statusCode}');
      log('call back -> response body : ${res.body}');
    } catch (e) {
      log('call back -> error is : $e');
    }

    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ///Initializing work manager for handling periodic tasks
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

enum AppState { laoding, failed, success }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppState appState = AppState.laoding;

  late final SharedPreferences _local;

  @override
  void initState() {
    _init();
    super.initState();
  }

  Future<void> _init() async {
    /// Initial State
    setState(() => appState = AppState.laoding);

    ///Get firebase token
    final token = await FirebaseMessaging.instance.getToken();

    ///Handling permissions
    final locationPermission = await _handleLocationPermission();
    final notificationPermission = await NotificationServices.handlePermission();

    ///If there is no permission and firebase token  -> Make state to failed state
    if (!notificationPermission || !locationPermission || (token?.isEmpty ?? false)) {
      setState(() => appState = AppState.failed);
      return;
    }

    ///Initializing notification channels
    await NotificationServices.initialize();

    ///Making shared pref instance for store firebase token
    _local = await SharedPreferences.getInstance();

    ///Store firebase token to local for sent notification
    _local.setString('firebase_token', token!);

    /// If all going well -> making state to success
    setState(() => appState = AppState.success);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
            child: switch (appState) {
          AppState.laoding => const CircularProgressIndicator(),
          AppState.failed => ElevatedButton(
              onPressed: () async => await _init(),
              child: const Text('Retry'),
            ),
          AppState.success => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // await Workmanager().registerPeriodicTask(
                    //   'com.fegno.task_background.periodic_unique_name',
                    //   'com.fegno.task_background.periodic_task',
                    //   initialDelay: const Duration(seconds: 30),
                    //   frequency: const Duration(minutes: 15),
                    // );
                    // callBack();
                    await Workmanager().registerOneOffTask(
                      'com.fegno.task_background.periodik_task${DateTime.now().microsecondsSinceEpoch.remainder(100000)}',
                      'Location fetch',
                      initialDelay: const Duration(seconds: 15),
                      // frequency: const Duration(minutes: 15),
                    );
                  },
                  child: const Text('SCHEDULE PERIODIC TASK'),
                ),
              ],
            ),
        }),
      ),
    );
  }
}
