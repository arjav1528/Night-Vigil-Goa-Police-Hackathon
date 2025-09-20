import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:night_vigil/main.dart';
import 'package:night_vigil/screen/home_screen.dart' hide navigatorKey;
import 'package:night_vigil/utils/custom_snackbar.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  static const String _tokenKey = 'access_token';

  AuthRepository()
      : _dio = Dio(
          BaseOptions(
            baseUrl: dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000',
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 3),
          ),
        ),
        _secureStorage = const FlutterSecureStorage() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            print('Token is invalid or expired. Logging out.');
            await logout();
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              CustomSnackBar.show(
                context,
                message: 'Session expired. Please log in again.',
                alertType: AlertType.error,
              );
            }
          }
          return handler.next(e);
        },
      ),
    );
  }


  Future<String> login(String empid, String password) async {
    try {
      print("Calling login API"); 
      final response = await _dio.post(
        '/users/login',
        data: {'empid': empid, 'password': password},
      );
      print("Login API response: ${response.data}"); 

      if (response.statusCode == 200 && response.data['access_token'] != null) {
        final token = response.data['access_token'];
        await _secureStorage.write(key: _tokenKey, value: token);
        return token;
      } else {
        throw Exception('Login failed: Invalid response from server.');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? 'Network error';
      throw Exception('Login failed: $errorMsg');
    } catch (e) {
      throw Exception('An unknown error occurred during login.');
    }
  }

  Future<void> register({
    required String empid,
    required String password,
    required List<String> profileImages,
  }) async {
    try {
      final response = await _dio.post('/users/register', data: {
        'empid': empid,
        'password': password,
        'profileImages': profileImages,
        'role': 'OFFICER'
      });

      if (response.statusCode != 201) {
        throw Exception('Failed to register.');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? 'Network error';
      throw Exception('Registration failed: $errorMsg');
    } catch (e) {
      throw Exception('An unknown error occurred during registration.');
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }
}