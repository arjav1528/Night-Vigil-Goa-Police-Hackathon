import 'package:app/api/duty_repository.dart';
import 'package:app/api/firebase_storage_service.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/geofencing_service.dart';
import 'package:app/models/duty_assignment_model.dart';

import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';


// --- STATES ---
abstract class CheckInState {}
class CheckInInitial extends CheckInState {}
class CheckInLoading extends CheckInState {}
class CheckInSuccess extends CheckInState {
  final String message;
  CheckInSuccess({required this.message});
}
class CheckInFailure extends CheckInState {
  final String error;
  CheckInFailure({required this.error});
}

// --- EVENT ---
abstract class CheckInEvent {}
class CheckInSubmitted extends CheckInEvent {
  final String dutyId;
  final File selfieImage;
  final String empid;
  final DutyAssignment duty; // Add duty assignment for geofencing

  CheckInSubmitted({
    required this.dutyId,
    required this.selfieImage,
    required this.empid,
    required this.duty,
  });
}

// --- BLOC ---
class CheckInBloc extends Bloc<CheckInEvent, CheckInState> {
  final DutyRepository dutyRepository;
  final FirebaseStorageService storageService;
  final LocationService locationService;
  final GeofencingService geofencingService;

  CheckInBloc({
    required this.dutyRepository,
    required this.storageService,
    required this.locationService,
    required this.geofencingService,
  }) : super(CheckInInitial()) {
    on<CheckInSubmitted>(_onCheckInSubmitted);
  }

  Future<void> _onCheckInSubmitted(
      CheckInSubmitted event, Emitter<CheckInState> emit) async {
    emit(CheckInLoading());
    try {
      // Step 1: Get Current Location using Geolocator
      final position = await locationService.getCurrentLocation();
      
      // DEBUG: Print current location
      print('DEBUG: Current location - Lat: ${position.latitude}, Long: ${position.longitude}');

      // Step 2: Upload Selfie to Firebase Storage
      final selfieUrl = await storageService.uploadImage(
        imageFile: event.selfieImage,
        empid: event.empid,
      );

      // Step 3: Call Backend to Check-in
      await dutyRepository.checkIn(
        dutyId: event.dutyId,
        latitude: position.latitude,
        longitude: position.longitude,
        selfieUrl: selfieUrl,
      );

      // Step 4: Automatically start compulsory geofencing after successful check-in
      try {
        print('DEBUG: Starting compulsory geofencing for duty: ${event.duty.id}');
        
        // Request permissions first
        final permissionsGranted = await geofencingService.requestPermissions();
        if (!permissionsGranted) {
          print('WARNING: Geofencing permissions not granted, but check-in was successful');
          emit(CheckInSuccess(message: 'Check-in successful! Please grant location permissions for geofencing to work properly.'));
          return;
        }

        // Start geofencing with the current duty
        await geofencingService.startGeofencing([event.duty]);
        print('DEBUG: Geofencing started successfully');
        
        emit(CheckInSuccess(message: 'Check-in successful! Geofencing is now active and monitoring your location.'));
      } catch (geofencingError) {
        print('WARNING: Geofencing failed to start: $geofencingError');
        // Still emit success for check-in, but mention geofencing issue
        emit(CheckInSuccess(message: 'Check-in successful! However, geofencing could not be started. Please contact support.'));
      }
    } catch (e) {
      emit(CheckInFailure(error: e.toString().replaceAll('Exception: ', '')));
    }
  }
}