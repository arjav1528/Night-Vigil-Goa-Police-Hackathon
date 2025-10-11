import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationHelper {
  /// Get current location with comprehensive error handling and fallback mechanisms
  static Future<LocationResult> getCurrentLocationSafely() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
          'Location permissions are permanently denied. Please enable them in device settings:\n'
          '1. Go to Settings > Privacy & Security > Location Services\n'
          '2. Enable Location Services\n'
          '3. Find this app and set to "While Using App" or "Always"',
        );
      }
      
      if (permission == LocationPermission.denied) {
        return LocationResult.error(
          'Location permissions are required. Please grant location permissions to continue.',
        );
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error(
          'Location services are disabled. Please enable location services:\n'
          '1. Go to Settings > Privacy & Security > Location Services\n'
          '2. Turn on Location Services',
        );
      }
      
      // Try to get current location with multiple fallback strategies
      Position? position = await _getLocationWithFallback();
      
      if (position == null) {
        return LocationResult.error(
          'Unable to get current location. GPS signal may be weak.\n'
          'Please try:\n'
          '1. Move to an area with better sky visibility\n'
          '2. Wait a moment for GPS to stabilize\n'
          '3. The app will continue trying in the background',
        );
      }
      
      return LocationResult.success(position);
      
    } on LocationServiceDisabledException {
      return LocationResult.error(
        'Location services are disabled. Please enable location services in your device settings.',
      );
    } on PermissionDeniedException {
      return LocationResult.error(
        'Location permissions denied. Please grant location permissions in app settings.',
      );
    } catch (e) {
      String errorMessage = 'Unable to get current location';
      
      // Handle specific iOS Core Location errors
      if (e.toString().contains('kCLLocationManager') || 
          e.toString().contains('CoreLocation') ||
          e.toString().contains('KCL')) {
        errorMessage = 'Location service error (iOS). Please try the following:\n'
            '1. Check that Location Services are enabled in Settings\n'
            '2. Ensure this app has location permissions\n'
            '3. Try restarting the app\n'
            '4. If the problem persists, restart your device';
      } else if (e.toString().contains('PERMISSION_DENIED') ||
                 e.toString().contains('LOCATION_DISABLED')) {
        errorMessage = 'Location access denied or disabled. Please check your location settings.';
      }
      
      debugPrint('Location error details: $e');
      return LocationResult.error('$errorMessage\n\nThe app will continue trying in the background.');
    }
  }
  
  /// Try multiple strategies to get location with fallback mechanisms
  static Future<Position?> _getLocationWithFallback() async {
    // Strategy 1: Try high accuracy with shorter timeout first
    try {
      debugPrint('Attempting high accuracy location...');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('High accuracy failed: $e');
    }
    
    // Strategy 2: Try medium accuracy with longer timeout
    try {
      debugPrint('Attempting medium accuracy location...');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint('Medium accuracy failed: $e');
    }
    
    // Strategy 3: Try to get last known location
    try {
      debugPrint('Attempting to get last known location...');
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        // Check if last known location is recent (within 5 minutes)
        final now = DateTime.now();
        final locationAge = now.difference(lastKnown.timestamp);
        if (locationAge.inMinutes <= 5) {
          debugPrint('Using recent last known location (${locationAge.inMinutes} minutes old)');
          return lastKnown;
        }
      }
    } catch (e) {
      debugPrint('Last known location failed: $e');
    }
    
    // Strategy 4: Try low accuracy with extended timeout as last resort
    try {
      debugPrint('Attempting low accuracy location as last resort...');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (e) {
      debugPrint('All location strategies failed: $e');
    }
    
    return null;
  }
  
  /// Show location troubleshooting dialog
  static void showLocationTroubleshootingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Troubleshooting'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'If you\'re having location issues, try these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Check Location Permissions:'),
              Text('   • Go to Settings > Apps > Night Vigil'),
              Text('   • Tap Permissions > Location'),
              Text('   • Select "Allow all the time" or "Allow while using app"'),
              SizedBox(height: 8),
              Text('2. Enable Location Services:'),
              Text('   • Go to Settings > Location'),
              Text('   • Turn on Location Services'),
              Text('   • Ensure High Accuracy mode is enabled'),
              SizedBox(height: 8),
              Text('3. Improve GPS Signal:'),
              Text('   • Move to an outdoor area'),
              Text('   • Ensure clear view of the sky'),
              Text('   • Wait a few moments for GPS to lock'),
              SizedBox(height: 8),
              Text('4. Restart:'),
              Text('   • Close and reopen the app'),
              Text('   • If issues persist, restart your device'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Result class for location operations
class LocationResult {
  final Position? position;
  final String? error;
  final bool isSuccess;
  
  LocationResult.success(this.position) : error = null, isSuccess = true;
  LocationResult.error(this.error) : position = null, isSuccess = false;
}