import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/screen/home_screen.dart';
import 'package:night_vigil/screen/login_screen.dart';
import 'package:night_vigil/screen/splash_screen.dart';


class AppRouter {
  final AuthBloc authBloc;
  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    // Define all the navigation paths (routes) for your app
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
      // Example of a route with a parameter:
      // GoRoute(
      //   path: '/duty/:id',
      //   builder: (context, state) {
      //     final dutyId = state.pathParameters['id']!;
      //     return DutyDetailsScreen(dutyId: dutyId);
      //   },
      // ),
    ],
    // Set the initial location to a splash screen while the app initializes
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

    // This crucial line makes GoRouter listen to changes in your AuthBloc state
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
  );
}

// This helper class is what allows GoRouter to be reactive to your BLoC's stream of states.
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