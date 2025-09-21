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
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
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



  Future<void> checkIn({
    required String dutyId,
    required double latitude,
    required double longitude,
    required String selfieUrl,
    required String empid, // Keep empid for consistency
  }) async {
    try {
      // The endpoint now receives a JSON body
      final response = await _dio.post(
        '/duties/$dutyId/checkin',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'selfieUrl': selfieUrl, // Use the correct key 'selfieUrl'
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

  // ... (inside your DutyRepository class)

  Future<void> sendOutOfRadiusAlert({
    required String dutyId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // This method does not need to handle a response, just send the data.
      await _dio.post(
        '/duties/location-update',
        data: {
          'dutyId': dutyId,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      print('Successfully sent out-of-radius alert to backend.');
    } on DioException catch (e) {
      // We can just print the error here, as there's no UI to update.
      print('Failed to send location alert: ${e.message}');
    }
  }


  
}