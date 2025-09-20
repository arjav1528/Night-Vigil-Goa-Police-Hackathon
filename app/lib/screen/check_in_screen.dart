import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';
import 'package:night_vigil/utils/loading_indicator.dart';

class CheckInScreen extends StatefulWidget {
  final DutyAssignment duty;
  const CheckInScreen({super.key, required this.duty});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  File? _selfieImage;
  bool _isLoading = false;

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null) {
      setState(() {
        _selfieImage = File(pickedFile.path);
      });
    }
  }

  void _performCheckIn() async {
    if (_selfieImage == null) {
      // Show snackbar: "Please take a selfie first"
      return;
    }
    setState(() => _isLoading = true);

    try {
      // --- Step 1: Get Current Location ---
      // final position = await LocationService().getCurrentLocation();

      // --- Step 2: Upload Selfie to S3 ---
      // final selfieUrl = await S3UploadService().uploadImage(_selfieImage!);

      // --- Step 3: Call Backend to Verify & Check-in ---
      // await DutyRepository().checkIn(
      //   dutyId: widget.duty.id,
      //   latitude: position.latitude,
      //   longitude: position.longitude,
      //   selfieUrl: selfieUrl,
      // );

      // On success, show success message and navigate back
      // Navigator.of(context).pop();

    } catch (e) {
      // Show error snackbar
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duty Check-in')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Location', style: Theme.of(context).textTheme.bodyMedium),
            Text(widget.duty.location, style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 24.h),
            
            // --- Selfie Preview ---
            Container(
              height: 300.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12.r),
                image: _selfieImage != null
                    ? DecorationImage(
                        image: FileImage(_selfieImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selfieImage == null
                  ? Center(child: Text('Take a selfie to verify', style: Theme.of(context).textTheme.bodyMedium))
                  : null,
            ),
            SizedBox(height: 24.h),
            
            // --- Action Buttons ---
            OutlinedButton.icon(
              onPressed: _takeSelfie,
              icon: const Icon(Icons.camera_alt),
              label: Text(_selfieImage == null ? 'Take Selfie' : 'Retake Selfie'),
            ),
            SizedBox(height: 16.h),
            _isLoading
                ? const LoadingIndicator()
                : ElevatedButton(
                    onPressed: _selfieImage == null ? null : _performCheckIn,
                    child: const Text('CONFIRM CHECK-IN'),
                  ),
          ],
        ),
      ),
    );
  }
}