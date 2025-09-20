import 'dart:io';

import 'package:night_vigil/bloc/register_bloc.dart';
import 'package:night_vigil/utils/loading_indicator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:night_vigil/api/auth_repository.dart';
import 'package:night_vigil/utils/custom_snackbar.dart';

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _empidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<File> _selectedImages = [];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.clear();
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _submitRegistration(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedImages.length < 3) {
        CustomSnackBar.show(context,
            message: 'Please select at least 3 photos for verification.',
            alertType: AlertType.warning);
        return;
      }
      context.read<RegisterBloc>().add(
            RegisterButtonPressed(
              empid: _empidController.text.trim(),
              password: _passwordController.text.trim(),
              images: _selectedImages,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegisterBloc(
        authRepository: RepositoryProvider.of<AuthRepository>(context),
      ),
      child: BlocListener<RegisterBloc, RegisterState>(
        listener: (context, state) {
          if (state is RegisterSuccess) {
            CustomSnackBar.show(context,
                message: 'Registration successful! Please log in.',
                alertType: AlertType.success);
            DefaultTabController.of(context).animateTo(0);
          }
          if (state is RegisterFailure) {
            CustomSnackBar.show(context,
                message: state.error.replaceAll('Exception: ', ''),
                alertType: AlertType.error);
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Officer Account',
                    style: Theme.of(context).textTheme.headlineMedium),
                SizedBox(height: 8.h),
                Text(
                  'Please provide your details and verification photos.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 48.h),
                TextFormField(
                  controller: _empidController,
                  decoration: const InputDecoration(labelText: 'Employee ID'),
                  validator: (v) => v!.isEmpty ? 'Employee ID is required' : null,
                ),
                SizedBox(height: 24.h),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      v!.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                SizedBox(height: 24.h),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  validator: (v) =>
                      v != _passwordController.text ? 'Passwords do not match' : null,
                ),
                SizedBox(height: 32.h),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Select 3+ Verification Photos'),
                ),
                if (_selectedImages.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 16.h),
                    child: Text(
                      '${_selectedImages.length} photos selected. Please ensure they are clear, forward-facing photos.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                SizedBox(height: 32.h),
                BlocBuilder<RegisterBloc, RegisterState>(
                  builder: (context, state) {
                    if (state is RegisterLoading) {
                      return const LoadingIndicator();
                    }
                    return ElevatedButton(
                      onPressed: () => _submitRegistration(context),
                      child: const Text('REGISTER'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}