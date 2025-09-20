import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:night_vigil/screen/auth/login_tab.dart';
import 'package:night_vigil/screen/auth/register_tab.dart';
import 'package:night_vigil/theme.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Officer Portal'),
          bottom: TabBar(
            indicatorColor: AppColors.secondary,
            indicatorWeight: 4.0,
            labelStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: 16.sp,
                ),
            unselectedLabelStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.onPrimary.withOpacity(0.7),
                  fontSize: 16.sp,
                ),
            tabs: const [
              Tab(text: 'LOGIN'),
              Tab(text: 'REGISTER'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LoginTab(),
            RegisterTab(),
          ],
        ),
      ),
    );
  }
}