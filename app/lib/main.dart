import 'package:app/api/auth_repository.dart';
import 'package:app/api/duty_repository.dart';
import 'package:app/bloc/auth_bloc.dart';
import 'package:app/router.dart';
import 'package:app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  String url = dotenv.env['BACKEND_URL'] ?? 'development';
  debugPrint('Backend URL: $url');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authRepository = AuthRepository();
  final dutyRepository = DutyRepository();
  final authBloc = AuthBloc(authRepository: authRepository)..add(AppStarted());

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: dutyRepository),
      ],
      child: BlocProvider.value(
        value: authBloc,
        child: MyApp(authBloc: authBloc),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthBloc authBloc;
  const MyApp({super.key, required this.authBloc});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(authBloc: authBloc);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Night Vigil',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          routerConfig: appRouter.router,
        );
      },
    );
  }
}