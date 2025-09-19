import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:night_vigil/api/auth.dart';
import 'package:night_vigil/theme.dart';
import 'package:night_vigil/utils/alert.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Night Vigil',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            // This will now work correctly
            String result = await AuthServices.login('test', 'test', context);
            CustomSnackBar.show(
              context,
              message: result,
              alertType: AlertType.success,
            );
          },
          child: const Text('Night Vigil Home Screen'),
        ),
      ),
    );
  }
}