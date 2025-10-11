import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:equatable/equatable.dart';

import '../models/duty_assignment_model.dart';
import '../services/geofencing_service.dart';
import '../utils/location_helper.dart';

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
  final bool isUsingFallbackLocation; // Track if using last known location

  const GeofencingActive({
    required this.activeDuties,
    this.currentLocation,
    this.dutiesUserIsIn = const [],
    this.dutyDistances = const {},
    this.isUsingFallbackLocation = false,
  });

  @override
  List<Object?> get props => [activeDuties, currentLocation, dutiesUserIsIn, dutyDistances, isUsingFallbackLocation];

  GeofencingActive copyWith({
    List<DutyAssignment>? activeDuties,
    Position? currentLocation,
    List<String>? dutiesUserIsIn,
    Map<String, double>? dutyDistances,
    bool? isUsingFallbackLocation,
  }) {
    return GeofencingActive(
      activeDuties: activeDuties ?? this.activeDuties,
      currentLocation: currentLocation ?? this.currentLocation,
      dutiesUserIsIn: dutiesUserIsIn ?? this.dutiesUserIsIn,
      dutyDistances: dutyDistances ?? this.dutyDistances,
      isUsingFallbackLocation: isUsingFallbackLocation ?? this.isUsingFallbackLocation,
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
  Timer? _preciseEndTimer; // Timer for precise duty end time

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
  }

  @override
  Future<void> close() {
    _positionStreamSubscription?.cancel();
    _dutyCheckTimer?.cancel(); // Cancel duty check timer
    _preciseEndTimer?.cancel(); // Cancel precise end timer
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
        emit(GeofencingActive(activeDuties: duties));
      } else {
        emit(GeofencingInactive());
      }
    } catch (e) {
      emit(GeofencingError('Failed to initialize geofencing: $e'));
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
      _preciseEndTimer?.cancel(); // Cancel precise end timer
      
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
        
        // Use the location helper for better error handling
        final locationResult = await LocationHelper.getCurrentLocationSafely();
        
        if (!locationResult.isSuccess) {
          // Instead of emitting an error state immediately, try to continue with last known location
          if (currentState.currentLocation != null) {
            // Check if last known location is still reasonably recent (within 10 minutes)
            final now = DateTime.now();
            final locationAge = now.difference(currentState.currentLocation!.timestamp);
            
            if (locationAge.inMinutes <= 10) {
              debugPrint('Using last known location (${locationAge.inMinutes} minutes old) due to location error');
              // Continue with existing location but show a warning
              // Don't emit error state to avoid disrupting the user experience
              return;
            }
          }
          
          // Only emit error if we have no recent location data
          debugPrint('Location error: ${locationResult.error}');
          emit(GeofencingError(locationResult.error!));
          return;
        }
        
        final position = locationResult.position!;
        
        // Check which duties the user is currently within and calculate distances
        final dutiesUserIsIn = <String>[];
        final dutyDistances = <String, double>{};
        
        for (final duty in currentState.activeDuties) {
          try {
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
          } catch (distanceError) {
            debugPrint('Error calculating distance for duty ${duty.id}: $distanceError');
            // Continue with other duties even if one fails
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
      debugPrint('Unexpected error in location check: $e');
      // Try to continue with existing state rather than showing error
      if (state is GeofencingActive) {
        final currentState = state as GeofencingActive;
        if (currentState.currentLocation != null) {
          debugPrint('Continuing with last known location due to unexpected error');
          return;
        }
      }
      emit(GeofencingError('Failed to check location: $e'));
    }
  }

  void _startLocationTracking() {
    _positionStreamSubscription?.cancel();
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium, // Use medium accuracy for better battery life and reliability
        distanceFilter: 10, // Update every 10 meters
        timeLimit: Duration(seconds: 20), // Increased timeout for better reliability
      ),
    ).listen(
      (Position position) {
        debugPrint('Location stream update: ${position.latitude}, ${position.longitude}');
        add(CheckCurrentLocationAgainstDuties());
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
        // Don't stop trying - continue with periodic checks
        // The CheckCurrentLocationAgainstDuties will handle fallback logic
        add(CheckCurrentLocationAgainstDuties());
      },
      cancelOnError: false, // Don't cancel stream on errors
    );
  }

  /// Start monitoring duty end times to automatically stop geofencing
  void _startDutyEndMonitoring() {
    _dutyCheckTimer?.cancel();
    _preciseEndTimer?.cancel();
    
    // Check every 10 seconds if any duties have ended (reduced from 1 minute for faster response)
    _dutyCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      add(CheckDutyEndTimes());
    });
    
    // Also set up a precise timer for the earliest duty end time
    _schedulePreciseEndTimer();
  }

  /// Schedule a precise timer for when the earliest duty ends
  void _schedulePreciseEndTimer() {
    _preciseEndTimer?.cancel();
    
    if (state is GeofencingActive) {
      final currentState = state as GeofencingActive;
      final now = DateTime.now();
      
      // Find the earliest duty end time
      DateTime? earliestEndTime;
      for (final duty in currentState.activeDuties) {
        if (duty.endTime.isAfter(now)) {
          if (earliestEndTime == null || duty.endTime.isBefore(earliestEndTime)) {
            earliestEndTime = duty.endTime;
          }
        }
      }
      
      if (earliestEndTime != null) {
        final timeUntilEnd = earliestEndTime.difference(now);
        if (timeUntilEnd.inMilliseconds > 0) {
          debugPrint('Setting precise timer for duty end in ${timeUntilEnd.inMinutes} minutes');
          _preciseEndTimer = Timer(timeUntilEnd, () {
            debugPrint('Precise duty end timer triggered');
            add(CheckDutyEndTimes());
          });
        }
      }
    }
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
          
          // Reschedule precise timer for remaining duties
          _schedulePreciseEndTimer();
        }
      }
    } catch (e) {
      debugPrint('Error checking duty end times: $e');
    }
  }
}