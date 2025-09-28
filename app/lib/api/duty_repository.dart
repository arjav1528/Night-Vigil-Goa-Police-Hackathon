import 'package:app/models/duty_assignment_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DutyRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  static const String _tokenKey = 'access_token';

  DutyRepository()
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
        _secureStorage = const FlutterSecureStorage() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<List<DutyAssignment>> getMyDuties() async {
    try {
      final response = await _dio.get('/duties/my-duties');
      if (response.statusCode == 200) {
        final List<dynamic> dutyJson = response.data['duties'];
        return dutyJson.map((json) => DutyAssignment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load duties');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? 'Failed to fetch duties';
      throw Exception(errorMsg);
    }
  }

  Future<void> checkIn({
    required String dutyId,
    required double latitude,
    required double longitude,
    required String selfieUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/duties/$dutyId/checkin',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'selfieUrl': selfieUrl,
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned an error during check-in.');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? 'An error occurred during check-in.';
      throw Exception(errorMsg);
    }
  }
}