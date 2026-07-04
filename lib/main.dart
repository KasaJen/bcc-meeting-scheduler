import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/login_page.dart'; 
import 'pages/admin_dashboard.dart'; 
import 'pages/dinas_dashboard.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BCC Meeting Scheduler',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(), 
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  Widget _homeWidget = const LoginPage();

  @override
  void initState() {
    super.initState();
    _checkSessionAndRole();
  }

  Future<void> _checkSessionAndRole() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();

        final role = response['role']?.toString().toLowerCase(); 

        if (role == 'admin') {
          _homeWidget = const AdminDashboard(); 
        } else {
          _homeWidget = const DinasDashboard(); 
        }
      } catch (e) {
        _homeWidget = const LoginPage();
      }
    } else {
      _homeWidget = const LoginPage();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _homeWidget;
  }
}