import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../widgets/pp/pp_shell.dart';
import '../screens/dashboard/priorities_dashboard_screen.dart';
import '../screens/submit/submit_request_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/map/hotspot_map_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/help_center_screen.dart';
import '../screens/debug/api_debug_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'auth_state_notifier.dart';
import '../utils/auth_session_gate.dart';

class AppRouter {
  static bool _isSignedIn() =>
      FirebaseAuth.instance.currentUser != null ||
      AuthSessionGate.instance.hasSession;

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final signedIn = _isSignedIn();
      final location = state.matchedLocation;
      final isAuthPage =
          location == '/login' || location == '/register' || location == '/landing';
      final isPublicPage = isAuthPage || location == '/splash';

      if (location == '/debug') {
        return null;
      }

      if (signedIn && isAuthPage) {
        return '/home';
      }

      if (!signedIn && !isPublicPage) {
        return '/landing';
      }

      return null;
    },
    refreshListenable: AuthStateNotifier(),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/landing',
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const PpShellScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const PrioritiesDashboardScreen(),
      ),
      GoRoute(
        path: '/submit',
        name: 'submit',
        builder: (context, state) => const SubmitRequestScreen(),
      ),
      GoRoute(
        path: '/hotspots',
        name: 'hotspots',
        builder: (context, state) => const HotspotMapScreen(),
      ),
      GoRoute(
        path: '/submit-grievance',
        name: 'submit-grievance',
        builder: (context, state) => const SubmitRequestScreen(),
      ),
      GoRoute(
        path: '/grievances',
        name: 'grievances',
        redirect: (_, __) => '/home',
      ),
      GoRoute(
        path: '/grievance/:id',
        name: 'grievance-detail',
        redirect: (_, __) => '/home',
      ),
      GoRoute(
        path: '/map',
        name: 'map',
        redirect: (_, state) {
          if (state.uri.queryParameters['selectLocation'] == 'true') {
            return null;
          }
          return '/hotspots';
        },
        builder: (context, state) {
          return MapScreen(selectLocation: true);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        redirect: (_, __) => '/home',
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/help',
        name: 'help-center',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      // Admin routes
      GoRoute(
        path: '/admin',
        name: 'admin',
        redirect: (_, __) => '/dashboard',
      ),
      GoRoute(
        path: '/admin/users',
        name: 'admin-users',
        redirect: (_, __) => '/dashboard',
      ),
      GoRoute(
        path: '/admin/locations',
        name: 'admin-locations',
        redirect: (_, __) => '/dashboard',
      ),
      // Department route
      GoRoute(
        path: '/department',
        name: 'department',
        redirect: (_, __) => '/dashboard',
      ),
      // Debug screen (remove in production)
      GoRoute(
        path: '/debug',
        name: 'debug',
        builder: (context, state) => const ApiDebugScreen(),
      ),
    ],
  );
}

