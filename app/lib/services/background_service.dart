import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:night_vigil/services/location_service.dart';
import 'package:night_vigil/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This is the entry point for the foreground service isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  final locationService = LocationService();
  final notificationService = NotificationService();
  notificationService.initialize();

  print('Background Service Started');

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(minutes: 25), (timer) async {
    print("--- Background location check running ---");
    final prefs = await SharedPreferences.getInstance();
    
    final double? lat = prefs.getDouble('activeDutyLat');
    final double? lon = prefs.getDouble('activeDutyLon');
    final double? radius = prefs.getDouble('activeDutyRadius');

    if (lat != null && lon != null && radius != null) {
      try {
        final position = await locationService.getCurrentLocation();
        final distance = Geolocator.distanceBetween(lat, lon, position.latitude, position.longitude);
        
        print("Current distance from duty center: ${distance}m");

        if (distance > radius) {
          print("ALERT: User is outside the duty radius!");
          await notificationService.showLocationAlert();
        }
      } catch (e) {
        print("Error in background location check: $e");
      }
    } else {
      print("No active duty found. Stopping service.");
      service.stopSelf();
    }
  });
}

// --- THIS IS THE FIX for iOS ---
// Create a separate background handler that returns a boolean.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}


Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'night_vigil_service',
      initialNotificationTitle: 'Night Vigil Service',
      initialNotificationContent: 'Monitoring duty location.',
      foregroundServiceNotificationId: 888,
    ),
    // --- THIS IS THE FIX ---
    // The onBackground handler must return a Future<bool>
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground, // Use the new handler here
      autoStart: false,
    ),
  );
}