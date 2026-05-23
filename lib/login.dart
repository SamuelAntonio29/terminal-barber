import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'registro.dart';
import 'verificacao_email.dart';
import 'main.dart';
import 'app_bar_custom.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscure = true;

  // Instância única do GoogleSignIn
  final _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user!;
      await user.reload();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastLogin', DateTime.now().millisecondsSinceEpoch);

      if (!mounted) return;

      if (!user.emailVerified) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificacaoEmail()),
          (r) => false,
        );
        return;
      }

      final tela = await telaParaUsuario(user.uid);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => tela),
        (r) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_mapError(e.code));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erro: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginGoogle() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      // Desconecta sessão anterior para forçar seleção de conta
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Usuário cancelou
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user!;

      // Cria documento se for primeiro acesso
      final docRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'nome': user.displayName ?? '',
          'email': user.email ?? '',
          'telefone': '',
          'role': 'client',
          'criadoEm': DateTime.now().millisecondsSinceEpoch,
          'totalAtendidos': 0,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastLogin', DateTime.now().millisecondsSinceEpoch);

      if (!mounted) return;

      final tela = await telaParaUsuario(user.uid);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => tela),
        (r) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_mapError(e.code));
    } catch (e) {
      if (!mounted) return;
      // Ignora erro de cancelamento pelo usuário
      if (!e.toString().contains('sign_in_canceled') &&
          !e.toString().contains('network_error')) {
        _showSnackBar('Erro ao entrar com Google: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente mais tarde.';
      case 'account-exists-with-different-credential':
        return 'Este e-mail já está cadastrado com outro método.';
      default:
        return 'Erro: $code';
    }
  }

  void _showSnackBar(String msg, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = Color(0xFFD4A017);
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark ? Colors.white54 : Colors.black38;
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const AppBarCustom(title: ''),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bem-vindo',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entre na sua conta para continuar',
                  style: TextStyle(color: hintColor, fontSize: 14),
                ),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: textColor),
                          decoration: _dec(
                            'E-mail',
                            Icons.email_outlined,
                            hintColor,
                            borderColor,
                            gold,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe o e-mail'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          style: TextStyle(color: textColor),
                          decoration: _dec(
                            'Senha',
                            Icons.lock_outline,
                            hintColor,
                            borderColor,
                            gold,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: hintColor,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Informe a senha'
                              : null,
                        ),
                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _showForgotPassword(
                              context,
                              hintColor,
                              gold,
                              cardColor,
                              textColor,
                              borderColor,
                            ),
                            child: const Text(
                              'Esqueceu a senha?',
                              style: TextStyle(
                                color: Color(0xFFD4A017),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                              shadowColor: gold.withOpacity(0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: borderColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'ou',
                                style: TextStyle(
                                  color: hintColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: borderColor)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _isGoogleLoading ? null : _loginGoogle,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isGoogleLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: gold,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                        width: 22,
                                        height: 22,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.g_mobiledata,
                                          color: textColor,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Entrar com Google',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Não tem conta? ', style: TextStyle(color: hintColor)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Registro()),
                      ),
                      child: const Text(
                        'Criar conta',
                        style: TextStyle(
                          color: Color(0xFFD4A017),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(
    String label,
    IconData icon,
    Color hint,
    Color border,
    Color gold, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: hint),
      prefixIcon: Icon(icon, color: hint),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  void _showForgotPassword(
    BuildContext ctx,
    Color hintColor,
    Color gold,
    Color cardColor,
    Color textColor,
    Color borderColor,
  ) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (_, setModal) {
          bool sending = false;
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(sheet).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recuperar senha',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviaremos um link de redefinição para seu e-mail.',
                  style: TextStyle(color: hintColor, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    labelStyle: TextStyle(color: hintColor),
                    prefixIcon: Icon(Icons.email_outlined, color: hintColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: gold, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: sending
                        ? null
                        : () async {
                            if (ctrl.text.trim().isEmpty) return;
                            setModal(() => sending = true);
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                    email: ctrl.text.trim(),
                                  );
                              if (!ctx.mounted) return;
                              Navigator.pop(sheet);
                              _showSnackBar(
                                'E-mail de recuperação enviado!',
                                color: Colors.green,
                              );
                            } on FirebaseAuthException catch (e) {
                              setModal(() => sending = false);
                              _showSnackBar(
                                e.code == 'user-not-found'
                                    ? 'E-mail não cadastrado.'
                                    : 'Erro ao enviar e-mail.',
                              );
                            } catch (_) {
                              setModal(() => sending = false);
                              _showSnackBar('Erro ao enviar e-mail.');
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Enviar link',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
