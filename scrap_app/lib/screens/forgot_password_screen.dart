import 'package:flutter/material.dart';

import '../api.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final api = Api();
  final _user = TextEditingController();
  final _code = TextEditingController();
  final _newPass = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _codeShown;

  @override
  void dispose() {
    _user.dispose();
    _code.dispose();
    _newPass.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _loading = true;
      _error = null;
      _codeShown = null;
    });
    try {
      final c = await api.forgotPassword(_user.text.trim());
      if (!mounted) return;
      setState(() {
        _codeShown = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi yêu cầu mã: $e';
        _loading = false;
      });
    }
  }

  Future<void> _reset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.resetPassword(
        _user.text.trim(),
        _code.text.trim(),
        _newPass.text,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi đặt lại: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'Tài khoản',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _requestCode,
            child: const Text('Lấy mã đặt lại'),
          ),
          if (_codeShown != null) ...[
            const SizedBox(height: 12),
            Text('Mã: $_codeShown'),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Mã xác nhận',
              prefixIcon: Icon(Icons.verified),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu mới',
              prefixIcon: Icon(Icons.lock_reset),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _reset,
            icon: const Icon(Icons.check),
            label: const Text('Đặt lại mật khẩu'),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Center(child: SingleChildScrollView(child: body)),
    );
  }
}
