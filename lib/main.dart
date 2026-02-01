import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'features/home/home_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'core/services/user_profile_service.dart';
import 'core/services/instance_generator_service.dart';
import 'core/services/notification_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/database/database_helper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final generator = InstanceGeneratorService();
      
      switch (task) {
        case 'generateDailyInstances':
        case 'midnightTask':
          // Run complete midnight task
          final result = await generator.runMidnightTask();
          print('Midnight task completed: $result');
          break;
        case 'markPendingAsMissed':
          final count = await generator.markYesterdayMissed();
          print('Marked $count instances as missed');
          break;
        default:
          print('Unknown task: $task');
      }
      return true;
    } catch (e) {
      print('WorkManager task error: $e');
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Pass async errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize services in parallel for faster startup
  try {
    await Future.wait([
      // Notification service
      NotificationService().initialize(),
      
      // Warm up database connection
      DatabaseHelper.instance.database,
      
      // Timezone initialization
      _initializeTimezone(),
    ]);
  } catch (e, stackTrace) {
    // Log initialization errors
    debugPrint('Initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  // Set up notification tap handler (if needed in future)
  // NotificationService().onNotificationTap = (routineId) { ... };


  // Initialize WorkManager for background tasks
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, // Set to false for production
  );

  // Register periodic task for midnight instance generation
  await Workmanager().registerPeriodicTask(
    'instance-generation',
    'generateDailyInstances',
    frequency: const Duration(hours:12), // Run twice daily
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(
      networkType: NetworkType.not_required,
    ),
  );

  // Run app
  runApp(
    const ProviderScope(
      child: AkshaApp(),
    ),
  );
}

Future<void> _initializeTimezone() async {
  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  } catch (e) {
    debugPrint('Timezone initialization error: $e');
  }
}

// Calculate delay until next midnight
Duration _calculateDelayToMidnight() {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return tomorrow.difference(now);
}

class AkshaApp extends ConsumerWidget {
  const AkshaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'Aksha',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), // Vibrant Indigo
          brightness: Brightness.light,
          primary: const Color(0xFF3F51B5),
          secondary: const Color(0xFF009688), // Teal Secondary
        ),
        useMaterial3: true,
        // Denser text for compact UI
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14, height: 1.2),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Compact margins
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.dark,
          primary: const Color(0xFF7986CB), // Lighter Indigo for Dark Mode
          secondary: const Color(0xFF80CBC4),
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        ),
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/sign-in': (context) => const SignInScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
      home: FutureBuilder<Map<String, bool>>(
        future: _checkAppState(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          final state = snapshot.data ?? {'onboarding': true, 'signedIn': false};
          
          if (!state['onboarding']!) {
            return const OnboardingScreen();
          } else if (!state['signedIn']!) {
            return const SignInScreen();
          } else {
            return const HomeScreen();
          }
        },
      ),
    );
  }
}

Future<Map<String, bool>> _checkAppState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    final profile = await UserProfileService.getProfile();
    final signedIn = profile != null;
    
    return {
      'onboarding': onboardingComplete,
      'signedIn': signedIn,
    };
  } catch (e) {
    print('Error checking app state: $e');
    return {'onboarding': false, 'signedIn': false};
  }
}

// Check authentication state
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Give splash screen a moment to display
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final isSignedIn = await UserProfileService.isSignedIn();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isSignedIn ? const HomeScreen() : const SignInScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// Splash screen
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.track_changes,
              size: 80,
              color: Color(0xFF6750A4),
            ),
            const SizedBox(height: 24),
            const Text(
              'AKSHA',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track Your Routines Honestly',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
