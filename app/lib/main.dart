import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:night_vigil/api/auth_repository.dart';
import 'package:night_vigil/api/duty_repository.dart'; // <-- Import DutyRepository
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/router.dart';
import 'package:night_vigil/theme.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthRepository _authRepository;
  late final DutyRepository _dutyRepository;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _dutyRepository = DutyRepository(); // <-- Create the instance
    _authBloc = AuthBloc(authRepository: _authRepository)..add(AppStarted());
    _appRouter = AppRouter(authBloc: _authBloc);
  }

  @override
  Widget build(BuildContext context) {
    // Use MultiRepositoryProvider to provide all your repositories
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: _dutyRepository),
      ],
      child: BlocProvider.value(
        value: _authBloc,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (context, child) {
            return MaterialApp.router(
              title: 'Night Vigil',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              routerConfig: _appRouter.router,
            );
          },
        ),
      ),
    );
  }
}