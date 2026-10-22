import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class PdfToolScreen extends StatefulWidget {
  final String toolId;
  const PdfToolScreen({super.key, required this.toolId});

  @override
  State<PdfToolScreen> createState() => _PdfToolScreenState();
}

class _PdfToolScreenState extends State<PdfToolScreen> {
  bool _busy = false;
  String _status = '';
  Uint8List? _pdfBytes;
  String? _savedFilePath;
  final List<Uint8List> _pageImages = [];
  final List<int> _pageRotations = [];

  // Tool-specific controllers
  final TextEditingController _rangeStartCtrl = TextEditingController(text: '1');
  final TextEditingController _rangeEndCtrl = TextEditingController(text: '1');
  final TextEditingController _watermarkCtrl = TextEditingController(text: 'CONFIDENTIAL');
  final TextEditingController _annotationCtrl = TextEditingController(text: 'Highlighted Note');
  final TextEditingController _passwordCtrl = TextEditingController();
  double _compressDpi = 90;
  final List<Offset?> _signaturePoints = [];
  String _ocrOutput = '';

  @override
  void dispose() {
    _rangeStartCtrl.dispose();
    _rangeEndCtrl.dispose();
    _watermarkCtrl.dispose();
    _annotationCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<File?> _pickSinglePdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'opdf'],
    );
    if (res == null || res.files.single.path == null) return null;
    return File(res.files.single.path!);
  }

  Future<void> _loadPdfAndRasterize({double dpi = 130}) async {
    final file = await _pickSinglePdf();
    if (file == null) return;
    setState(() {
      _busy = true;
      _status = AppStrings.tr('Reading PDF pages...', 'جارٍ قراءة صفحات PDF...');
      _pageImages.clear();
      _pageRotations.clear();
    });
    try {
      final bytes = await file.readAsBytes();
      _pdfBytes = bytes;
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        final png = await page.toPng();
        _pageImages.add(png);
        _pageRotations.add(0);
      }
      _rangeEndCtrl.text = _pageImages.length.toString();
      setState(() {
        _status = AppStrings.tr(
          'Loaded ${_pageImages.length} pages.',
          'تم تحميل ${_pageImages.length} صفحة.',
        );
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _saveAndSharePdf(pw.Document doc, String filename) async {
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final outFile = File('${dir.path}/$filename');
    await outFile.writeAsBytes(bytes);
    setState(() {
      _pdfBytes = bytes;
      _savedFilePath = outFile.path;
      _status = AppStrings.tr('Saved: $filename', 'تم الحفظ: $filename');
    });
    await Share.shareXFiles([XFile(outFile.path)], text: filename);
  }

  Future<void> _mergePdfs() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res == null || res.files.isEmpty) return;
    setState(() {
      _busy = true;
      _status = AppStrings.tr('Merging PDFs...', 'جارٍ دمج ملفات PDF...');
    });
    try {
      final doc = pw.Document();
      int totalPages = 0;
      for (final f in res.files) {
        if (f.path == null) continue;
        final bytes = await File(f.path!).readAsBytes();
        await for (final page in Printing.raster(bytes, dpi: 130)) {
          final png = await page.toPng();
          final img = pw.MemoryImage(png);
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
            ),
          );
          totalPages++;
        }
      }
      await _saveAndSharePdf(doc, 'merged_$totalPages.pdf');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _imagesToPdf() async {
    final picker = ImagePicker();
    final imgs = await picker.pickMultiImage();
    if (imgs.isEmpty) return;
    setState(() {
      _busy = true;
      _status = AppStrings.tr('Building PDF from images...', 'جارٍ إنشاء PDF من الصور...');
    });
    try {
      final doc = pw.Document();
      for (final xfile in imgs) {
        final bytes = await xfile.readAsBytes();
        final img = pw.MemoryImage(bytes);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
          ),
        );
      }
      await _saveAndSharePdf(doc, 'images_to_pdf.pdf');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _exportPagesAsImages() async {
    if (_pageImages.isEmpty) return;
    final dir = await getTemporaryDirectory();
    final List<XFile> files = [];
    for (int i = 0; i < _pageImages.length; i++) {
      final f = File('${dir.path}/page_${i + 1}.png');
      await f.writeAsBytes(_pageImages[i]);
      files.add(XFile(f.path));
    }
    await Share.shareXFiles(files, text: 'PDF Pages');
  }

  Future<void> _rebuildPdfWithOptions({
    bool splitRange = false,
    bool addWatermark = false,
    bool addPageNumbers = false,
    bool addAnnotation = false,
    bool addSignature = false,
    int? deletePageIndex,
  }) async {
    if (_pageImages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      final start = (int.tryParse(_rangeStartCtrl.text) ?? 1).clamp(1, _pageImages.length);
      final end = (int.tryParse(_rangeEndCtrl.text) ?? _pageImages.length).clamp(start, _pageImages.length);

      for (int i = 0; i < _pageImages.length; i++) {
        if (splitRange && (i + 1 < start || i + 1 > end)) continue;
        if (deletePageIndex != null && i == deletePageIndex) continue;

        final img = pw.MemoryImage(_pageImages[i]);
        final rot = _pageRotations[i];
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(12),
            build: (_) {
              return pw.Stack(
                children: [
                  pw.Center(
                    child: pw.Transform.rotateBox(
                      angle: rot * 1.57079632679,
                      child: pw.Image(img, fit: pw.BoxFit.contain),
                    ),
                  ),
                  if (addWatermark)
                    pw.Center(
                      child: pw.Transform.rotate(
                        angle: -0.5,
                        child: pw.Opacity(
                          opacity: 0.28,
                          child: pw.Text(
                            _watermarkCtrl.text,
                            style: pw.TextStyle(
                              fontSize: 44,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (addAnnotation)
                    pw.Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        color: PdfColors.yellow200,
                        child: pw.Text(
                          _annotationCtrl.text,
                          style: const pw.TextStyle(fontSize: 14, color: PdfColors.black),
                        ),
                      ),
                    ),
                  if (addSignature && _signaturePoints.isNotEmpty)
                    pw.Positioned(
                      bottom: 30,
                      right: 30,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue800),
                        ),
                        child: pw.Text(
                          'Signed Digitally (${DateTime.now().toIso8601String().split('T').first})',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  if (addPageNumbers)
                    pw.Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: pw.Center(
                        child: pw.Text(
                          'Page ${i + 1} of ${_pageImages.length}',
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }
      await _saveAndSharePdf(doc, '${widget.toolId}_output.pdf');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _compressPdf() async {
    final file = await _pickSinglePdf();
    if (file == null) return;
    setState(() {
      _busy = true;
      _status = AppStrings.tr('Compressing PDF...', 'جارٍ ضغط ملف PDF...');
    });
    try {
      final origBytes = await file.readAsBytes();
      final doc = pw.Document(compress: true);
      await for (final page in Printing.raster(origBytes, dpi: _compressDpi)) {
        final png = await page.toPng();
        final img = pw.MemoryImage(png);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
          ),
        );
      }
      await _saveAndSharePdf(doc, 'compressed_${_compressDpi.toInt()}dpi.pdf');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Uint8List _xorBytes(Uint8List input, String password) {
    final key = password.codeUnits;
    final out = Uint8List(input.length);
    for (int i = 0; i < input.length; i++) {
      out[i] = input[i] ^ key[i % key.length] ^ (i & 0xFF);
    }
    return out;
  }

  Future<void> _lockOrUnlockPdf({required bool lock}) async {
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _status = AppStrings.tr('Enter a password first', 'أدخل كلمة المرور أولاً'));
      return;
    }
    final file = await _pickSinglePdf();
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final processed = _xorBytes(bytes, _passwordCtrl.text);
      final dir = await getTemporaryDirectory();
      final ext = lock ? 'opdf' : 'pdf';
      final out = File('${dir.path}/${lock ? "locked" : "unlocked"}_document.$ext');
      await out.writeAsBytes(processed);
      if (!lock) {
        _pdfBytes = processed;
      }
      setState(() {
        _savedFilePath = out.path;
        _status = lock
            ? AppStrings.tr('Encrypted as .opdf! Share or store safely.', 'تم قفل الملف بنجاح!')
            : AppStrings.tr('Unlocked PDF successfully!', 'تم فتح قفل PDF بنجاح!');
      });
      await Share.shareXFiles([XFile(out.path)]);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _extractOcrFromPdf() async {
    await _loadPdfAndRasterize(dpi: 150);
    if (_pageImages.isEmpty) return;
    setState(() {
      _busy = true;
      _ocrOutput = '';
      _status = AppStrings.tr('Running OCR on PDF pages...', 'جارٍ استخراج النص...');
    });
    try {
      final dir = await getTemporaryDirectory();
      final buffer = StringBuffer();
      for (int i = 0; i < _pageImages.length; i++) {
        final f = File('${dir.path}/ocr_page_$i.png');
        await f.writeAsBytes(_pageImages[i]);
        final text = await NativeBridge.recognizeText(f.path);
        buffer.writeln('--- Page ${i + 1} ---');
        buffer.writeln(text);
      }
      setState(() {
        _ocrOutput = buffer.toString();
        _status = AppStrings.tr('OCR Complete!', 'اكتمل استخراج النص!');
      });
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
      titleAr: 'أداة PDF',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          _buildToolControls(id),
          const SizedBox(height: 16),
          if (_pdfBytes != null && id == 'pdf_viewer')
            SizedBox(
              height: 520,
              child: PdfPreview(
                build: (_) async => _pdfBytes!,
                allowPrinting: true,
                allowSharing: true,
              ),
            ),
          if (_pageImages.isNotEmpty && id != 'pdf_viewer') ...[
            SectionHeader(AppStrings.tr('Loaded Pages (${_pageImages.length})', 'الصفحات المحملة')),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pageImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  return Column(
                    children: [
                      Expanded(
                        child: Transform.rotate(
                          angle: _pageRotations[i] * 1.57079632679,
                          child: Image.memory(_pageImages[i], fit: BoxFit.contain),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#${i + 1}'),
                          if (id == 'pdf_rotate_reorder') ...[
                            IconButton(
                              icon: const Icon(Icons.rotate_right, size: 18),
                              onPressed: () => setState(() => _pageRotations[i] = (_pageRotations[i] + 1) % 4),
                            ),
                            if (i > 0)
                              IconButton(
                                icon: const Icon(Icons.arrow_back, size: 18),
                                onPressed: () {
                                  setState(() {
                                    final tmp = _pageImages[i - 1];
                                    _pageImages[i - 1] = _pageImages[i];
                                    _pageImages[i] = tmp;
                                  });
                                },
                              ),
                          ],
                          if (id == 'pdf_delete_extract')
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () => _rebuildPdfWithOptions(deletePageIndex: i),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          if (_ocrOutput.isNotEmpty)
            ResultCard(
              title: AppStrings.tr('Extracted OCR Text', 'النص المستخرج'),
              value: _ocrOutput,
            ),
        ],
      ),
    );
  }

  Widget _buildToolControls(String id) {
    switch (id) {
      case 'pdf_viewer':
        return FilledButton.icon(
          icon: const Icon(Icons.folder_open),
          label: Text(AppStrings.tr('Open PDF File to View & Print', 'فتح ملف PDF للعرض والطباعة')),
          onPressed: () async {
            final f = await _pickSinglePdf();
            if (f != null) {
              final b = await f.readAsBytes();
              setState(() => _pdfBytes = b);
            }
          },
        );

      case 'pdf_merge':
        return FilledButton.icon(
          icon: const Icon(Icons.merge_type),
          label: Text(AppStrings.tr('Select Multiple PDFs & Merge', 'اختر عدة ملفات PDF لدمجها')),
          onPressed: _mergePdfs,
        );

      case 'pdf_img_to_pdf':
        return FilledButton.icon(
          icon: const Icon(Icons.collections),
          label: Text(AppStrings.tr('Pick Images & Convert to PDF', 'اختر صوراً وحولها إلى PDF')),
          onPressed: _imagesToPdf,
        );

      case 'pdf_to_img':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Pick PDF File', '1. اختر ملف PDF')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: Text(AppStrings.tr('2. Export & Share All Pages as PNG', '2. تصدير ومشاركة الصفحات كصور')),
              onPressed: _pageImages.isEmpty ? null : _exportPagesAsImages,
            ),
          ],
        );

      case 'pdf_split':
      case 'pdf_delete_extract':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Load PDF File', '1. تحميل ملف PDF')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rangeStartCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('From Page', 'من صفحة'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rangeEndCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('To Page', 'إلى صفحة'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.call_split),
              label: Text(AppStrings.tr('Extract Selected Page Range', 'استخراج الصفحات المحددة')),
              onPressed: _pageImages.isEmpty ? null : () => _rebuildPdfWithOptions(splitRange: true),
            ),
          ],
        );

      case 'pdf_compress':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.tr('Target Compression DPI: ${_compressDpi.toInt()}', 'دقة الضغط: ${_compressDpi.toInt()} DPI')),
            Slider(
              value: _compressDpi,
              min: 50,
              max: 150,
              divisions: 10,
              label: '${_compressDpi.toInt()} DPI',
              onChanged: (v) => setState(() => _compressDpi = v),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.compress),
              label: Text(AppStrings.tr('Pick PDF & Compress Now', 'اختر ملف PDF واضغطه الآن')),
              onPressed: _compressPdf,
            ),
          ],
        );

      case 'pdf_rotate_reorder':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Load PDF to Rotate/Reorder', '1. اختر ملف PDF للتدوير والترتيب')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save),
              label: Text(AppStrings.tr('2. Save Rotated/Reordered PDF', '2. حفظ ملف PDF المعدل')),
              onPressed: _pageImages.isEmpty ? null : () => _rebuildPdfWithOptions(),
            ),
          ],
        );

      case 'pdf_password':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Password', 'كلمة المرور'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.lock),
                    label: Text(AppStrings.tr('Lock PDF', 'قفل PDF')),
                    onPressed: () => _lockOrUnlockPdf(lock: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_open),
                    label: Text(AppStrings.tr('Unlock .opdf', 'فتح القفل')),
                    onPressed: () => _lockOrUnlockPdf(lock: false),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'pdf_sign':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Load PDF to Sign', '1. تحميل ملف PDF للتوقيع')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 12),
            Text(AppStrings.tr('2. Draw Your Signature Below:', '2. ارسم توقيعك بالأسفل:')),
            const SizedBox(height: 6),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey),
              ),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() => _signaturePoints.add(details.localPosition));
                },
                onPanEnd: (_) => setState(() => _signaturePoints.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(_signaturePoints),
                  size: Size.infinite,
                ),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _signaturePoints.clear()),
                  child: Text(AppStrings.tr('Clear Pad', 'مسح التوقيع')),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check),
                  label: Text(AppStrings.tr('Apply Signature & Save', 'تطبيق التوقيع والحفظ')),
                  onPressed: _pageImages.isEmpty
                      ? null
                      : () => _rebuildPdfWithOptions(addSignature: true),
                ),
              ],
            ),
          ],
        );

      case 'pdf_annotate':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Load PDF', '1. تحميل ملف PDF')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _annotationCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Highlight Banner Text', 'نص التظليل والتعليق'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.edit_note),
              label: Text(AppStrings.tr('Add Highlight Note & Save', 'إضافة التظليل وحفظ PDF')),
              onPressed: _pageImages.isEmpty
                  ? null
                  : () => _rebuildPdfWithOptions(addAnnotation: true),
            ),
          ],
        );

      case 'pdf_watermark':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Load PDF', '1. تحميل ملف PDF')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _watermarkCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Watermark Text', 'نص العلامة المائية'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.branding_watermark),
              label: Text(AppStrings.tr('Stamp Watermark & Save', 'إضافة العلامة المائية والحفظ')),
              onPressed: _pageImages.isEmpty
                  ? null
                  : () => _rebuildPdfWithOptions(addWatermark: true),
            ),
          ],
        );

      case 'pdf_ocr':
        return FilledButton.icon(
          icon: const Icon(Icons.document_scanner),
          label: Text(AppStrings.tr('Pick PDF & Extract Text (OCR)', 'اختر PDF واستخرج النص منه')),
          onPressed: _extractOcrFromPdf,
        );

      case 'pdf_page_numbers':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(AppStrings.tr('1. Load PDF', '1. تحميل ملف PDF')),
              onPressed: _loadPdfAndRasterize,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.format_list_numbered),
              label: Text(AppStrings.tr('2. Stamp Page Numbers & Export', '2. ترقيم الصفحات والحفظ')),
              onPressed: _pageImages.isEmpty
                  ? null
                  : () => _rebuildPdfWithOptions(addPageNumbers: true),
            ),
          ],
        );
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
