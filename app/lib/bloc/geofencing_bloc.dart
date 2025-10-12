import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:equatable/equatable.dart';

import '../models/duty_assignment_model.dart';
import '../services/geofencing_service.dart';

// Events
abstract class GeofencingEvent extends Equatable {
  const GeofencingEvent();

  @override
  List<Object?> get props => [];
}

class InitializeGeofencing extends GeofencingEvent {}

class StartGeofencingWithDuties extends GeofencingEvent {
  final List<DutyAssignment> duties;

  const StartGeofencingWithDuties(this.duties);

  @override
  List<Object?> get props => [duties];
}

class StopGeofencing extends GeofencingEvent {
  final bool isAutomatic; // Flag to distinguish automatic vs manual stops

  const StopGeofencing({this.isAutomatic = false});

  @override
  List<Object?> get props => [isAutomatic];
}

class AddGeofenceForDuty extends GeofencingEvent {
  final DutyAssignment duty;

  const AddGeofenceForDuty(this.duty);

  @override
  List<Object?> get props => [duty];
}

class RemoveGeofenceForDuty extends GeofencingEvent {
  final String dutyId;

  const RemoveGeofenceForDuty(this.dutyId);

  @override
  List<Object?> get props => [dutyId];
}

class CheckCurrentLocationAgainstDuties extends GeofencingEvent {}

class RequestGeofencingPermissions extends GeofencingEvent {}

class CheckDutyEndTimes extends GeofencingEvent {}

class GeofenceStatusChanged extends GeofencingEvent {
  final String dutyId;
  final String location;
  final bool isInside;
  final double distance;
  final DateTime timestamp;

