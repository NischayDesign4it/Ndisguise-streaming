import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:haishin_kit/audio_settings.dart';
import 'package:haishin_kit/rtmp_connection.dart';
import 'package:haishin_kit/rtmp_stream.dart';
import 'package:haishin_kit/video_settings.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,

    ),
    iosConfiguration: IosConfiguration(
      // onForeground: onStart,
      // onBackground: onIosBackground,
    ),
  );
  service.startService();
}

void onStart(ServiceInstance service) async {

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('startStreaming').listen((event) async {
    final connection = await RtmpConnection.create(); // Use factory constructor
    final stream = await RtmpStream.create(connection); // Use factory constructor

    // Setup stream settings
    stream.audioSettings = AudioSettings(bitrate: 64 * 1000);
    stream.videoSettings = VideoSettings(
      width: 480,
      height: 272,
      bitrate: 512 * 1000,
    );

    // Start streaming
    stream.publish("live");

    // Handle streaming logic here
    service.on('stopStreaming').listen((event) {
      stream.close();
    });
  });




Timer.periodic(const Duration(seconds: 2), (timer) async{
    print("service is successfully running ${DateTime.now().second}");
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
            title: "Background Service Running ", content: "Update at ${DateTime.now()}");
      }
    }
  });
}






