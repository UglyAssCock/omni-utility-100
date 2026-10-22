import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class QrToolScreen extends StatefulWidget {
  final String toolId;
  const QrToolScreen({super.key, required this.toolId});

  @override
  State<QrToolScreen> createState() => _QrToolScreenState();
}

class _QrToolScreenState extends State<QrToolScreen> {
  final ImagePicker _picker = ImagePicker();
  List<String> _history = [];
  List<Map<String, String>> _scanResults = [];
  bool _busy = false;

  // Generators
  final TextEditingController _textCtrl = TextEditingController(text: 'https://flutter.dev');
  final TextEditingController _ssidCtrl = TextEditingController();
  final TextEditingController _wifiPassCtrl = TextEditingController();
  String _wifiAuth = 'WPA';

  final TextEditingController _vNameCtrl = TextEditingController();
  final TextEditingController _vPhoneCtrl = TextEditingController();
  final TextEditingController _vEmailCtrl = TextEditingController();
  final TextEditingController _vOrgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _ssidCtrl.dispose();
    _wifiPassCtrl.dispose();
    _vNameCtrl.dispose();
    _vPhoneCtrl.dispose();
    _vEmailCtrl.dispose();
    _vOrgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('qr_history') ?? [];
    });
  }

  Future<void> _addHistory(String val) async {
    if (val.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final entry = '${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')} | $val';
    _history.insert(0, entry);
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    await prefs.setStringList('qr_history', _history);
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('qr_history');
    setState(() => _history.clear());
  }

  Future<void> _scanImage({required bool fromCamera}) async {
    final xfile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (xfile == null) return;
    setState(() => _busy = true);
    try {
      final results = await NativeBridge.scanBarcodeFile(xfile.path);
      setState(() => _scanResults = results);
      for (final r in results) {
        final v = r['value'] ?? '';
        if (v.isNotEmpty) {
          await _addHistory(v);
        }
      }
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.tr('No QR or Barcode detected in image.', 'لم يتم العثور على رمز في الصورة.'),
            ),
          ),
        );
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  String _buildWifiPayload() {
    return 'WIFI:T:$_wifiAuth;S:${_ssidCtrl.text};P:${_wifiPassCtrl.text};;';
  }

  String _buildVCardPayload() {
    return 'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:${_vNameCtrl.text}\n'
        'ORG:${_vOrgCtrl.text}\n'
        'TEL:${_vPhoneCtrl.text}\n'
        'EMAIL:${_vEmailCtrl.text}\n'
        'END:VCARD';
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'أدوات QR والباركود',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (id == 'qr_scanner' || id == 'barcode_scanner' || id == 'qr_gallery') ...[
            Row(
              children: [
                if (id != 'qr_gallery')
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: Text(AppStrings.tr('Scan with Camera', 'مسح بالكاميرا')),
                      onPressed: () => _scanImage(fromCamera: true),
                    ),
                  ),
                if (id != 'qr_gallery') const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.photo_library),
                    label: Text(AppStrings.tr('Scan from Gallery', 'مسح من المعرض')),
                    onPressed: () => _scanImage(fromCamera: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_scanResults.isNotEmpty)
              ..._scanResults.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ResultCard(
                    title: AppStrings.tr('Detected Code', 'الرمز المكتشف'),
                    value: r['value'] ?? '',
                    subtitle: 'Format ID: ${r['format'] ?? ''}',
                  ),
                ),
              ),
          ],
          if (id == 'qr_gen_text') ...[
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Enter URL or Text', 'أدخل الرابط أو النص'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _buildQrPreview(_textCtrl.text),
          ],
          if (id == 'qr_gen_wifi') ...[
            TextField(
              controller: _ssidCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Wi-Fi Network Name (SSID)', 'اسم شبكة الواي فاي (SSID)'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wifiPassCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Wi-Fi Password', 'كلمة مرور الواي فاي'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _wifiAuth,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Security Type', 'نوع الحماية'),
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA / WPA2 / WPA3')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(value: 'nopass', child: Text('Open (No Password)')),
              ],
              onChanged: (v) => setState(() => _wifiAuth = v ?? 'WPA'),
            ),
            const SizedBox(height: 16),
            _buildQrPreview(_buildWifiPayload()),
          ],
          if (id == 'qr_gen_vcard') ...[
            TextField(
              controller: _vNameCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Full Name', 'الاسم الكامل'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Phone Number', 'رقم الهاتف'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Email Address', 'البريد الإلكتروني'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vOrgCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Company / Organization', 'الشركة / المؤسسة'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _buildQrPreview(_buildVCardPayload()),
          ],
          if (id == 'qr_history') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionHeader(AppStrings.tr('Saved Scan History (${_history.length})', 'سجل المسح المحفوظ')),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    label: Text(AppStrings.tr('Clear All', 'مسح الكل')),
                    onPressed: _clearHistory,
                  ),
              ],
            ),
            if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(AppStrings.tr('No scans recorded yet.', 'لا يوجد سجل مسح حتى الآن.')),
                ),
              )
            else
              ..._history.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ResultCard(
                    title: item.split(' | ').first,
                    value: item.split(' | ').skip(1).join(' | '),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrPreview(String data) {
    final safeData = data.trim().isEmpty ? 'Omni 100' : data;
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: safeData,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ResultCard(
          title: AppStrings.tr('Encoded QR Content', 'محتوى رمز QR'),
          value: safeData,
        ),
      ],
    );
  }
}
