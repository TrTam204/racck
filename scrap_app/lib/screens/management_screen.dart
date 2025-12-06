import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin {
  final api = Api();

  late final TabController _tab;

  // TAB "Khách hàng"
  List<Customer> _customers = [];

  // TAB "DN & Collector"
  //
  // mỗi item company dạng:
  // {
  //   "id": 1,
  //   "name": "...",
  //   "contactPhone": "...",
  //   "address": "...",
  //   "collectors": [
  //     {"id":2,"fullName":"...","phone":"...","companyId":1, ...},
  //     ...
  //   ]
  // }
  List<Map<String, dynamic>> _companies = [];

  // tất cả user trong hệ thống (chỉ admin mới gọi được)
  // [
  //   {"id":5,"username":"nvA","role":"collector","collectorId":3,...},
  //   ...
  // ]
  List<Map<String, dynamic>> _allUsers = [];

  // TAB "Đơn hàng"
  List<PickupRequest> _orders = [];

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {})); // để FAB đổi theo tab
    _loadAll();
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

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final customersFut = api.getCustomers();
      final companiesFut = api.getCompanies();
      final usersFut = api.getAllUsersAdmin(); // cần token admin
      final ordersFut = api.getPickups(); // tất cả đơn

      final results = await Future.wait([
        customersFut,
        companiesFut,
        usersFut,
        ordersFut,
      ]);

      if (!mounted) return;

      _customers = results[0] as List<Customer>;
      _companies = results[1] as List<Map<String, dynamic>>;
      _allUsers = results[2] as List<Map<String, dynamic>>;
      _orders = results[3] as List<PickupRequest>;
    } catch (e) {
      if (!mounted) return;
      _error = 'Lỗi tải dữ liệu quản lý: $e';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  // ==== helper dialog nhập text nhanh ====

  Future<String?> _prompt(String label, {String? initial}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==== Tab KH: CRUD khách hàng =========================================

  Future<void> _addCustomer() async {
    final name = await _prompt('Tên KH');
    if (name == null || name.isEmpty) return;

    final phone = await _prompt('Điện thoại');
    if (phone == null || phone.isEmpty) return;

    await api.createCustomer(name, phone, null);
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _editCustomer(Customer c) async {
    final nameCtrl = TextEditingController(text: c.fullName);
    final phoneCtrl = TextEditingController(text: c.phone);
    final emailCtrl = TextEditingController(text: c.email ?? '');
    String? genderValue = _toViGender(c.gender);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sửa khách hàng'),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên KH',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Điện thoại',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: genderValue,
              items: const [
                DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                DropdownMenuItem(value: 'Khác', child: Text('Khác')),
              ],
              onChanged: (v) => genderValue = v,
              decoration: const InputDecoration(labelText: 'Giới tính'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Huỷ'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiếu tên/điện thoại')),
      );
      return;
    }

    await api.updateCustomer(c.id, {
      'id': c.id,
      'fullName': name,
      'phone': phone,
      'email': email.isNotEmpty ? email : null,
      'gender': genderValue,
      'address': c.address,
    });

    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _delCustomer(Customer c) async {
    await api.deleteCustomer(c.id);
    if (!mounted) return;
    await _loadAll();
  }

  // ==== Tab DN & Collector: CRUD công ty / collector =====================

  Future<void> _addCompany() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thêm doanh nghiệp'),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên công ty',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Điện thoại công ty',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Huỷ'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Thêm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiếu tên/điện thoại công ty')),
      );
      return;
    }

    try {
      await api.createCompany(name, phone, null);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã thêm doanh nghiệp')));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi thêm: $e')));
    }
  }

  Future<void> _addCollector(int companyId) async {
    final n = await _prompt('Tên nhân viên thu gom');
    if (n == null || n.isEmpty) return;

    final p = await _prompt('Điện thoại nhân viên');
    if (p == null || p.isEmpty) return;

    await api.createCollector(companyId, n, p);
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _deleteCompany(int companyId) async {
    await api.deleteCompany(companyId);
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _deleteCollector(int collectorId) async {
    await api.deleteCollector(collectorId);
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _editCollector(Map<String, dynamic> cl) async {
    final cid = cl['id'] as int;
    final companyId = cl['companyId'] as int? ?? 0;
    final nameCtrl = TextEditingController(text: cl['fullName']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: cl['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: cl['email']?.toString() ?? '');
    String? genderValue = _toViGender(cl['gender']?.toString());

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sửa nhân viên #$cid'),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Điện thoại', prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: genderValue,
              items: const [
                DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                DropdownMenuItem(value: 'Khác', child: Text('Khác')),
              ],
              onChanged: (v) => genderValue = v,
              decoration: const InputDecoration(labelText: 'Giới tính'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Huỷ'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiếu họ tên/điện thoại')),
      );
      return;
    }

    await api.updateCollector(
      cid,
      companyId,
      name,
      phone,
      email: email.isNotEmpty ? email : null,
      gender: genderValue,
    );

    if (!mounted) return;
    await _loadAll();
  }

  // ==== Cấp tài khoản đăng nhập cho collector ===========================
  //
  // Gọi POST /api/admin/createCollectorUser
  // cần token role=admin
  //
  Future<void> _showCreateLoginDialog(int collectorId) async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cấp tài khoản đăng nhập'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Collector #$collectorId'),
            const SizedBox(height: 12),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username đăng nhập',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final u = userCtrl.text.trim();
    final p = passCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiếu username / password')),
      );
      return;
    }

    try {
      await api.createCollectorUser(
        collectorId: collectorId,
        username: u,
        password: p,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo tài khoản đăng nhập')),
      );

      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo tài khoản: $e')),
      );
    }
  }

  // Kiểm tra collector đã có tài khoản login chưa
  // -> trả về username nếu có, null nếu chưa
  String? _loginOfCollector(int collectorId) {
    for (final u in _allUsers) {
      if ((u['role'] == 'collector') &&
          (u['collectorId'] == collectorId)) {
        return u['username']?.toString();
      }
    }
    return null;
  }

  // ==== Tab Đơn hàng: helpers hiển thị trạng thái =======================

  String _statusName(int s) {
    switch (s) {
      case 0:
        return 'Chờ xử lý';
      case 1:
        return 'Đã nhận';
      case 2:
        return 'Đang thực hiện';
      case 3:
        return 'Hoàn tất';
      case 4:
        return 'Đã huỷ';
      default:
        return '?';
    }
  }

  // ==== BUILD UI CHO TỪNG TAB ==========================================

  Widget _buildTabCustomers() {
    return ListView.separated(
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = _customers[i];
        return ListTile(
          title: Text('${c.fullName} • ${c.phone}'),
          subtitle: Text(c.address ?? ''),
          trailing: Wrap(
            spacing: 6,
            children: [
              TextButton(
                onPressed: () => _editCustomer(c),
                child: const Text('Sửa'),
              ),
              TextButton(
                onPressed: () => _delCustomer(c),
                child: const Text('Xoá'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabCompaniesCollectors() {
    return ListView.builder(
      itemCount: _companies.length,
      itemBuilder: (_, i) {
        final co = _companies[i];
        final List cols = (co['collectors'] ?? []) as List;

        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header công ty + nút thêm collector / xoá DN
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${co['id']} ${co['name']} • ${co['contactPhone'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _addCollector(co['id'] as int),
                      child: const Text('Thêm collector'),
                    ),
                    TextButton(
                      onPressed: () => _deleteCompany(co['id'] as int),
                      child: const Text('Xoá DN'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // danh sách collector trong công ty
                ...cols.map((cl) {
                  final cid = cl['id'] as int;
                  final usernameIssued = _loginOfCollector(cid);

                  return ListTile(
                    title: Text(
                      '#$cid ${cl['fullName']} • ${cl['phone']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      usernameIssued == null
                          ? 'Chưa có tài khoản đăng nhập'
                          : 'Đã cấp TK: $usernameIssued',
                      style: TextStyle(
                        fontSize: 12,
                        color: usernameIssued == null
                            ? Colors.redAccent
                            : Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _editCollector(cl as Map<String, dynamic>),
                          child: const Text('Sửa'),
                        ),
                        if (usernameIssued == null)
                          OutlinedButton(
                            onPressed: () => _showCreateLoginDialog(cid),
                            child: const Text('Cấp TK'),
                          ),
                        TextButton(
                          onPressed: () => _deleteCollector(cid),
                          child: const Text('Xoá'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabOrders() {
    if (_orders.isEmpty) {
      return const Center(
        child: Text('Chưa có đơn thu gom nào.'),
      );
    }

    return ListView.separated(
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final o = _orders[i];

        final custName = o.customer?.fullName ?? '(khách?)';
        final custPhone = o.customer?.phone ?? '';
        final kgStr = '${o.quantityKg} kg ${o.scrapType}';
        final st = _statusName(o.status);

        // ===== CHỖ GÂY LỖI LÚC NÃY =====
        // app bạn hiện chưa có field như `acceptedByCollectorId`
        // nên mình tạm không show collector nhận đơn
        final collectorLine = 'Collector: (chưa hỗ trợ hiển thị)';

        return ListTile(
          title: Text(
            'Đơn #${o.id} • $st',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kgStr),
              Text('Khách: $custName - $custPhone'),
              Text(collectorLine),
            ],
          ),
          trailing: IconButton(
            onPressed: () => _confirmDeleteOrder(o.id),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Xoá đơn',
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteOrder(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ đơn thu gom'),
        content: Text('Bạn chắc chắn muốn huỷ đơn #$id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.updatePickupStatus(id, 4); // 4 = Cancelled
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã huỷ đơn')));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi huỷ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTabCustomers = _tab.index == 0;
    final isTabCompanies = _tab.index == 1;
    // tab 2 ("Đơn hàng") không có FAB

    Widget? fab;
    if (isTabCustomers) {
      fab = FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
      );
    } else if (isTabCompanies) {
      fab = FloatingActionButton(
        onPressed: _addCompany,
        child: const Icon(Icons.add_business),
      );
    } else {
      fab = null;
    }

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : TabBarView(
                controller: _tab,
                children: [
                  _buildTabCustomers(),
                  _buildTabCompaniesCollectors(),
                  _buildTabOrders(),
                ],
              ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Khách hàng'),
            Tab(text: 'Doanh nghiệp & Nhân viên'),
            Tab(text: 'Đơn hàng'),
          ],
        ),
      ),
      floatingActionButton: fab,
      body: body,
    );
  }
}
