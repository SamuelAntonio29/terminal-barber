import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'login.dart';
import 'verificacao_email.dart';
import 'home_cliente.dart';
import 'home_owner.dart';
import 'notificacao_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificacaoService.init(); // ✅ Inicializa notificações
  runApp(const MyApp());
}

Future<Widget> telaParaUsuario(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!doc.exists || doc.data() == null) {
      final authUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nome': authUser?.displayName ?? '',
        'email': authUser?.email ?? '',
        'telefone': '',
        'role': 'client',
        'criadoEm': DateTime.now().millisecondsSinceEpoch,
        'totalAtendidos': 0,
      });
      return const HomeCliente();
    }

    final role = (doc.data()!['role'] as String?) ?? 'client';
    debugPrint('>>> role lido: $role');
    return role == 'owner' ? const HomeOwner() : const HomeCliente();
  } catch (e) {
    debugPrint('>>> Erro ao buscar role: $e');
    return const HomeCliente();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Widget _startScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await user.reload();
      if (!user.emailVerified) {
        _startScreen = const VerificacaoEmail();
      } else {
        _startScreen = await telaParaUsuario(user.uid);
      }
    } else {
      _startScreen = const Login();
    }

    setState(() {});
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    prefs.setBool('isDark', _themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Barber',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFFD4A017),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFD4A017),
        useMaterial3: true,
      ),
      home: _startScreen,
    );
  }
}
