import 'dart:io';


import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

      print('Successfully uploaded to Firebase Storage. URL: $downloadUrl');
      return downloadUrl;

    } on FirebaseException catch (e) {
      print('Error uploading to Firebase Storage: ${e.message}');
      throw Exception('Failed to upload image: ${e.code}');
    }
  }

  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String empid,
  }) async {
    final uploadFutures = images.map((imageFile) {
      return uploadImage(imageFile: imageFile, empid: empid);
    }).toList();

    return await Future.wait(uploadFutures);
  }
}