import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class FileConverterToolScreen extends StatefulWidget {
  final String toolId;
  const FileConverterToolScreen({super.key, required this.toolId});

  @override
  State<FileConverterToolScreen> createState() => _FileConverterToolScreenState();
}

class _FileConverterToolScreenState extends State<FileConverterToolScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String _status = '';
  Uint8List? _imageBytes;

  // Format & resize & compress options
  String _targetFormat = 'png';
  final TextEditingController _widthCtrl = TextEditingController(text: '800');
  final TextEditingController _heightCtrl = TextEditingController(text: '600');
  double _jpegQuality = 70;

  // Text to PDF & Base64
  final TextEditingController _textCtrl = TextEditingController(
    text: 'Sample document text.\nType or paste anything here to convert.',
  );
  String _base64Output = '';

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      _widthCtrl.text = decoded.width.toString();
      _heightCtrl.text = decoded.height.toString();
    }
    setState(() {
      _imageBytes = bytes;
      _status = AppStrings.tr(
        'Loaded image (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
        'تم تحميل الصورة (${(bytes.length / 1024).toStringAsFixed(1)} كيلوبايت)',
      );
    });
  }

  Future<void> _processImage() async {
    if (_imageBytes == null) return;
    setState(() => _busy = true);
    try {
      final decoded = img.decodeImage(_imageBytes!);
      if (decoded == null) throw Exception('Unsupported image');
      img.Image working = decoded;

      if (widget.toolId == 'file_img_resize') {
        final w = (int.tryParse(_widthCtrl.text) ?? decoded.width).clamp(16, 4096);
        final h = (int.tryParse(_heightCtrl.text) ?? decoded.height).clamp(16, 4096);
        working = img.copyResize(decoded, width: w, height: h);
      }

      late List<int> encoded;
      String ext = 'jpg';
      if (widget.toolId == 'file_img_compress') {
        encoded = img.encodeJpg(working, quality: _jpegQuality.round());
        ext = 'jpg';
      } else if (widget.toolId == 'file_img_format') {
        ext = _targetFormat;
        if (_targetFormat == 'png') {
          encoded = img.encodePng(working);
        } else if (_targetFormat == 'bmp') {
          encoded = img.encodeBmp(working);
        } else if (_targetFormat == 'gif') {
          encoded = img.encodeGif(working);
        } else {
          encoded = img.encodeJpg(working, quality: 92);
          ext = 'jpg';
        }
      } else {
        encoded = img.encodeJpg(working, quality: 90);
      }

      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await out.writeAsBytes(encoded);
      setState(() {
        _status = AppStrings.tr(
          'Output size: ${(encoded.length / 1024).toStringAsFixed(1)} KB',
          'الحجم الناتج: ${(encoded.length / 1024).toStringAsFixed(1)} كيلوبايت',
        );
      });
      await Share.shareXFiles([XFile(out.path)]);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _convertTextToPdf(String content, String title) async {
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      final lines = content.split('\n');
      const linesPerPage = 38;
      for (int i = 0; i < lines.length; i += linesPerPage) {
        final chunk = lines.skip(i).take(linesPerPage).join('\n');
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text(chunk, style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
        );
      }
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/document_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await out.writeAsBytes(await doc.save());
      setState(() => _status = AppStrings.tr('PDF Created!', 'تم إنشاء ملف PDF!'));
      await Share.shareXFiles([XFile(out.path)]);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _convertOfficeToPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'xlsx', 'pptx', 'txt', 'csv'],
    );
    if (res == null || res.files.single.path == null) return;
    setState(() {
      _busy = true;
      _status = AppStrings.tr('Extracting Office XML content...', 'جارٍ استخراج محتوى ملف الأوفيس...');
    });
    try {
      final file = File(res.files.single.path!);
      final ext = res.files.single.extension?.toLowerCase() ?? '';
      String extracted = '';

      if (ext == 'txt' || ext == 'csv') {
        extracted = await file.readAsString();
      } else {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final buffer = StringBuffer();
        for (final entry in archive) {
          if (!entry.isFile) continue;
          final name = entry.name;
          if (name == 'word/document.xml' ||
              name == 'xl/sharedStrings.xml' ||
              name.startsWith('ppt/slides/slide')) {
            final xml = utf8.decode(entry.content as List<int>, allowMalformed: true);
            final textMatches = RegExp(r'<[^>]+>').allMatches(xml);
            final stripped = xml
                .replaceAll(RegExp(r'</w:p>|</row>|</a:p>'), '\n')
                .replaceAll(RegExp(r'<[^>]*>'), ' ')
                .replaceAll(RegExp(r' +'), ' ')
                .trim();
            if (stripped.isNotEmpty && textMatches.isNotEmpty) {
              buffer.writeln(stripped);
              buffer.writeln();
            }
          }
        }
        extracted = buffer.toString().trim();
        if (extracted.isEmpty) {
          extracted = 'Office file (${res.files.single.name}) parsed, no plain text nodes found.';
        }
      }
      await _convertTextToPdf(extracted, res.files.single.name);
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _convertVideoToAudio() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res == null || res.files.single.path == null) return;
    setState(() {
      _busy = true;
      _status = AppStrings.tr('Extracting audio track natively...', 'جارٍ استخراج المسار الصوتي...');
    });
    try {
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/extracted_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final saved = await NativeBridge.extractAudio(res.files.single.path!, outPath);
      if (saved != null) {
        setState(() => _status = AppStrings.tr('Audio extracted (.m4a)!', 'تم استخراج الصوت بنجاح!'));
        await Share.shareXFiles([XFile(saved)]);
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'تحويل الملفات والوسائط',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (id == 'file_img_format' || id == 'file_img_resize' || id == 'file_img_compress') ...[
            FilledButton.icon(
              icon: const Icon(Icons.image),
              label: Text(AppStrings.tr('1. Pick Image from Gallery', '1. اختر صورة من المعرض')),
              onPressed: _pickImage,
            ),
            const SizedBox(height: 12),
            if (id == 'file_img_format')
              DropdownButtonFormField<String>(
                value: _targetFormat,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('Target Image Format', 'الصيغة المطلوبة'),
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'png', child: Text('PNG')),
                  DropdownMenuItem(value: 'jpg', child: Text('JPG / JPEG')),
                  DropdownMenuItem(value: 'bmp', child: Text('BMP')),
                  DropdownMenuItem(value: 'gif', child: Text('GIF')),
                ],
                onChanged: (v) => setState(() => _targetFormat = v ?? 'png'),
              ),
            if (id == 'file_img_resize')
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _widthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('Width (px)', 'العرض (بكسل)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('Height (px)', 'الارتفاع (بكسل)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            if (id == 'file_img_compress') ...[
              Text(AppStrings.tr('Compression Quality: ${_jpegQuality.round()}%', 'جودة الضغط: ${_jpegQuality.round()}%')),
              Slider(
                value: _jpegQuality,
                min: 10,
                max: 95,
                divisions: 17,
                onChanged: (v) => setState(() => _jpegQuality = v),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save_alt),
              label: Text(AppStrings.tr('2. Convert & Share Image', '2. تحويل ومشاركة الصورة')),
              onPressed: _imageBytes == null ? null : _processImage,
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 16),
              Image.memory(_imageBytes!, height: 200, fit: BoxFit.contain),
            ],
          ],
          if (id == 'file_txt_pdf') ...[
            TextField(
              controller: _textCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Document Text', 'نص المستند'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(AppStrings.tr('Export Text as PDF', 'تصدير النص كملف PDF')),
              onPressed: () => _convertTextToPdf(_textCtrl.text, 'Text Document'),
            ),
          ],
          if (id == 'file_office_pdf') ...[
            Text(
              AppStrings.tr(
                'Select a .docx, .xlsx, .pptx, .csv, or .txt file to extract its text and tables into a clean A4 PDF offline.',
                'اختر ملف Word أو Excel أو PowerPoint لتحويله إلى PDF بدون إنترنت.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('Pick Office File & Convert to PDF', 'اختر ملف أوفيس وحوله إلى PDF')),
              onPressed: _convertOfficeToPdf,
            ),
          ],
          if (id == 'file_video_audio') ...[
            Text(
              AppStrings.tr(
                'Extracts the original AAC/MP4 audio stream directly from your video using Android hardware muxing (fast, zero quality loss).',
                'يستخرج الصوت الأصلي مباشرة من ملف الفيديو بسرعة عالية وبدون فقدان للجودة.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.audiotrack),
              label: Text(AppStrings.tr('Select Video & Extract Audio', 'اختر فيديو واستخرج الصوت')),
              onPressed: _convertVideoToAudio,
            ),
          ],
          if (id == 'file_base64') ...[
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Input Text or Base64 String', 'أدخل النص أو كود Base64'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _base64Output = base64Encode(utf8.encode(_textCtrl.text));
                      });
                    },
                    child: Text(AppStrings.tr('Encode Base64', 'تشفير Base64')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      try {
                        setState(() {
                          _base64Output = utf8.decode(base64Decode(_textCtrl.text.trim()));
                        });
                      } catch (e) {
                        setState(() => _base64Output = 'Invalid Base64 input');
                      }
                    },
                    child: Text(AppStrings.tr('Decode Base64', 'فك تشفير Base64')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_base64Output.isNotEmpty)
              ResultCard(
                title: AppStrings.tr('Base64 Result', 'النتيجة'),
                value: _base64Output,
              ),
          ],
        ],
      ),
    );
  }
}
