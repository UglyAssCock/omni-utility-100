import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../main.dart';
import '../registry/tool_registry.dart';
import '../widgets/shared_widgets.dart';

class AppWideToolScreen extends StatefulWidget {
  final String toolId;
  const AppWideToolScreen({super.key, required this.toolId});

  @override
  State<AppWideToolScreen> createState() => _AppWideToolScreenState();
}

class _AppWideToolScreenState extends State<AppWideToolScreen> {
  final TextEditingController _widgetNoteCtrl = TextEditingController(
    text: 'Tap to open Omni 100 Tools',
  );
  final TextEditingController _restoreJsonCtrl = TextEditingController();
  String _status = '';

  @override
  void dispose() {
    _widgetNoteCtrl.dispose();
    _restoreJsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final backupMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      backupMap[key] = prefs.get(key);
    }
    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupMap);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/omni_100_backup.json');
    await f.writeAsString(jsonStr);
    setState(() => _status = AppStrings.tr('Backup exported!', 'تم تصدير النسخة الاحتياطية!'));
    await Share.shareXFiles([XFile(f.path)], text: 'Omni 100 Tools Backup');
  }

  Future<void> _restoreBackup() async {
    if (_restoreJsonCtrl.text.trim().isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(_restoreJsonCtrl.text));
      final prefs = await SharedPreferences.getInstance();
      for (final e in map.entries) {
        final v = e.value;
        if (v is bool) {
          await prefs.setBool(e.key, v);
        } else if (v is int) {
          await prefs.setInt(e.key, v);
        } else if (v is double) {
          await prefs.setDouble(e.key, v);
        } else if (v is String) {
          await prefs.setString(e.key, v);
        } else if (v is List) {
          await prefs.setStringList(e.key, v.map((x) => x.toString()).toList());
        }
      }
      if (mounted) {
        OmniApp.of(context).reloadFromPrefs();
        setState(() => _status = AppStrings.tr('Backup restored successfully!', 'تمت استعادة البيانات بنجاح!'));
      }
    } catch (e) {
      setState(() => _status = 'Invalid JSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    final appState = OmniApp.of(context);

    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'إعدادات ومميزات التطبيق',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (id == 'app_theme') ...[
            SwitchListTile(
              title: Text(AppStrings.tr('Dark Mode (Material 3)', 'الوضع الليلي المظلم')),
              subtitle: Text(AppStrings.tr('Saves OLED battery and reduces eye strain', 'يوفر طاقة البطارية ويريح العين')),
              value: appState.isDark,
              onChanged: (v) => appState.toggleTheme(v),
            ),
          ],
          if (id == 'app_offline') ...[
            ResultCard(
              title: AppStrings.tr('Offline-First Engine', 'نظام العمل بدون إنترنت'),
              value: '98 / 100 Tools 100% Offline',
              subtitle: AppStrings.tr(
                'Only live currency rates and internet speed test use network; both fall back gracefully when offline.',
                'جميع الأدوات تعمل بدون إنترنت باستثناء تحديث أسعار العملات وقياس سرعة الإنترنت.',
              ),
              copyable: false,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.cleaning_services),
              label: Text(AppStrings.tr('Clear Temporary Cache Files', 'مسح الملفات المؤقتة')),
              onPressed: () async {
                final dir = await getTemporaryDirectory();
                if (await dir.exists()) {
                  await dir.delete(recursive: true);
                }
                setState(() => _status = AppStrings.tr('Temporary cache cleared!', 'تم تنظيف الذاكرة المؤقتة!'));
              },
            ),
          ],
          if (id == 'app_widgets') ...[
            TextField(
              controller: _widgetNoteCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Custom Home Screen Widget Subtitle', 'نص ودجت الشاشة الرئيسية'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.widgets),
              label: Text(AppStrings.tr('Update & Pin Home Screen Widget', 'تحديث وتثبيت الودجت على الشاشة الرئيسية')),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('widget_note', _widgetNoteCtrl.text);
                await NativeBridge.pinHomeWidget(_widgetNoteCtrl.text);
                setState(() {
                  _status = AppStrings.tr(
                    'Home Widget updated! You can also add "Omni 100 Tools" from your Android launcher widgets menu.',
                    'تم تحديث الودجت وطلب تثبيته على الشاشة الرئيسية!',
                  );
                });
              },
            ),
          ],
          if (id == 'app_lang') ...[
            RadioListTile<bool>(
              title: const Text('English (LTR)'),
              value: false,
              groupValue: appState.isArabic,
              onChanged: (v) => appState.toggleLanguage(false),
            ),
            RadioListTile<bool>(
              title: const Text('العربية (واجهة كاملة من اليمين إلى اليسار RTL)'),
              value: true,
              groupValue: appState.isArabic,
              onChanged: (v) => appState.toggleLanguage(true),
            ),
          ],
          if (id == 'app_backup') ...[
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('Export All Notes, Favorites & Settings (.json)', 'تصدير جميع الملاحظات والمفضلة والإعدادات')),
              onPressed: _exportBackup,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _restoreJsonCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Paste Backup JSON to Restore', 'الصق كود النسخة الاحتياطية للاستعادة'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: Text(AppStrings.tr('Restore Backup Data', 'استعادة البيانات')),
              onPressed: _restoreBackup,
            ),
          ],
          if (id == 'app_favorites') ...[
            SectionHeader(AppStrings.tr('Home Grid Columns', 'عدد أعمدة الشبكة الرئيسية')),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2 Cols')),
                ButtonSegment(value: 3, label: Text('3 Cols')),
                ButtonSegment(value: 4, label: Text('4 Cols')),
              ],
              selected: {appState.gridColumns},
              onSelectionChanged: (s) => appState.setGridColumns(s.first),
            ),
            const SizedBox(height: 16),
            SectionHeader(AppStrings.tr('Favorite Tools (${appState.favorites.length})', 'الأدوات المفضلة')),
            ...ToolRegistry.allTools.map(
              (t) => CheckboxListTile(
                value: appState.favorites.contains(t.id),
                title: Text(AppStrings.tr(t.titleEn, t.titleAr)),
                secondary: Icon(t.icon, color: t.color),
                onChanged: (_) => appState.toggleFavorite(t.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
