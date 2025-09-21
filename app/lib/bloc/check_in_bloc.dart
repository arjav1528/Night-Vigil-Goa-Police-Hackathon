import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:night_vigil/api/duty_repository.dart';
import 'package:night_vigil/api/firebase_storage_service.dart';
import 'package:night_vigil/services/location_service.dart';

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
  final String empid; // Needed for the S3/Firebase path

  CheckInSubmitted({
    required this.dutyId,
    required this.selfieImage,
    required this.empid,
  });
}

// --- BLOC ---
class CheckInBloc extends Bloc<CheckInEvent, CheckInState> {
  final DutyRepository dutyRepository;
  final FirebaseStorageService storageService;
  final LocationService locationService;

  CheckInBloc({
    required this.dutyRepository,
    required this.storageService,
    required this.locationService,
  }) : super(CheckInInitial()) {
    on<CheckInSubmitted>(_onCheckInSubmitted);
  }

  Future<void> _onCheckInSubmitted(
      CheckInSubmitted event, Emitter<CheckInState> emit) async {
    emit(CheckInLoading());
    try {
      // --- Step 1: Get Current Location ---
      print("Step 1: Getting current location...");
      final position = await locationService.getCurrentLocation();
      print("Step 1 SUCCESS: Location is ${position.latitude}, ${position.longitude}");

      // --- Step 2: Upload Selfie to Firebase Storage ---
      print("Step 2: Uploading selfie to Firebase...");
      final selfieUrl = await storageService.uploadImage(
        imageFile: event.selfieImage,
        empid: event.empid,
      );
      print("Step 2 SUCCESS: Selfie URL is $selfieUrl");
      
      // --- Step 3: Call Backend to Check-in ---
      print("Step 3: Sending check-in data to backend...");
      await dutyRepository.checkIn(
        dutyId: event.dutyId,
        latitude: position.latitude,
        longitude: position.longitude,
        selfieUrl: selfieUrl,
        empid: event.empid,
      );
      print("Step 3 SUCCESS: Backend confirmed check-in.");



      emit(CheckInSuccess(message: 'Check-in successfully verified!'));
      

    } catch (e) {
      // This will now catch the error from the specific step that failed
      print("CHECK-IN FAILED: $e");
      emit(CheckInFailure(error: e.toString().replaceAll('Exception: ', '')));
    }
  }
}