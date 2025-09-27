import 'package:app/api/duty_repository.dart';
import 'package:app/api/firebase_storage_service.dart';
import 'package:app/services/location_service.dart';

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
      // Step 1: Get Current Location using Geolocator
      final position = await locationService.getCurrentLocation();

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

      emit(CheckInSuccess(message: 'Check-in successfully verified!'));
    } catch (e) {
      emit(CheckInFailure(error: e.toString().replaceAll('Exception: ', '')));
    }
  }
}