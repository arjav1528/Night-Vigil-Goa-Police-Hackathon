import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/duty_assignment_model.dart';
import 'package:app/api/duty_repository.dart';

class GeofencingService {
  static const String _dutiesKey = 'geofence_duties';
  static const String _lastLocationKey = 'last_location';
  
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late DutyRepository _dutyRepository;
  
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  /// Initialize the geofencing service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _initializeBackgroundService();
    _dutyRepository = DutyRepository(); // Initialize duty repository
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(initSettings);

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Notifications',
      description: 'Notifications for geofence events and duty tracking',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Initialize background service
  Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'geofence_channel',
        initialNotificationTitle: 'Night Vigil',
        initialNotificationContent: 'Geofencing service is running',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Request necessary permissions
  Future<bool> requestPermissions() async {
    try {
      // Request location permissions using geolocator
      LocationPermission locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      
      if (locationPermission == LocationPermission.deniedForever) {
        return false;
      }

      // Request notification permissions using flutter_local_notifications
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // For Android
      final androidPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      // For iOS  
      final iosPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Check if we have at least "when in use" permission
      return locationPermission == LocationPermission.always || 
             locationPermission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  /// Start geofencing with duty assignments
  Future<void> startGeofencing(List<DutyAssignment> duties) async {
    await _saveDutiesToStorage(duties);
    
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    
    if (!isRunning) {
      await service.startService();
    }
    
    // Send duties to background service
    service.invoke('updateDuties', {'duties': _dutiesToJson(duties)});
    
    await showNotification(
      'Geofencing Started',
      'Monitoring ${duties.length} duty areas',
      notificationId: 100,
    );
  }

  /// Stop geofencing (for automatic duty end only)
  Future<void> stopGeofencing() async {
    final service = FlutterBackgroundService();
    service.invoke('stopGeofencing');
    
    bool isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
    
    await _clearDutiesFromStorage();
    
    await showNotification(
      'Duty Completed',
      'Geofencing stopped - Your duty has ended',
      notificationId: 101,
    );
  }

  /// Force stop geofencing (for emergency or system use only)
  Future<void> forceStopGeofencing() async {
    final service = FlutterBackgroundService();
    service.invoke('stopGeofencing');
    
    bool isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
    
    await _clearDutiesFromStorage();
  }

  /// Add a single geofence for a new duty
  Future<void> addGeofence(DutyAssignment duty) async {
    // Update stored duties
    final prefs = await SharedPreferences.getInstance();
    final String? dutiesJson = prefs.getString(_dutiesKey);
    List<DutyAssignment> duties = [];
    
    if (dutiesJson != null) {
      final List<dynamic> dutiesList = json.decode(dutiesJson);
      duties = dutiesList.map((e) => DutyAssignment.fromJson(e)).toList();
    }
    
    duties.add(duty);
    await _saveDutiesToStorage(duties);
    
    // Update background service
    final service = FlutterBackgroundService();
    service.invoke('updateDuties', {'duties': _dutiesToJson(duties)});
  }

  /// Remove a geofence
  Future<void> removeGeofence(String dutyId) async {
    // Update stored duties
    final prefs = await SharedPreferences.getInstance();
    final String? dutiesJson = prefs.getString(_dutiesKey);
    
    if (dutiesJson != null) {
      final List<dynamic> dutiesList = json.decode(dutiesJson);
      List<DutyAssignment> duties = dutiesList.map((e) => DutyAssignment.fromJson(e)).toList();
      duties.removeWhere((duty) => duty.id == dutyId);
      await _saveDutiesToStorage(duties);
      
      // Update background service
      final service = FlutterBackgroundService();
      service.invoke('updateDuties', {'duties': _dutiesToJson(duties)});
    }
  }

  /// Save duties to local storage
  Future<void> _saveDutiesToStorage(List<DutyAssignment> duties) async {
    final prefs = await SharedPreferences.getInstance();
    final dutiesJson = _dutiesToJson(duties);
    await prefs.setString(_dutiesKey, json.encode(dutiesJson));
  }

  /// Convert duties to JSON
  List<Map<String, dynamic>> _dutiesToJson(List<DutyAssignment> duties) {
    return duties.map((duty) => {
      'id': duty.id,
      'location': duty.location,
      'latitude': duty.latitude,
      'longitude': duty.longitude,
      'radius': duty.radius,
      'startTime': duty.startTime.toIso8601String(),
      'endTime': duty.endTime.toIso8601String(),
      'status': duty.status,
    }).toList();
  }

  /// Clear duties from storage
  Future<void> _clearDutiesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dutiesKey);
  }

  /// Get duties from storage
  Future<List<DutyAssignment>> getDutiesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dutiesJson = prefs.getString(_dutiesKey);
    
    if (dutiesJson == null) return [];
    
    final List<dynamic> dutiesList = json.decode(dutiesJson);
    return dutiesList.map((e) => DutyAssignment.fromJson(e)).toList();
  }

  /// Check if user is within duty area
  Future<bool> isWithinDutyArea(DutyAssignment duty, Position currentPosition) async {
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      duty.latitude,
      duty.longitude,
    );
    
    return distance <= duty.radius;
  }

  /// Check if geofencing is currently running
  Future<bool> get isRunning async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Show notification
  Future<void> showNotification(String title, String body, {required int notificationId}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications for geofence events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      ongoing: false,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
    );
  }

  /// Get last known location
  Future<Position?> getLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationString = prefs.getString(_lastLocationKey);
    
    if (locationString != null) {
      final locationData = json.decode(locationString);
      return Position(
        latitude: locationData['latitude'],
        longitude: locationData['longitude'],
        timestamp: DateTime.parse(locationData['timestamp']),
        accuracy: locationData['accuracy'] ?? 0.0,
        altitude: locationData['altitude'] ?? 0.0,
        altitudeAccuracy: locationData['altitudeAccuracy'] ?? 0.0,
        heading: locationData['heading'] ?? 0.0,
        headingAccuracy: locationData['headingAccuracy'] ?? 0.0,
        speed: locationData['speed'] ?? 0.0,
        speedAccuracy: locationData['speedAccuracy'] ?? 0.0,
        isMocked: locationData['isMocked'] ?? false,
      );
    }
    
    return null;
  }
}

/// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Night Vigil Geofencing",
          content: "Monitoring duty areas - ${DateTime.now()}",
        );
      }
    }
    
    await _performGeofenceCheck(prefs, service);
  });

  service.on('updateDuties').listen((event) async {
    final duties = event?['duties'] as List<dynamic>?;
    if (duties != null) {
      await prefs.setString('geofence_duties', json.encode(duties));
    }
  });

  service.on('stopGeofencing').listen((event) async {
    await prefs.remove('geofence_duties');
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await _performGeofenceCheck(prefs, service);
  
  return true;
}

/// Perform geofence checking
Future<void> _performGeofenceCheck(SharedPreferences prefs, ServiceInstance service) async {
  try {
    // Get stored duties
    final dutiesString = prefs.getString('geofence_duties');
    if (dutiesString == null) return;
    
    final List<dynamic> dutiesList = json.decode(dutiesString);
    final duties = dutiesList.map((e) => DutyAssignment.fromJson(e)).toList();
    
    // Check if any duties have ended and auto-stop if needed
    final now = DateTime.now();
    final activeDuties = duties.where((duty) => now.isBefore(duty.endTime)).toList();
    
    if (activeDuties.isEmpty && duties.isNotEmpty) {
      // All duties have ended, stop the service
      debugPrint('All duties ended, stopping geofencing service');
      await prefs.remove('geofence_duties');
      
      // Show notification about automatic stop
      await _showBackgroundNotification(
        'Duty Completed',
        'All duties have ended. Geofencing has been stopped automatically.',
        998,
      );
      
      service.stopSelf();
      return;
    } else if (activeDuties.length != duties.length) {
      // Some duties ended, update the stored duties
      await prefs.setString('geofence_duties', json.encode(activeDuties.map((duty) => {
        'id': duty.id,
        'location': duty.location,
        'latitude': duty.latitude,
        'longitude': duty.longitude,
        'radius': duty.radius,
        'startTime': duty.startTime.toIso8601String(),
        'endTime': duty.endTime.toIso8601String(),
        'status': duty.status,
      }).toList()));
    }
    
    // Get current location
    final Position? position = await _getCurrentLocationSafely();
    if (position == null) return;
    
    // Save current location
    await prefs.setString('last_location', json.encode({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': position.timestamp.toIso8601String(),
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'altitudeAccuracy': position.altitudeAccuracy,
      'heading': position.heading,
      'headingAccuracy': position.headingAccuracy,
      'speed': position.speed,
      'speedAccuracy': position.speedAccuracy,
      'isMocked': position.isMocked,
    }));
    
    // Check each active duty area
    for (final duty in activeDuties) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        duty.latitude,
        duty.longitude,
      );
      
      final isInside = distance <= duty.radius;
      final previousStatusKey = 'duty_${duty.id}_inside';
      final wasInside = prefs.getBool(previousStatusKey) ?? false;
      
      // Check if status changed
      if (isInside != wasInside) {
        await prefs.setBool(previousStatusKey, isInside);
        
        // Show notification
        await _showBackgroundNotification(
          isInside ? 'Entered Duty Area' : 'Left Duty Area',
          '${duty.location} - Distance: ${distance.round()}m',
          duty.id.hashCode,
        );
        
        service.invoke('geofence_status_changed', {
          'dutyId': duty.id,
          'location': duty.location,
          'isInside': isInside,
          'distance': distance,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }
  } catch (e) {
    debugPrint('Error in geofence check: $e');
  }
}

/// Get current location safely
Future<Position?> _getCurrentLocationSafely() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied: $permission');
      return null;
    }
    
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return null;
    }
    
    // Try multiple strategies for getting location
    Position? position;
    
    // Strategy 1: Try medium accuracy first (better reliability)
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      debugPrint('Medium accuracy location failed: $e');
    }
    
    // Strategy 2: Try last known position if recent
    try {
      position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final locationAge = DateTime.now().difference(position.timestamp);
        if (locationAge.inMinutes <= 5) {
          debugPrint('Using last known location (${locationAge.inMinutes} min old)');
          return position;
        }
      }
    } catch (e) {
      debugPrint('Last known location failed: $e');
    }
    
    // Strategy 3: Try low accuracy as fallback
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
      return position;
    } catch (e) {
      debugPrint('Low accuracy location failed: $e');
    }
    
    return null;
    
  } on LocationServiceDisabledException catch (e) {
    debugPrint('Location service disabled: $e');
    return null;
  } on PermissionDeniedException catch (e) {
    debugPrint('Location permission denied: $e');
    return null;
  } on TimeoutException catch (e) {
    debugPrint('Location timeout: $e');
    return null;
  } catch (e) {
    debugPrint('Error getting location: $e');
    return null;
  }
}

/// Show notification from background
Future<void> _showBackgroundNotification(String title, String body, int id) async {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'geofence_channel',
    'Geofence Notifications',
    channelDescription: 'Notifications for geofence events',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    playSound: true,
    enableVibration: true,
  );
  
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );
  
  await notificationsPlugin.show(id, title, body, details);
}