  const GeofenceStatusChanged({
    required this.dutyId,
    required this.location,
    required this.isInside,
    required this.distance,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [dutyId, location, isInside, distance, timestamp];
}

// States
abstract class GeofencingState extends Equatable {
  const GeofencingState();

  @override
  List<Object?> get props => [];
}

class GeofencingInitial extends GeofencingState {}

class GeofencingLoading extends GeofencingState {}

class GeofencingPermissionDenied extends GeofencingState {
  final String message;

  const GeofencingPermissionDenied(this.message);

  @override
  List<Object?> get props => [message];
}

class GeofencingActive extends GeofencingState {
  final List<DutyAssignment> activeDuties;
  final Position? currentLocation;
  final List<String> dutiesUserIsIn;
  final Map<String, double> dutyDistances; // Map of duty ID to distance in meters

  const GeofencingActive({
    required this.activeDuties,
    this.currentLocation,
    this.dutiesUserIsIn = const [],
    this.dutyDistances = const {},
  });

  @override
  List<Object?> get props => [activeDuties, currentLocation, dutiesUserIsIn, dutyDistances];

  GeofencingActive copyWith({
    List<DutyAssignment>? activeDuties,
    Position? currentLocation,
    List<String>? dutiesUserIsIn,
    Map<String, double>? dutyDistances,
  }) {
    return GeofencingActive(
      activeDuties: activeDuties ?? this.activeDuties,
      currentLocation: currentLocation ?? this.currentLocation,
      dutiesUserIsIn: dutiesUserIsIn ?? this.dutiesUserIsIn,
      dutyDistances: dutyDistances ?? this.dutyDistances,
    );
  }
}

class GeofencingInactive extends GeofencingState {}

class GeofencingError extends GeofencingState {
  final String message;

  const GeofencingError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class GeofencingBloc extends Bloc<GeofencingEvent, GeofencingState> {
  final GeofencingService _geofencingService;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _dutyCheckTimer; // Timer to check duty end times
  Timer? _locationTrackingTimer; // Timer for periodic location tracking
  StreamSubscription? _geofenceStatusSubscription; // Listen to background service events

  GeofencingBloc({GeofencingService? geofencingService})
      : _geofencingService = geofencingService ?? GeofencingService(),
        super(GeofencingInitial()) {
    
    on<InitializeGeofencing>(_onInitializeGeofencing);
    on<RequestGeofencingPermissions>(_onRequestGeofencingPermissions);
    on<StartGeofencingWithDuties>(_onStartGeofencingWithDuties);
    on<StopGeofencing>(_onStopGeofencing);
    on<AddGeofenceForDuty>(_onAddGeofenceForDuty);
    on<RemoveGeofenceForDuty>(_onRemoveGeofenceForDuty);
    on<CheckCurrentLocationAgainstDuties>(_onCheckCurrentLocationAgainstDuties);
    on<CheckDutyEndTimes>(_onCheckDutyEndTimes);
    on<GeofenceStatusChanged>(_onGeofenceStatusChanged);
  }

  @override
  Future<void> close() {
    _positionStreamSubscription?.cancel();
    _dutyCheckTimer?.cancel(); // Cancel duty check timer
    _locationTrackingTimer?.cancel(); // Cancel location tracking timer
    _geofenceStatusSubscription?.cancel(); // Cancel geofence status subscription
    return super.close();
  }

  Future<void> _onInitializeGeofencing(
    InitializeGeofencing event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      emit(GeofencingLoading());
      await _geofencingService.initialize();
      
      // Check if geofencing is already running
      final isRunning = await _geofencingService.isRunning;
      if (isRunning) {
        final duties = await _geofencingService.getDutiesFromStorage();
        
        // Check if any duties are still active
        final now = DateTime.now();
        final activeDuties = duties.where((duty) => now.isBefore(duty.endTime)).toList();
        
        if (activeDuties.isNotEmpty) {
          emit(GeofencingActive(activeDuties: activeDuties));
        } else {
          // All duties have ended, stop geofencing
          debugPrint('All stored duties have ended, stopping geofencing during initialization');
          await _geofencingService.forceStopGeofencing();
          emit(GeofencingInactive());
        }
      } else {
        emit(GeofencingInactive());
      }
    } catch (e) {
      debugPrint('Error initializing geofencing: $e');
      // Try to gracefully handle the error
      try {
        await _geofencingService.forceStopGeofencing();
      } catch (stopError) {
        debugPrint('Error force stopping geofencing during error recovery: $stopError');
      }
      emit(GeofencingInactive());
    }
  }

  Future<void> _onRequestGeofencingPermissions(
    RequestGeofencingPermissions event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      emit(GeofencingLoading());
      final permissionsGranted = await _geofencingService.requestPermissions();
      
      if (permissionsGranted) {
        emit(GeofencingInactive());
      } else {
        emit(const GeofencingPermissionDenied(
          'Location permissions are required for geofencing. Please grant permissions in app settings.',
        ));
      }
    } catch (e) {
      emit(GeofencingError('Failed to request permissions: $e'));
    }
  }

  Future<void> _onStartGeofencingWithDuties(
    StartGeofencingWithDuties event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      emit(GeofencingLoading());
      
      // Check permissions first
      final permissionsGranted = await _geofencingService.requestPermissions();
      if (!permissionsGranted) {
        emit(const GeofencingPermissionDenied(
          'Location permissions are required for geofencing.',
        ));
        return;
      }

      await _geofencingService.startGeofencing(event.duties);
      
      // Start listening to geofence status changes from background service
      _startGeofenceStatusListener();
      
      // Start listening to location updates
      _startLocationTracking();
      
      // Start duty end time monitoring
      _startDutyEndMonitoring();
      
      // Initial state with empty distances, will be updated by location tracking
      emit(GeofencingActive(activeDuties: event.duties));
      
      // Immediately check current location to get initial distances
      add(CheckCurrentLocationAgainstDuties());
      
      // Also immediately check if any duties have already ended
      add(CheckDutyEndTimes());
    } catch (e) {
      debugPrint('Error starting geofencing: $e');
      emit(GeofencingError('Failed to start geofencing: $e'));
    }
  }

