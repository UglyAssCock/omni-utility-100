import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_strings.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('omni_native');

  static Future<bool> toggleFlashlight(bool enable) async {
    try {
      final res = await _channel.invokeMethod<bool>('toggleFlashlight', {'enable': enable});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> vibrate([int ms = 40]) async {
    try {
      await _channel.invokeMethod('vibrate', {'ms': ms});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getBatteryInfo() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getBatteryInfo');
      return res ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return res ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<String?> startMic() async {
    try {
      await _channel.invokeMethod('startMic');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Microphone error';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<double> getMicDb() async {
    try {
      final val = await _channel.invokeMethod<double>('getMicDb');
      return val ?? 30.0;
    } catch (_) {
      return 30.0;
    }
  }

  static Future<void> stopMic() async {
    try {
      await _channel.invokeMethod('stopMic');
    } catch (_) {}
  }

  static Future<String> recognizeText(String imagePath) async {
    try {
      final text = await _channel.invokeMethod<String>('recognizeText', {'path': imagePath});
      return text ?? '';
    } catch (e) {
      return 'OCR Error: $e';
    }
  }

  static Future<List<Map<String, String>>> scanBarcodeFile(String imagePath) async {
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('scanBarcodeFile', {'path': imagePath});
      if (list == null) return [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'value': (m['value'] ?? '').toString(),
          'format': (m['format'] ?? '').toString(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> extractAudio(String videoPath, String outPath) async {
    try {
      final res = await _channel.invokeMethod<String>('extractAudio', {
        'videoPath': videoPath,
        'outPath': outPath,
      });
      return res;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Audio extraction failed');
    }
  }

  static Future<bool> pinHomeWidget(String title) async {
    try {
      final res = await _channel.invokeMethod<bool>('pinHomeWidget', {'title': title});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

class ToolScaffold extends StatelessWidget {
  final String titleEn;
  final String titleAr;
  final Widget child;
  final List<Widget>? actions;

  const ToolScaffold({
    super.key,
    required this.titleEn,
    required this.titleAr,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(titleEn, titleAr)),
        actions: actions,
      ),
      body: SafeArea(
        child: child,
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final bool copyable;

  const ResultCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.copyable = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.primaryContainer.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (copyable && value.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: AppStrings.tr('Copy', 'نسخ'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.tr('Copied to clipboard', 'تم النسخ للحافظة'))),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 18),
                    tooltip: AppStrings.tr('Share', 'مشاركة'),
                    onPressed: () => Share.share(value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
