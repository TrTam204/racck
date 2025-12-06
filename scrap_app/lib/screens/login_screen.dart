import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final api = Api();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String? _err;

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await api.login(
        _user.text.trim(),
        _pass.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootApp()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = 'Đăng nhập thất bại';
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _goRegister() async {
    // mở màn hình đăng ký và chờ kết quả
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );

    // nếu RegisterScreen pop(context, true) => đăng ký ok
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký thành công, hãy đăng nhập'),
        ),
      );
    }
  }

  Future<void> _goForgot() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đặt lại mật khẩu, hãy đăng nhập')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.recycling, size: 64, color: Colors.white),
              SizedBox(height: 8),
              Text('Scrap App', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Đăng nhập để tiếp tục', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );

    final form = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            if (_err != null)
              Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _doLogin,
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _loading ? null : _goRegister,
                  icon: const Icon(Icons.app_registration),
                  label: const Text('Đăng ký'),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : _goForgot,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Quên mật khẩu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            children: [
              header,
              const SizedBox(height: 16),
              form,
              const SizedBox(height: 24),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
