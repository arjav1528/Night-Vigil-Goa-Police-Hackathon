

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:night_vigil/utils/alert.dart';

class AuthServices{
  static String baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
  static FlutterSecureStorage storage = const FlutterSecureStorage();

  static Future<String> login(String empid, String password, BuildContext context) async {

    final body = {
      'empid': empid,
      'password': password,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);
      final accessToken = data['access_token'];
      await storage.write(key: 'access_token', value: accessToken);
      CustomSnackBar.show(
        context,
        message: 'Login successful',
        alertType: AlertType.success,
      );
      return 'Login successful';
    }else if(response.statusCode == 401){
      CustomSnackBar.show(
        context,
        message: 'Invalid credentials',
        alertType: AlertType.error,
      );
      return 'Invalid credentials';

    } else {
      CustomSnackBar.show(
        context,
        message: 'Failed to login',
        alertType: AlertType.error,
      );  
      return 'Failed to login';
    }
  }


  static Future<String> logout(BuildContext context) async {
    await storage.delete(key: 'access_token');
    CustomSnackBar.show(
      context,
      message: 'Logged out',
      alertType: AlertType.success,
    );
    return 'Logged out';
  }
}