  Future<void> _onStopGeofencing(
    StopGeofencing event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      // Only allow automatic stops (when duty ends)
      if (!event.isAutomatic) {
        emit(const GeofencingError('Geofencing cannot be manually stopped. It will automatically stop when your duty ends.'));
        return;
      }

      emit(GeofencingLoading());
      
      await _geofencingService.stopGeofencing();
      _positionStreamSubscription?.cancel();
      _dutyCheckTimer?.cancel(); // Cancel duty monitoring timer
      _locationTrackingTimer?.cancel(); // Cancel location tracking timer
      _geofenceStatusSubscription?.cancel(); // Cancel geofence status listener
      
      emit(GeofencingInactive());
    } catch (e) {
      emit(GeofencingError('Failed to stop geofencing: $e'));
    }
  }

  Future<void> _onAddGeofenceForDuty(
    AddGeofenceForDuty event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      if (state is GeofencingActive) {
        final currentState = state as GeofencingActive;
        
        await _geofencingService.addGeofence(event.duty);
        
        final updatedDuties = List<DutyAssignment>.from(currentState.activeDuties)
          ..add(event.duty);
        
        emit(currentState.copyWith(activeDuties: updatedDuties));
        
        // Refresh location to calculate distance for new duty
        add(CheckCurrentLocationAgainstDuties());
        
        // Check if any duties have ended and reschedule precise timer
        add(CheckDutyEndTimes());
      }
    } catch (e) {
      emit(GeofencingError('Failed to add geofence: $e'));
    }
  }

  Future<void> _onRemoveGeofenceForDuty(
    RemoveGeofenceForDuty event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      if (state is GeofencingActive) {
        final currentState = state as GeofencingActive;
        
        await _geofencingService.removeGeofence(event.dutyId);
        
        final updatedDuties = currentState.activeDuties
            .where((duty) => duty.id != event.dutyId)
            .toList();
        
        // Remove distance information for the removed duty
        final updatedDistances = Map<String, double>.from(currentState.dutyDistances);
        updatedDistances.remove(event.dutyId);
        
        // Remove from duties user is in
        final updatedDutiesUserIsIn = currentState.dutiesUserIsIn
            .where((dutyId) => dutyId != event.dutyId)
            .toList();
        
        emit(currentState.copyWith(
          activeDuties: updatedDuties,
          dutyDistances: updatedDistances,
          dutiesUserIsIn: updatedDutiesUserIsIn,
        ));
        
        // Check if any duties have ended and reschedule precise timer
        add(CheckDutyEndTimes());
      }
    } catch (e) {
      emit(GeofencingError('Failed to remove geofence: $e'));
    }
  }

  Future<void> _onCheckCurrentLocationAgainstDuties(
    CheckCurrentLocationAgainstDuties event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      if (state is GeofencingActive) {
        final currentState = state as GeofencingActive;
        
        // Get current location
        final position = await Geolocator.getCurrentPosition();
        
        // Check which duties the user is currently within and calculate distances
        final dutiesUserIsIn = <String>[];
        final dutyDistances = <String, double>{};
        
        for (final duty in currentState.activeDuties) {
          // Calculate distance to this duty location
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            duty.latitude,
            duty.longitude,
          );
          dutyDistances[duty.id] = distance;
          
          // Check if user is within the duty area
          final isWithin = await _geofencingService.isWithinDutyArea(duty, position);
          if (isWithin) {
            dutiesUserIsIn.add(duty.id);
          }
        }
        
        emit(currentState.copyWith(
          currentLocation: position,
          dutiesUserIsIn: dutiesUserIsIn,
          dutyDistances: dutyDistances,
        ));
        
        // Also check if any duties have ended (immediate check on location update)
        add(CheckDutyEndTimes());
      }
    } catch (e) {
      emit(GeofencingError('Failed to check location: $e'));
    }
  }

  void _startLocationTracking() {
    _positionStreamSubscription?.cancel();
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
        timeLimit: Duration(seconds: 30),
      ),
    ).listen(
      (Position position) {
        add(CheckCurrentLocationAgainstDuties());
      },
      onError: (error) {
        add(CheckCurrentLocationAgainstDuties()); // Still try to check manually
      },
    );
    
    // Start periodic location tracking every 5 seconds
    _startPeriodicLocationTracking();
  }

  void _startPeriodicLocationTracking() {
    _locationTrackingTimer?.cancel();
    
    // Update location every 5 seconds
    _locationTrackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      add(CheckCurrentLocationAgainstDuties());
    });
  }

  /// Start monitoring duty end times to automatically stop geofencing
  void _startDutyEndMonitoring() {
    _dutyCheckTimer?.cancel();
    
    // Check every minute if any duties have ended
    _dutyCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      add(CheckDutyEndTimes());
    });
  }

  /// Handle checking duty end times and auto-stopping geofencing
  Future<void> _onCheckDutyEndTimes(
    CheckDutyEndTimes event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      if (state is GeofencingActive) {
        final currentState = state as GeofencingActive;
        final now = DateTime.now();
        
        // Check if all duties have ended
        final activeDuties = currentState.activeDuties.where((duty) => 
          now.isBefore(duty.endTime)
        ).toList();
        
        // If no active duties remain, stop geofencing automatically
        if (activeDuties.isEmpty && currentState.activeDuties.isNotEmpty) {
          debugPrint('All duties have ended. Automatically stopping geofencing.');
          
          await _geofencingService.stopGeofencing();
          _positionStreamSubscription?.cancel();
          _dutyCheckTimer?.cancel();
          _locationTrackingTimer?.cancel(); // Cancel location tracking timer
          
          emit(GeofencingInactive());
          
          // Show notification about automatic stop
          await _geofencingService.showNotification(
            'Duty Completed',
            'Geofencing has been automatically stopped as your duty time has ended.',
            notificationId: 999,
          );
        } else if (activeDuties.length != currentState.activeDuties.length) {
          // Some duties ended but others are still active - update distances for remaining duties
          final endedDutyIds = currentState.activeDuties
              .where((duty) => !activeDuties.contains(duty))
              .map((duty) => duty.id)
              .toList();
          
          // Remove distance information for ended duties
          final updatedDistances = Map<String, double>.from(currentState.dutyDistances);
          for (final dutyId in endedDutyIds) {
            updatedDistances.remove(dutyId);
          }
          
          // Remove from duties user is in
          final updatedDutiesUserIsIn = currentState.dutiesUserIsIn
              .where((dutyId) => !endedDutyIds.contains(dutyId))
              .toList();
          
          emit(currentState.copyWith(
            activeDuties: activeDuties,
            dutyDistances: updatedDistances,
            dutiesUserIsIn: updatedDutiesUserIsIn,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error checking duty end times: $e');
    }
  }

  /// Start listening to geofence status changes from background service
  void _startGeofenceStatusListener() {
    _geofenceStatusSubscription?.cancel();
    
    final service = FlutterBackgroundService();
    _geofenceStatusSubscription = service.on('geofence_status_changed').listen((event) {
      if (event != null) {
        try {
          final dutyId = event['dutyId'] as String;
          final location = event['location'] as String;
          final isInside = event['isInside'] as bool;
          final distance = (event['distance'] as num).toDouble();
          final timestamp = DateTime.parse(event['timestamp'] as String);
          
          add(GeofenceStatusChanged(
            dutyId: dutyId,
            location: location,
            isInside: isInside,
            distance: distance,
            timestamp: timestamp,
          ));
        } catch (e) {
          debugPrint('Error parsing geofence status change: $e');
        }
      }
    });
  }

  /// Handle geofence status changes from background service
  Future<void> _onGeofenceStatusChanged(
    GeofenceStatusChanged event,
    Emitter<GeofencingState> emit,
  ) async {
    try {
      if (state is GeofencingActive) {
        final currentState = state as GeofencingActive;
        
        // Update the duties user is in
        final updatedDutiesUserIsIn = List<String>.from(currentState.dutiesUserIsIn);
        
        if (event.isInside && !updatedDutiesUserIsIn.contains(event.dutyId)) {
          updatedDutiesUserIsIn.add(event.dutyId);
          
          // Show notification for entering duty area
          await _geofencingService.showNotification(
            'Entered Duty Area',
            '${event.location} - You are now in your assigned duty area',
            notificationId: 200 + event.dutyId.hashCode,
          );
          
        } else if (!event.isInside && updatedDutiesUserIsIn.contains(event.dutyId)) {
          updatedDutiesUserIsIn.remove(event.dutyId);
          
          // Show notification for leaving duty area
          await _geofencingService.showNotification(
            'Left Duty Area',
            '${event.location} - Please return to your duty area (${event.distance.round()}m away)',
            notificationId: 300 + event.dutyId.hashCode,
          );
        }
        
        // Update distances
        final updatedDistances = Map<String, double>.from(currentState.dutyDistances);
        updatedDistances[event.dutyId] = event.distance;
        
        emit(currentState.copyWith(
          dutiesUserIsIn: updatedDutiesUserIsIn,
          dutyDistances: updatedDistances,
        ));
        
        debugPrint('Geofence status changed: ${event.location} - Inside: ${event.isInside} - Distance: ${event.distance.round()}m');
      }
    } catch (e) {
      debugPrint('Error handling geofence status change: $e');
    }
  }
}