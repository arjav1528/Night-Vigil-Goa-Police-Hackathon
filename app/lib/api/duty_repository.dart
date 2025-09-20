import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DutyRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  static const String _tokenKey = 'access_token';

  DutyRepository()
      : _dio = Dio(
          BaseOptions(
            baseUrl: dotenv.env['BACKEND_URL']!, // Use ! if you're sure it exists in .env
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 5),
            headers: {
              'Content-Type': 'application/json',
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
          print("Sending request to: ${options.path}");
          print("Headers: ${options.headers}");
          return handler.next(options);
        },
      ),
    );
  }

  Future<List<DutyAssignment>> getMyDuties() async {
    try {
      final response = await _dio.get('/duties/my-duties');
      if (response.statusCode == 200) {
        print("Duties fetched: ${response.data}");
        final List<dynamic> dutyJson = response.data;
        return dutyJson.map((json) => DutyAssignment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load duties');
      }
    } on DioException catch (e) {
      String errorMsg = 'An unknown error occurred.';
      if (e.response != null) {
        final responseData = e.response?.data;
        if (responseData is Map && responseData.containsKey('detail')) {
          errorMsg = responseData['detail'];
        } else {
          errorMsg = 'Server returned an error: ${e.response?.statusCode}. Response: ${e.response?.data}';
        }
      } else {
        errorMsg = 'Network error: ${e.message}';
      }
      print("Error fetching duties: $errorMsg");
      throw Exception(errorMsg);
    }
  }
}