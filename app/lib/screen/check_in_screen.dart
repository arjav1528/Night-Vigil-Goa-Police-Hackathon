import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:night_vigil/api/duty_repository.dart';
import 'package:night_vigil/api/firebase_storage_service.dart';
import 'package:night_vigil/bloc/check_in_bloc.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';
import 'package:night_vigil/services/location_service.dart';
import 'package:night_vigil/utils/custom_snackbar.dart';
import 'package:night_vigil/utils/loading_indicator.dart';


class CheckInScreen extends StatefulWidget {
  final DutyAssignment duty;
  const CheckInScreen({super.key, required this.duty});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  File? _selfieImage;

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

  

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.go('/',);
        return false;
      },
      child: BlocProvider(
        create: (context) => CheckInBloc(
          dutyRepository: RepositoryProvider.of<DutyRepository>(context),
          storageService: FirebaseStorageService(),
          locationService: LocationService(),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Duty Check-in')),
          body: BlocConsumer<CheckInBloc, CheckInState>(
            listener: (context, state) {
              if (state is CheckInSuccess) {
                CustomSnackBar.show(context,
                    message: state.message, alertType: AlertType.success);
                context.go('/'); // Go back to home screen on success
              }
              if (state is CheckInFailure) {
                CustomSnackBar.show(context,
                    message: state.error, alertType: AlertType.error);
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Location', style: Theme.of(context).textTheme.bodyMedium),
                    Text(widget.duty.location,
                        style: Theme.of(context).textTheme.headlineMedium),
                    SizedBox(height: 24.h),
                    Container(
                      height: 300.h,
                      width: 300.w,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12.r),
                        image: _selfieImage != null
                            ? DecorationImage(
                                image: FileImage(_selfieImage!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _selfieImage == null
                          ? Center(child: Text('Take a selfie to verify', style: Theme.of(context).textTheme.bodyMedium))
                          : null,
                    ),
                    SizedBox(height: 24.h),
                    OutlinedButton.icon(
                      onPressed: _takeSelfie,
                      icon: const Icon(Icons.camera_alt),
                      label:
                          Text(_selfieImage == null ? 'Take Selfie' : 'Retake Selfie'),
                    ),
                    SizedBox(height: 16.h),
                    if (state is CheckInLoading)
                      const LoadingIndicator()
                    else
                      ElevatedButton(
                        onPressed: _selfieImage == null
                            ? null
                            : () {
                                context.read<CheckInBloc>().add(
                                      CheckInSubmitted(
                                        dutyId: widget.duty.id,
                                        selfieImage: _selfieImage!,
                                        // You'll need to get the empid from your AuthBloc state or user model
                                        empid: 'current_user_empid',
                                      ),
                                    );
                              },
                        child: const Text('CONFIRM CHECK-IN'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}