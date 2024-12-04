import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'models/user_model.dart';
import 'screens/home/mentor/mentor_home_screen.dart';
import 'screens/home/mentee/mentee_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'PMU Mentor',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const LoginScreen(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );
            case '/mentor_home':
              final user = settings.arguments as UserModel;
              return MaterialPageRoute(
                builder: (_) => MentorHomeScreen(user: user),
              );
            case '/mentee_home':
              final user = settings.arguments as UserModel;
              return MaterialPageRoute(
                builder: (_) => MenteeHomeScreen(user: user),
              );
          }
        },
      ),
    );
  }
}
