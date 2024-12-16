import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sars/auth/dashboard_page.dart';
import 'package:sars/auth/dl_prediction_page.dart';
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'repositories/user_repository.dart';
import 'main_page.dart';
import './utils/constants.dart';
import 'package:sars/firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use generated options
  );
  FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('7CE6FBEE-9F51-4C5E-9A97-97F065699F90'), // Replace with your actual site key
  );
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => UserRepository()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Gen Ai Remote Sensing App',
      theme: ThemeData(
        primaryColor: primaryColor,
        hintColor: accentColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainPage(), // Change the initial route to the HomePage
      routes: {
       // '/': (context) => MainPage(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    DashboardPage(), // Replace with your actual dashboard page
    DLPredictionPage(), // The DL prediction page
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'DL Prediction',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}
