import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:night_vigil/main.dart';
import 'package:night_vigil/utils/alert.dart';

class AuthServices {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000', // Replace with your backend URL
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static Future<void> login(String empid, String password) async {
    try {
      final response = await _dio.post(
        '/users/login',
        data: {
          'empid': empid,
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data['access_token'] != null) {
        await _secureStorage.write(
          key: 'access_token',
          value: response.data['access_token'],
        );

        CustomSnackBar.show(
          navigatorKey.currentContext!,
          message: 'Login successful',
          alertType: AlertType.success,
        );
      } else if (response.statusCode == 401) {
        CustomSnackBar.show(
          navigatorKey.currentContext!,
          message: 'Invalid credentials',
          alertType: AlertType.error,
        );
        throw Exception('Invalid credentials');
      } else {
        CustomSnackBar.show(
          navigatorKey.currentContext!,
          message: 'Failed to login',
          alertType: AlertType.error,
        );
        throw Exception('Failed to login');
      }
    } on DioException catch (e) {
      CustomSnackBar.show(
        navigatorKey.currentContext!,
        message: 'Error connecting to the server',
        alertType: AlertType.error,
      );
      throw Exception('Error connecting to the server: ${e.message}');
    } catch (e) {
      CustomSnackBar.show(
        navigatorKey.currentContext!,
        message: 'An unknown error occurred',
        alertType: AlertType.error,
      );
      throw Exception('An unknown error occurred');
    }
  }

  Future<void> register({
      required String empid,
      required String password,
      String? profileImage,
      String role = 'OFFICER'
  }) async {
    try {
      final response = await _dio.post(
          '/users/register',
          data: {
            'empid': empid,
            'password': password,
            'profileImage': profileImage,
            'role': role
          }
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to register');
      }
    } catch (e) {
      throw Exception('An error occurred during registration');
    }
  }
}