import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:night_vigil/api/auth_repository.dart'; // Make sure you're using the repository
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/utils/custom_snackbar.dart';
import 'package:night_vigil/utils/loading_indicator.dart'; // Your snackbar utility

class LoginTab extends StatefulWidget {
  const LoginTab({super.key});

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _empidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _performLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepository = context.read<AuthRepository>();

      await authRepository.login(
        _empidController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Login Successful! Welcome.',
          alertType: AlertType.success,
        );
        context.read<AuthBloc>().add(LoggedIn());
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''), // Clean up the error message
          alertType: AlertType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 8.h),
            Text(
              'Please enter your credentials to continue.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 48.h),
            TextFormField(
              controller: _empidController,
              decoration: const InputDecoration(
                labelText: 'Employee ID',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter your Employee ID' : null,
            ),
            SizedBox(height: 24.h),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter your password' : null,
            ),
            SizedBox(height: 48.h),
            _isLoading
                ? Center(child: LoadingIndicator())
                : ElevatedButton(
                    onPressed: _performLogin,
                    child: const Text('LOGIN'),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _empidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}