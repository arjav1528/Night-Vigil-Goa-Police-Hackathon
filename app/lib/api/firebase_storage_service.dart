import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {

  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;

 
  Future<String> uploadImage({
    required File imageFile,
    required String empid,
  }) async {
    try {

      final extension = path.extension(imageFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadPath = 'photos/$empid/verification_$timestamp$extension';

 
      final ref = _storage.ref().child(uploadPath);


      final uploadTask = ref.putFile(imageFile);


      final snapshot = await uploadTask.whenComplete(() => {});
      
 
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Successfully uploaded to Firebase Storage. URL: $downloadUrl');
      return downloadUrl;

    } on firebase_storage.FirebaseException catch (e) {

      debugPrint('Error uploading to Firebase Storage: ${e.message}');
      throw Exception('Failed to upload image: ${e.code}');
    } catch (e) {

      debugPrint('An unknown error occurred during upload: $e');
      throw Exception('An unknown error occurred during image upload.');
    }
  }


  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String empid,
  }) async {
    // Use Future.wait to run all upload tasks concurrently for better performance
    final uploadFutures = images.map((imageFile) {
      return uploadImage(imageFile: imageFile, empid: empid);
    }).toList();


    return await Future.wait(uploadFutures);
  }
}