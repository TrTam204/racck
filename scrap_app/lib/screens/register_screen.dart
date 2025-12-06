import 'package:flutter/material.dart';
import '../api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = Api();

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _doRegister() async {
    final u = _userCtrl.text.trim();
    final p1 = _passCtrl.text;
    final p2 = _pass2Ctrl.text;

    setState(() {
      _error = null;
      _success = null;
    });

    if (u.isEmpty || p1.isEmpty || p2.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ thông tin';
      });
      return;
    }

    if (p1 != p2) {
      setState(() {
        _error = 'Mật khẩu nhập lại không khớp';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // gọi API đăng ký customer
      await _api.registerCustomerRole(
        username: u,
        password: p1,
      );

      if (!mounted) return;
      setState(() {
        _success = 'Tạo tài khoản thành công. Bạn có thể đăng nhập.';
      });

      // quay về màn Login và cho biết là đăng ký ok
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Đăng ký thất bại: $e';
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: 'Tài khoản',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass2Ctrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nhập lại mật khẩu',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),

          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),

          if (_success != null)
            Text(
              _success!,
              style: const TextStyle(color: Colors.green),
            ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _loading ? null : _doRegister,
            icon: const Icon(Icons.app_registration),
            label: const Text("Đăng ký"),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo tài khoản mới"),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(child: body),
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
