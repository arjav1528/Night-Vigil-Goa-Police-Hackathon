import 'dart:async';
import 'package:app/bloc/auth_bloc.dart';
import 'package:app/models/duty_assignment_model.dart';
import 'package:app/screens/auth/auth_screen.dart';
import 'package:app/screens/check_in_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class AppRouter {
  final AuthBloc authBloc;
  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/duty/:dutyId',
        builder: (context, state) {
          final duty = state.extra as DutyAssignment?;
          if (duty != null) {
            return CheckInScreen(duty: duty);
          }
          // Fallback if duty object is missing
          return const Scaffold(body: Center(child: Text('Error: Duty not found.')));
        },
      ),
    ],
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final onLoginPage = state.matchedLocation == '/login';
      final onSplashPage = state.matchedLocation == '/splash';

      if (authState is AuthInitial) return '/splash';
      if (authState is AuthUnauthenticated && !onLoginPage) return '/login';
      if (authState is AuthAuthenticated && (onLoginPage || onSplashPage)) return '/';
      
      return null;
    },
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}