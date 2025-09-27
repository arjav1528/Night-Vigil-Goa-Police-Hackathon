import 'dart:io';

import 'package:app/api/auth_repository.dart';


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/api/firebase_storage_service.dart';

// States
abstract class RegisterState {}
class RegisterInitial extends RegisterState {}
class RegisterLoading extends RegisterState {}
class RegisterSuccess extends RegisterState {}
class RegisterFailure extends RegisterState {
  final String error;
  RegisterFailure({required this.error});
}

// Events
abstract class RegisterEvent {}
class RegisterButtonPressed extends RegisterEvent {
  final String empid;
  final String password;
  final List<File> images;

  RegisterButtonPressed({required this.empid, required this.password, required this.images});
}

// BLoC
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final AuthRepository authRepository;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  RegisterBloc({required this.authRepository}) : super(RegisterInitial()) {
    on<RegisterButtonPressed>(_onRegisterButtonPressed);
  }

  Future<void> _onRegisterButtonPressed(RegisterButtonPressed event, Emitter<RegisterState> emit) async {
    emit(RegisterLoading());
    try {
      final List<String> imageUrls = await _storageService.uploadMultipleImages(
        images: event.images,
        empid: event.empid,
      );
      await authRepository.register(
        empid: event.empid,
        password: event.password,
        profileImages: imageUrls,
      );
      emit(RegisterSuccess());
    } catch (error) {
      emit(RegisterFailure(error: error.toString()));
    }
  }
}