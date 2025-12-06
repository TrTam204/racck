import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../api.dart';
import '../models.dart'; // <-- rất quan trọng: để có class Listing

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});
  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final api = Api();

  // form đăng bán
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  final _price = TextEditingController(text: '7000');
  final _contact = TextEditingController();

  // form tìm kiếm
  final _q = TextEditingController();
  double _radius = 5;

  // vị trí hiện tại dùng cho đăng / search
  Position? _pos;

  // danh sách kết quả search
  List<Listing> _items = [];
  List<Map<String, dynamic>> _drafts = [];
  int? _editingKey;
  Box? _draftBox;
  XFile? _image;
  final ImagePicker _picker = ImagePicker();

  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _contact.dispose();
    _q.dispose();
    _draftBox?.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initLocal();
  }

  Future<void> _initLocal() async {
    await Hive.initFlutter();
    _draftBox = await Hive.openBox('draft_listings');
    await _loadDrafts();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(m)));
  }

  // xin quyền + lấy toạ độ
  Future<void> _ensurePos() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Chưa có quyền vị trí');
      return;
    }

    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    setState(() {
      _pos = p;
    });
  }

  // gọi API tạo listing mới
  Future<void> _create() async {
    final price = double.tryParse(_price.text) ?? 0;

    setState(() => _busy = true);

    await api.createListing(
      _title.text.trim(),
      _desc.text.trim(),
      price,
      lat: _pos?.latitude,
      lng: _pos?.longitude,
      contactPhone: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
    );

    if (!mounted) return;
    setState(() => _busy = false);

    // reset form
    _title.clear();
    _desc.clear();
    _price.text = '7000';
    _contact.clear();
    _image = null;

    await _search();
    _toast('Đã đăng');
  }

  Future<void> _saveDraft() async {
    final price = double.tryParse(_price.text) ?? 0;
    final m = {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'pricePerKg': price,
      'contactPhone': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      'lat': _pos?.latitude,
      'lng': _pos?.longitude,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'imagePath': _image?.path,
    };
    if (_editingKey == null) {
      await _draftBox?.add(m);
    } else {
      await _draftBox?.put(_editingKey, m);
      _editingKey = null;
    }
    await _loadDrafts();
    _toast('Đã lưu bản nháp');
  }

  Future<void> _loadDrafts() async {
    final l = <Map<String, dynamic>>[];
    if (_draftBox != null) {
      for (final k in _draftBox!.keys) {
        final v = Map<String, dynamic>.from(_draftBox!.get(k));
        v['key'] = k;
        l.add(v);
      }
    }
    setState(() => _drafts = l);
  }

  void _editDraft(Map<String, dynamic> d) {
    _title.text = d['title']?.toString() ?? '';
    _desc.text = d['description']?.toString() ?? '';
    _price.text = (d['pricePerKg'] ?? 0).toString();
    _contact.text = d['contactPhone']?.toString() ?? '';
    _editingKey = d['key'] as int?;
    final p = d['imagePath']?.toString();
    _image = p == null || p.isEmpty ? null : XFile(p);
    _toast('Đã tải bản nháp lên form');
  }

  Future<void> _deleteDraft(int key) async {
    await _draftBox?.delete(key);
    await _loadDrafts();
  }

  // tìm kiếm listing quanh bán kính
  Future<void> _search() async {
    setState(() => _busy = true);

    // nếu chưa có vị trí thì xin
    if (_pos == null) {
      await _ensurePos();
    }

    final list = await api.searchListings(
      q: _q.text.trim().isEmpty ? null : _q.text.trim(),
      lat: _pos?.latitude,
      lng: _pos?.longitude,
      radiusKm: _pos == null ? null : _radius,
    );

    if (!mounted) return;
    setState(() {
      _items = list;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nguồn cung phế liệu')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ====== KHU ĐĂNG BÁN ======
              const _Section(title: 'Đăng bán'),
              const SizedBox(height: 8),

              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_image!.path),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              if (_image != null) const SizedBox(height: 8),

              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _price,
                decoration: const InputDecoration(
                  labelText: 'Giá/kg',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Số liên hệ (tuỳ chọn)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _ensurePos,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Lấy vị trí'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Đăng'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saveDraft,
                    icon: Icon(_editingKey == null ? Icons.save_alt : Icons.edit),
                    label: Text(_editingKey == null ? 'Lưu bản nháp' : 'Cập nhật nháp'),
                  ),
                ],
              ),

              const Divider(height: 32),

              // ====== KHU TÌM KIẾM ======
              const _Section(title: 'Tìm kiếm'),
              const SizedBox(height: 8),

              TextField(
                controller: _q,
                decoration: const InputDecoration(
                  labelText: 'Từ khoá (nhựa, giấy,...)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Text('Bán kính:'),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '${_radius.toStringAsFixed(0)} km',
                      value: _radius,
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                  ),
                  FilledButton(
                    onPressed: _search,
                    child: const Text('Tìm'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ====== KẾT QUẢ LISTINGS ======
              ..._items.map(
                (e) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      e.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.description),
                        const SizedBox(height: 4),
                        if (e.contactPhone != null && e.contactPhone!.isNotEmpty)
                          Text('Liên hệ: ${e.contactPhone}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            '${e.pricePerKg.toStringAsFixed(0)} đ/kg',
                          ),
                        ),
                        if (e.lat != null && e.lng != null)
                          const SizedBox(width: 8),
                        if (e.lat != null && e.lng != null)
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                          ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () => _showListingActions(e),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              const Divider(height: 32),
              const _Section(title: 'Bản nháp cục bộ'),
              const SizedBox(height: 8),
              ..._drafts.map(
                (d) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: (d['imagePath'] == null || (d['imagePath'] as String).isEmpty)
                        ? null
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(d['imagePath'] as String),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                    title: Text(d['title']?.toString() ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['description']?.toString() ?? ''),
                        const SizedBox(height: 4),
                        if ((d['contactPhone']?.toString() ?? '').isNotEmpty)
                          Text('Liên hệ: ${d['contactPhone']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editDraft(d),
                          icon: const Icon(Icons.edit),
                          tooltip: 'Chỉnh sửa',
                        ),
                        IconButton(
                          onPressed: () => _deleteDraft(d['key'] as int),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Xoá',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),

        if (_busy)
          Container(
            color: Colors.black.withValues(alpha: 0.06),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showListingActions(Listing e) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(e.description),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: (e.contactPhone == null || e.contactPhone!.isEmpty)
                      ? null
                      : () => _call(e.contactPhone!),
                  icon: const Icon(Icons.phone),
                  label: const Text('Gọi'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (e.lat == null || e.lng == null)
                      ? null
                      : () => _openMap(e.lat!, e.lng!),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Xem bản đồ'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyText('${e.title}\n${e.description}\nGiá: ${e.pricePerKg.toStringAsFixed(0)} đ/kg'),
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyText(phone);
      _toast('Thiết bị không hỗ trợ gọi trực tiếp, đã sao chép số');
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('Đã sao chép');
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) {
      setState(() => _image = x);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
