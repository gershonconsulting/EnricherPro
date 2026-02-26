import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/landing_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/main_layout.dart';
import 'screens/contacts_screen.dart';
import 'providers/contact_provider.dart';
import 'models/file_upload.dart';
import 'models/csv_field_analysis.dart';
import 'services/file_upload_service.dart';
import 'test_enrichment_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive adapters
  Hive.registerAdapter(FileUploadAdapter());
  Hive.registerAdapter(CsvFieldInfoAdapter());
  Hive.registerAdapter(CsvFieldAnalysisAdapter());
  
  // Open Hive boxes
  await FileUploadService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContactProvider(),
      child: MaterialApp(
        title: 'EnricherPro.com - Professional B2B Contact Enrichment',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 4,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LandingScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/dashboard': (context) => const MainLayout(),
          '/contacts': (context) => const ContactsScreen(),
          '/test': (context) => const TestEnrichmentPage(),
        },
      ),
    );
  }
}
