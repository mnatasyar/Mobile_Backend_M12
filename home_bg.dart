import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'foreground',
    'Foreground Service',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'foreground',
      initialNotificationTitle: 'Foreground Service',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  int sum = 60;
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    sum--;
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Countdown Service',
          'Remaining ${sum} times ...',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'foreground',
              'Foreground Service',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }

    print('Background Service: ${sum}');

    service.invoke(
      'update',
      {
        "count": sum,
      },
    );

    if (sum <= 0) {
      service.stopSelf(); // Stop the service when countdown reaches 0 or negative value
      timer.cancel(); // Stop the timer
    }
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String text = "Stop Service";
  bool isChangingColor = false;
  late Timer colorChangeTimer;
  Color currentColor = Colors.white;

  void startColorChange() {
    colorChangeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        currentColor = _randomColor();
      });
    });
  }

  Color _randomColor() {
    final Random random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1.0,
    );
  }

  @override
  void dispose() {
    colorChangeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Countdown Service")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StreamBuilder<Map<String, dynamic>?>(
              // ... (stream builder)
            ),
            ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                if (isRunning) {
                  service.invoke("stopService");
                  text = 'Restart Service';
                } else {
                  service.startService();
                  text = 'Stop Service';
                }
                setState(() {});
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text(isChangingColor ? 'Stop Changing Color' : 'Change Color'),
              onPressed: () {
                setState(() {
                  if (isChangingColor) {
                    colorChangeTimer.cancel();
                    isChangingColor = false;
                  } else {
                    isChangingColor = true;
                    startColorChange();
                  }
                });
              },
            ),
          ],
        ),
      ),
      backgroundColor: isChangingColor ? currentColor : Colors.white,
    );
  }
}