import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class TextDevToolScreen extends StatefulWidget {
  final String toolId;
  const TextDevToolScreen({super.key, required this.toolId});

  @override
  State<TextDevToolScreen> createState() => _TextDevToolScreenState();
}

class _TextDevToolScreenState extends State<TextDevToolScreen> {
  final TextEditingController _inputCtrl = TextEditingController();

  // Notes & Todos
  List<String> _notes = [];
  List<Map<String, dynamic>> _todos = [];

  // Password gen
  double _passLen = 16;
  bool _useUpper = true;
  bool _useNumbers = true;
  bool _useSymbols = true;
  String _generatedPass = '';

  // Color Picker
  double _r = 56;
  double _g = 189;
  double _b = 248;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.toolId == 'text_password') {
      _generatePassword();
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notes = prefs.getStringList('saved_notes') ?? [];
      final rawTodos = prefs.getString('saved_todos');
      if (rawTodos != null) {
        try {
          _todos = List<Map<String, dynamic>>.from(jsonDecode(rawTodos));
        } catch (_) {}
      }
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_notes', _notes);
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_todos', jsonEncode(_todos));
  }

  void _generatePassword() {
    String chars = 'abcdefghijklmnopqrstuvwxyz';
    if (_useUpper) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (_useNumbers) chars += '0123456789';
    if (_useSymbols) chars += '!@#\$%^&*()-_=+[]{}';
    final rng = Random.secure();
    setState(() {
      _generatedPass = List.generate(_passLen.round(), (_) => chars[rng.nextInt(chars.length)]).join();
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'أدوات النصوص والمطورين',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildBody(id)],
      ),
    );
  }

  Widget _buildBody(String id) {
    switch (id) {
      case 'text_notes':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('Write a quick note...', 'اكتب ملاحظة سريعة...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_inputCtrl.text.trim().isEmpty) return;
                    setState(() {
                      _notes.insert(0, _inputCtrl.text.trim());
                      _inputCtrl.clear();
                    });
                    _saveNotes();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_notes.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ResultCard(
                  title: 'Note #${_notes.length - i}',
                  value: _notes[i],
                ),
              );
            }),
          ],
        );

      case 'text_todo':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('Add new task...', 'أضف مهمة جديدة...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add_task),
                  onPressed: () {
                    if (_inputCtrl.text.trim().isEmpty) return;
                    setState(() {
                      _todos.insert(0, {'title': _inputCtrl.text.trim(), 'done': false});
                      _inputCtrl.clear();
                    });
                    _saveTodos();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_todos.length, (i) {
              final item = _todos[i];
              final done = item['done'] == true;
              return CheckboxListTile(
                value: done,
                title: Text(
                  '${item['title']}',
                  style: TextStyle(decoration: done ? TextDecoration.lineThrough : null),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _todos.removeAt(i));
                    _saveTodos();
                  },
                ),
                onChanged: (v) {
                  setState(() => _todos[i]['done'] = v ?? false);
                  _saveTodos();
                },
              );
            }),
          ],
        );

      case 'text_password':
        return Column(
          children: [
            ResultCard(
              title: AppStrings.tr('Generated Secure Password', 'كلمة المرور المولدة'),
              value: _generatedPass,
            ),
            const SizedBox(height: 12),
            Text(AppStrings.tr('Length: ${_passLen.round()} characters', 'الطول: ${_passLen.round()} حرف')),
            Slider(
              value: _passLen,
              min: 6,
              max: 48,
              divisions: 42,
              onChanged: (v) => setState(() => _passLen = v),
            ),
            SwitchListTile(
              title: Text(AppStrings.tr('Include Uppercase (A-Z)', 'أحرف كبيرة (A-Z)')),
              value: _useUpper,
              onChanged: (v) => setState(() => _useUpper = v),
            ),
            SwitchListTile(
              title: Text(AppStrings.tr('Include Numbers (0-9)', 'أرقام (0-9)')),
              value: _useNumbers,
              onChanged: (v) => setState(() => _useNumbers = v),
            ),
            SwitchListTile(
              title: Text(AppStrings.tr('Include Symbols (!@#\$)', 'رموز خاصة (!@#\$)')),
              value: _useSymbols,
              onChanged: (v) => setState(() => _useSymbols = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.tr('Generate New Password', 'توليد كلمة مرور جديدة')),
              onPressed: _generatePassword,
            ),
          ],
        );

      case 'text_counter':
        final txt = _inputCtrl.text;
        final chars = txt.length;
        final words = txt.trim().isEmpty ? 0 : txt.trim().split(RegExp(r'\s+')).length;
        final lines = txt.isEmpty ? 0 : txt.split('\n').length;
        return Column(
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Paste or type text here...', 'الصق أو اكتب النص هنا...'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Text Statistics', 'إحصائيات النص'),
              value: '$words Words  •  $chars Characters',
              subtitle: 'Lines: $lines  •  No-space chars: ${txt.replaceAll(RegExp(r"\s"), "").length}',
            ),
          ],
        );

      case 'text_case':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Enter Text', 'أدخل النص'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => setState(() => _inputCtrl.text = _inputCtrl.text.toUpperCase()),
                  child: const Text('UPPERCASE'),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(() => _inputCtrl.text = _inputCtrl.text.toLowerCase()),
                  child: const Text('lowercase'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final words = _inputCtrl.text.split(' ').map((w) {
                      if (w.isEmpty) return w;
                      return w[0].toUpperCase() + w.substring(1).toLowerCase();
                    }).join(' ');
                    setState(() => _inputCtrl.text = words);
                  },
                  child: const Text('Title Case'),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(
                    () => _inputCtrl.text = _inputCtrl.text.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase(),
                  ),
                  child: const Text('snake_case'),
                ),
              ],
            ),
          ],
        );

      case 'text_color':
        final ri = _r.round();
        final gi = _g.round();
        final bi = _b.round();
        final hex = '#${ri.toRadixString(16).padLeft(2, '0')}${gi.toRadixString(16).padLeft(2, '0')}${bi.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
        final color = Color.fromARGB(255, ri, gi, bi);
        final hsl = HSLColor.fromColor(color);
        return Column(
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _r,
              min: 0,
              max: 255,
              activeColor: Colors.red,
              onChanged: (v) => setState(() => _r = v),
            ),
            Slider(
              value: _g,
              min: 0,
              max: 255,
              activeColor: Colors.green,
              onChanged: (v) => setState(() => _g = v),
            ),
            Slider(
              value: _b,
              min: 0,
              max: 255,
              activeColor: Colors.blue,
              onChanged: (v) => setState(() => _b = v),
            ),
            ResultCard(
              title: 'HEX / RGB / HSL',
              value: hex,
              subtitle: 'RGB($ri, $gi, $bi)  •  HSL(${hsl.hue.round()}°, ${(hsl.saturation * 100).round()}%, ${(hsl.lightness * 100).round()}%)',
            ),
          ],
        );

      case 'text_hash':
      default:
        final bytes = utf8.encode(_inputCtrl.text);
        final md5Str = md5.convert(bytes).toString();
        final sha1Str = sha1.convert(bytes).toString();
        final sha256Str = sha256.convert(bytes).toString();
        final sha512Str = sha512.convert(bytes).toString();
        return Column(
          children: [
            TextField(
              controller: _inputCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Input Text to Hash', 'أدخل النص لتوليد التجزئة'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ResultCard(title: 'MD5', value: md5Str),
            const SizedBox(height: 8),
            ResultCard(title: 'SHA-1', value: sha1Str),
            const SizedBox(height: 8),
            ResultCard(title: 'SHA-256', value: sha256Str),
            const SizedBox(height: 8),
            ResultCard(title: 'SHA-512', value: sha512Str),
          ],
        );
    }
  }
}
