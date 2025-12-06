import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  final FlutterTts _tts = FlutterTts();

  String? _mat; // chất liệu giả định
  String? _clean; // độ sạch
  String? _shape; // hình dạng
  bool? _magnet; // hút nam châm?
  bool? _transparent; // trong suốt?
  String? _sound; // âm thanh khi gõ
  String? _item; // vật phẩm mẫu
  String? _resin; // mã nhựa resin

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: const FlexibleSpaceBar(
              title: Text('Phân loại rác'),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildGuided(),
          ),
        ],
      ),
    );
  }

  

  Widget _buildGuided() {
    final materials = [
      'Giấy','Nhựa','Kim loại','Thủy tinh','Hữu cơ','Pin/Điện tử','Vải dệt','Gỗ','Cao su','Gốm sứ'
    ];
    final cleanliness = [
      'Sạch','Có dầu/mỡ','Ướt','Có mùi','Bụi/bẩn'
    ];
    final shapes = [
      'Chai/lọ','Lon/hộp','Tấm/miếng','Sợi/vải','Hạt/viên','Mảnh vụn','Thiết bị'
    ];
    final sounds = ['Leng keng','Ting/cạch','Đục','Không rõ'];
    final items = [
      'Chai PET','Lon nhôm','Bình thuỷ tinh','Carton','Giấy A4','Túi nylon','Pin AA/AAA','Điện thoại cũ','Vải quần áo','Lốp cao su','Gỗ vụn','Gốm sứ vỡ'
    ];
    final resins = ['PET (1)','HDPE (2)','PVC (3)','LDPE (4)','PP (5)','PS (6)','Khác (7)'];

    final res = _guidedResult();

    final result = res == null
        ? const SizedBox.shrink()
        : Card(
            child: ListTile(
              leading: const Icon(Icons.category),
              title: Text('Kết quả: ${res['label']}'),
              subtitle: Text('Lý do: ${(res['reasons'] as List<String>).join(', ')}'),
            ),
          );

    List<String> tipsFor(String label) {
      final tips = <String>[];
      switch (label) {
        case 'Kim loại':
          tips.addAll(['Tách vật sắc nhọn', 'Giữ khô ráo trước khi giao']);
          break;
        case 'Thủy tinh':
          tips.addAll(['Bọc kín tránh vỡ', 'Không trộn với rác ướt']);
          break;
        case 'Nhựa':
          tips.addAll(['Rửa sạch dầu mỡ', 'Tháo nắp/nhãn khi có thể']);
          break;
        case 'Giấy':
          tips.addAll(['Giữ khô, tránh ướt', 'Gấp phẳng']);
          break;
        case 'Hữu cơ':
          tips.addAll(['Tách khỏi rác tái chế', 'Ủ phân nếu phù hợp']);
          break;
        case 'Pin/Điện tử':
          tips.addAll(['Không bỏ vào rác thường', 'Đưa đến điểm thu gom pin/điện tử']);
          break;
        case 'Vải dệt':
          tips.addAll(['Đóng gói gọn', 'Giặt nếu quá bẩn']);
          break;
        case 'Cao su':
          tips.addAll(['Làm sạch bề mặt', 'Giao theo lô']);
          break;
        case 'Gốm sứ':
          tips.addAll(['Bọc chống vỡ', 'Không trộn thuỷ tinh']);
          break;
        case 'Gỗ':
          tips.addAll(['Phân loại mùn cưa riêng', 'Giữ khô']);
          break;
        default:
          tips.add('Kiểm tra lại tiêu chí để phân loại chính xác');
      }
      return tips;
    }

    Widget advice(String label) {
      final tips = tipsFor(label);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Khuyến nghị xử lý'),
              const SizedBox(height: 8),
              ...tips.map((t) => Text('- $t')),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await _tts.setLanguage('vi-VN');
                      await _tts.setSpeechRate(0.48);
                      final s = 'Kết quả: $label. Khuyến nghị: ${tips.join(', ')}';
                      await _tts.speak(s);
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Đọc lời khuyên'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _tts.stop();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Dừng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        DropdownButtonFormField<String>(
          initialValue: _item,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() { _item = v; _applyPreset(v); }),
          decoration: const InputDecoration(labelText: 'Vật phẩm (mẫu)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _mat,
          items: materials.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _mat = v),
          decoration: const InputDecoration(labelText: 'Chất liệu'),
        ),
        if (_mat == 'Nhựa') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _resin,
            items: resins.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _resin = v),
            decoration: const InputDecoration(labelText: 'Nhựa (mã resin)'),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _clean,
          items: cleanliness.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _clean = v),
          decoration: const InputDecoration(labelText: 'Độ sạch'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _shape,
          items: shapes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _shape = v),
          decoration: const InputDecoration(labelText: 'Hình dạng'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          initialValue: _magnet,
          items: const [
            DropdownMenuItem(value: true, child: Text('Hút nam châm')),
            DropdownMenuItem(value: false, child: Text('Không hút')),
          ],
          onChanged: (v) => setState(() => _magnet = v),
          decoration: const InputDecoration(labelText: 'Nam châm'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          initialValue: _transparent,
          items: const [
            DropdownMenuItem(value: true, child: Text('Trong suốt')),
            DropdownMenuItem(value: false, child: Text('Không trong')),
          ],
          onChanged: (v) => setState(() => _transparent = v),
          decoration: const InputDecoration(labelText: 'Mức trong suốt'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sound,
          items: sounds.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _sound = v),
          decoration: const InputDecoration(labelText: 'Âm thanh khi gõ'),
        ),
        const SizedBox(height: 16),
        result,
        if (res != null) advice(res['label'] as String),
      ],
    ),
  );
  }

  Map<String, dynamic>? _guidedResult() {
    final reasons = <String>[];
    String? label;

    if (_mat == 'Kim loại' || _sound == 'Leng keng' || _magnet == true) {
      label = 'Kim loại';
      reasons.add('Âm leng keng/ hút nam châm');
    }
    if (_mat == 'Thủy tinh' || _sound == 'Ting/cạch' || _transparent == true) {
      label = 'Thủy tinh';
      reasons.add('Trong suốt/ âm ting/cạch');
    }
    if (_mat == 'Nhựa' || _sound == 'Đục' || _shape == 'Chai/lọ') {
      label = 'Nhựa';
      reasons.add('Chai/lọ nhựa, âm đục');
    }
    if (_mat == 'Giấy' || _shape == 'Tấm/miếng') {
      label = 'Giấy';
      reasons.add('Dạng tờ/tấm');
    }
    if (_mat == 'Hữu cơ') {
      label = 'Hữu cơ';
      reasons.add('Thức ăn, lá cây');
    }
    if (_mat == 'Pin/Điện tử' || _shape == 'Thiết bị') {
      label = 'Pin/Điện tử';
      reasons.add('Thiết bị điện tử/pin');
    }
    if (_mat == 'Vải dệt' || _shape == 'Sợi/vải') {
      label = 'Vải dệt';
      reasons.add('Sợi/vải');
    }

    if (_mat == 'Nhựa' && _resin != null) {
      reasons.add('Mã resin: $_resin');
      label = '${label ?? 'Nhựa'} ($_resin)';
    }

    if (label == null) return null;
    if (_clean != null && _clean != 'Sạch') {
      reasons.add('Cần làm sạch trước khi phân loại');
    }
    return {
      'label': label,
      'reasons': reasons,
    };
  }

  void _applyPreset(String? item) {
    switch (item) {
      case 'Chai PET':
        _mat = 'Nhựa'; _shape = 'Chai/lọ'; _transparent = true; _magnet = false; _sound = 'Đục'; _resin = 'PET (1)'; _clean ??= 'Sạch';
        break;
      case 'Lon nhôm':
        _mat = 'Kim loại'; _shape = 'Lon/hộp'; _transparent = false; _magnet = false; _sound = 'Leng keng'; _clean ??= 'Sạch';
        break;
      case 'Bình thuỷ tinh':
        _mat = 'Thủy tinh'; _shape = 'Chai/lọ'; _transparent = true; _magnet = false; _sound = 'Ting/cạch'; _clean ??= 'Sạch';
        break;
      case 'Carton':
        _mat = 'Giấy'; _shape = 'Tấm/miếng'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Sạch';
        break;
      case 'Giấy A4':
        _mat = 'Giấy'; _shape = 'Tấm/miếng'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Sạch';
        break;
      case 'Túi nylon':
        _mat = 'Nhựa'; _shape = 'Tấm/miếng'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _resin = 'LDPE (4)'; _clean ??= 'Sạch';
        break;
      case 'Pin AA/AAA':
        _mat = 'Pin/Điện tử'; _shape = 'Thiết bị'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Sạch';
        break;
      case 'Điện thoại cũ':
        _mat = 'Pin/Điện tử'; _shape = 'Thiết bị'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Sạch';
        break;
      case 'Vải quần áo':
        _mat = 'Vải dệt'; _shape = 'Sợi/vải'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Sạch';
        break;
      case 'Lốp cao su':
        _mat = 'Cao su'; _shape = 'Thiết bị'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Có mùi';
        break;
      case 'Gỗ vụn':
        _mat = 'Gỗ'; _shape = 'Mảnh vụn'; _transparent = false; _magnet = false; _sound = 'Không rõ'; _clean ??= 'Bụi/bẩn';
        break;
      case 'Gốm sứ vỡ':
        _mat = 'Gốm sứ'; _shape = 'Mảnh vụn'; _transparent = false; _magnet = false; _sound = 'Ting/cạch'; _clean ??= 'Sạch';
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
