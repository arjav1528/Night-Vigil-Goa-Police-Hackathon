import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  static const String _tokenKey = 'access_token';

  AuthRepository()
      : _dio = Dio(
          BaseOptions(
            baseUrl: dotenv.env['BACKEND_URL']!,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 5),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            }
          ),
        ),
        _secureStorage = const FlutterSecureStorage();

  Future<String> login(String empid, String password) async {
    try {
      final response = await _dio.post(
        '/users/login',
        data: {'empid': empid, 'password': password},
      );
      if (response.statusCode == 200 && response.data['access_token'] != null) {
        final token = response.data['access_token'];
        await _secureStorage.write(key: _tokenKey, value: token);
        return token;
      } else {
        throw Exception('Login failed: Invalid response.');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? 'Network error';
      throw Exception(errorMsg);
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
      final errorMsg = e.response?.data?['detail'] ?? 'Registration failed';
      throw Exception(errorMsg);
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }
}