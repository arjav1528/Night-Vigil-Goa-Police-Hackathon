import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:night_vigil/api/auth_repository.dart';

abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthAuthenticated extends AuthState {}
class AuthUnauthenticated extends AuthState {}

abstract class AuthEvent {}
class AppStarted extends AuthEvent {}
class LoggedIn extends AuthEvent {}
class LoggedOut extends AuthEvent {}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _storage = const FlutterSecureStorage();
  final _tokenKey = 'access_token';

  AuthBloc({required AuthRepository authRepository}) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedIn>(_onLoggedIn);
    on<LoggedOut>(_onLoggedOut);
  }

  void _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final token = await _storage.read(key: _tokenKey);
    print("Token: $token");
    if (token != null) {
      print("User is authenticated");
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  void _onLoggedIn(LoggedIn event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated());
  }

  void _onLoggedOut(LoggedOut event, Emitter<AuthState> emit) async {
    await AuthRepository().logout();
    emit(AuthUnauthenticated());
  }
}