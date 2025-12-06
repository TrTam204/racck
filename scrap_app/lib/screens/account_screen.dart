import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../env.dart';

import '../api.dart';
import '../models.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final api = Api();

  String? _username;
  String? _role;
  int? _customerId;
  int? _collectorId;

  Collector? _collector;

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender;
  final _addrCtrl = TextEditingController();

  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  final _newPass2 = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _avatarPath;
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addrCtrl.dispose();
    _oldPass.dispose();
    _newPass.dispose();
    _newPass2.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await api.getMe();
      _username = me['username']?.toString();
      _role = me['role']?.toString();

      final sp = await SharedPreferences.getInstance();
      _customerId = sp.getInt('customerId');
      _collectorId = sp.getInt('collectorId');
      final keyPath = 'profile_avatar_path_${_username ?? ''}';
      final keyUrl  = 'profile_avatar_url_${_username ?? ''}';
      _avatarPath = sp.getString(keyPath);
      _avatarUrl  = sp.getString(keyUrl);

      if (_role == 'customer' && _customerId != null) {
        final c = await api.getCustomer(_customerId!);
        _fullNameCtrl.text = c.fullName;
        _phoneCtrl.text = c.phone;
        _emailCtrl.text = c.email ?? '';
        _gender = _toViGender(c.gender);
        _addrCtrl.text = c.address ?? '';
      } else if (_role == 'collector' && _collectorId != null) {
        final list = await api.getCollectors();
        _collector = list.firstWhere(
          (e) => e.id == _collectorId,
          orElse: () => Collector(_collectorId!, ''),
        );
        _fullNameCtrl.text = _collector?.fullName ?? '';
        _phoneCtrl.text = _collector?.phone ?? '';
        _emailCtrl.text = _collector?.email ?? '';
        _gender = _toViGender(_collector?.gender);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi tải tài khoản: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    try {
      if (_role == 'customer' && _customerId != null) {
        await api.updateCustomer(_customerId!, {
          'id': _customerId,
          'fullName': _fullNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'gender': _gender,
          'address': _addrCtrl.text.trim(),
        });
      } else if (_role == 'collector' && _collectorId != null) {
        await api.updateCollector(
          _collectorId!,
          _collector?.companyId ?? 0,
          _fullNameCtrl.text.trim(),
          _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          gender: _gender,
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu thông tin')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
    }
  }

  Future<void> _changePassword() async {
    final p1 = _newPass.text;
    final p2 = _newPass2.text;
    if (p1.isEmpty || p2.isEmpty || p1 != p2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mật khẩu mới không hợp lệ')));
      return;
    }
    try {
      await api.changePassword(_oldPass.text, p1);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu')));
      _oldPass.clear();
      _newPass.clear();
      _newPass2.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi đổi mật khẩu: $e')));
    }
  }

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) {
      final sp = await SharedPreferences.getInstance();
      final keyPath = 'profile_avatar_path_${_username ?? ''}';
      final keyUrl  = 'profile_avatar_url_${_username ?? ''}';
      await sp.setString(keyPath, x.path);
      try {
        final url = await api.uploadAvatar(x.path);
        await sp.setString(keyUrl, url);
        _avatarUrl = url;
      } catch (_) {
        // nếu upload fail, vẫn hiển thị ảnh cục bộ
      }
      if (!mounted) return;
      setState(() {
        _avatarPath = x.path;
      });
    }
  }

  Future<void> _clearAvatar() async {
    final sp = await SharedPreferences.getInstance();
    final keyPath = 'profile_avatar_path_${_username ?? ''}';
    final keyUrl  = 'profile_avatar_url_${_username ?? ''}';
    await sp.remove(keyPath);
    await sp.remove(keyUrl);
    if (!mounted) return;
    setState(() {
      _avatarPath = null;
      _avatarUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage('${Env.baseUrl}${_avatarUrl!}')
                  : (_avatarPath == null || _avatarPath!.isEmpty
                      ? null
                      : FileImage(File(_avatarPath!)) as ImageProvider),
              child: ((_avatarUrl == null || _avatarUrl!.isEmpty) && (_avatarPath == null || _avatarPath!.isEmpty))
                  ? const Icon(Icons.person, size: 36, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_username ?? ''),
                const SizedBox(height: 4),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Đổi ảnh'),
                    ),
                    const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _avatarPath == null ? null : _clearAvatar,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xoá ảnh'),
                ),
                  ],
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        Text('Tài khoản: ${_username ?? ''}'),
        const SizedBox(height: 4),
        Text('Vai trò: ${_role ?? ''}'),
        const SizedBox(height: 8),
        if (_role == 'customer' || _role == 'collector') ...[
          Text('Họ tên: ${_fullNameCtrl.text}'),
          const SizedBox(height: 4),
          Text('Email: ${_emailCtrl.text}'),
          const SizedBox(height: 4),
          Text('Giới tính: ${_gender ?? ''}'),
          if (_role == 'customer') ...[
            const SizedBox(height: 4),
            Text('Địa chỉ: ${_addrCtrl.text}'),
          ],
        ],
      ],
    );

    final profileForm = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_role == 'customer' || _role == 'collector') ...[
          TextField(
            controller: _fullNameCtrl,
            decoration: const InputDecoration(labelText: 'Họ tên'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Điện thoại'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            items: const [
              DropdownMenuItem(value: 'Nam', child: Text('Nam')),
              DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
              DropdownMenuItem(value: 'Khác', child: Text('Khác')),
            ],
            onChanged: (v) => setState(() => _gender = v),
            decoration: const InputDecoration(labelText: 'Giới tính'),
          ),
          if (_role == 'customer') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _addrCtrl,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saveProfile,
            child: const Text('Lưu thông tin'),
          ),
        ],
      ],
    );

    final changePassForm = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _oldPass,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPass,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPass2,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _changePassword,
          child: const Text('Đổi mật khẩu'),
        ),
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          info,
          const Divider(height: 24),
          profileForm,
          const Divider(height: 24),
          changePassForm,
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ]
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')), 
      body: _loading ? const Center(child: CircularProgressIndicator()) : body,
    );
  }

  String? _toViGender(String? g) {
    if (g == null) return null;
    switch (g.toLowerCase()) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return g;
    }
  }
}
