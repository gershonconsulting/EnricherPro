import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/main_layout.dart';
import 'screens/contacts_screen.dart';
import 'screens/user_files_screen.dart';
import 'providers/contact_provider.dart';
import 'providers/auth_provider.dart';
import 'models/file_upload.dart';
import 'models/csv_field_analysis.dart';
import 'services/file_upload_service.dart';
import 'test_enrichment_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive local storage
  await Hive.initFlutter();
  Hive.registerAdapter(FileUploadAdapter());
  Hive.registerAdapter(CsvFieldInfoAdapter());
  Hive.registerAdapter(CsvFieldAnalysisAdapter());
  await FileUploadService.init();

  // Restore auth session before first frame
  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
      ],
      child: MaterialApp(
        title: 'EnricherPro — Professional B2B Contact Enrichment',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.light),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        // Initial route determined by auth state
        home: authProvider.isAuthenticated
            ? const MainLayout()
            : const LandingScreen(),
        routes: {
          '/': (context) => const LandingScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/dashboard': (context) => const MainLayout(),
          '/contacts': (context) => const ContactsScreen(),
          '/my-files': (context) => const UserFilesScreen(),
          '/test': (context) => const TestEnrichmentPage(),
        },
        // Auth guard: redirect unauthenticated users away from protected routes
        onGenerateRoute: (settings) {
          const protected = {'/dashboard', '/contacts', '/my-files'};
          if (protected.contains(settings.name)) {
            final auth = authProvider;
            if (!auth.isAuthenticated) {
              return MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                  settings: const RouteSettings(name: '/login'));
            }
          }
          return null; // Fall through to routes map
        },
      ),
    );
  }
}
