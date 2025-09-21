import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';
import 'package:night_vigil/screen/check_in_screen.dart';
import 'package:night_vigil/screen/home_screen.dart';
import 'package:night_vigil/screen/login_screen.dart';
import 'package:night_vigil/screen/splash_screen.dart';


class AppRouter {
  final AuthBloc authBloc;
  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/duty/:dutyId',
        builder: (context, state) {
          // --- THIS IS THE FIX ---
          // Check if the 'extra' data exists before trying to use it.
          if (state.extra is DutyAssignment && state.extra != null) {
            final duty = state.extra as DutyAssignment;
            return CheckInScreen(duty: duty);
          } else {
            // If the data is missing, show an error or an empty screen.
            // It's often best to redirect back home in this case.
            // Note: A direct redirect isn't recommended inside a builder.
            // This is a simple fallback UI.
            return const Scaffold(
              body: Center(
                child: Text('Error: Duty details not found.'),
              ),
            );
          }
        },
      ),
    ],
    initialLocation: '/splash',

    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final onLoginPage = state.matchedLocation == '/login';

      if (authState is AuthInitial) {
        return '/splash';
      }

      if (authState is AuthUnauthenticated && !onLoginPage) {
        return '/login';
      }

      if (authState is AuthAuthenticated && ( onLoginPage || state.matchedLocation == '/splash')) {
        return '/';
      }

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