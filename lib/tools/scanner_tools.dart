import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class ScannerToolScreen extends StatefulWidget {
  final String toolId;
  const ScannerToolScreen({super.key, required this.toolId});

  @override
  State<ScannerToolScreen> createState() => _ScannerToolScreenState();
}

class _ScannerToolScreenState extends State<ScannerToolScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _scannedPages = [];
  Uint8List? _idFront;
  Uint8List? _idBack;
  String _ocrText = '';
  bool _busy = false;
  String _selectedFilter = 'original';
  double _cropMarginPct = 8.0;

  Future<void> _captureImage({required bool fromCamera, int? idSide}) async {
    final xfile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 92,
    );
    if (xfile == null) return;
    setState(() => _busy = true);
    try {
      Uint8List bytes = await xfile.readAsBytes();
      if (widget.toolId == 'scan_ocr') {
        final text = await NativeBridge.recognizeText(xfile.path);
        setState(() {
          _scannedPages
            ..clear()
            ..add(bytes);
          _ocrText = text.isEmpty
              ? AppStrings.tr('No text detected in image.', 'لم يتم العثور على نص في الصورة.')
              : text;
        });
      } else if (widget.toolId == 'scan_id_card') {
        setState(() {
          if (idSide == 1) {
            _idFront = bytes;
          } else {
            _idBack = bytes;
          }
        });
      } else {
        if (widget.toolId == 'scan_edge') {
          bytes = _applyCrop(bytes, _cropMarginPct);
        } else if (widget.toolId == 'scan_filters' && _selectedFilter != 'original') {
          bytes = _applyFilter(bytes, _selectedFilter);
        }
        setState(() => _scannedPages.add(bytes));
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  Uint8List _applyCrop(Uint8List bytes, double marginPct) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final mx = (decoded.width * (marginPct / 100)).round();
    final my = (decoded.height * (marginPct / 100)).round();
    final cropped = img.copyCrop(
      decoded,
      x: mx,
      y: my,
      width: (decoded.width - mx * 2).clamp(10, decoded.width),
      height: (decoded.height - my * 2).clamp(10, decoded.height),
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }

  Uint8List _applyFilter(Uint8List bytes, String mode) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    img.Image working = decoded.clone();
    if (mode == 'bw') {
      working = img.grayscale(working);
      working = img.contrast(working, contrast: 145);
    } else if (mode == 'magic') {
      working = img.adjustColor(working, contrast: 1.3, saturation: 1.25, brightness: 1.05);
    } else if (mode == 'invert') {
      working = img.invert(working);
    }
    return Uint8List.fromList(img.encodeJpg(working, quality: 90));
  }

  Future<void> _exportScannedPdf() async {
    final doc = pw.Document();
    if (widget.toolId == 'scan_id_card') {
      if (_idFront == null && _idBack == null) return;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (_) => pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              if (_idFront != null)
                pw.Container(
                  height: 240,
                  child: pw.Image(pw.MemoryImage(_idFront!), fit: pw.BoxFit.contain),
                ),
              if (_idBack != null)
                pw.Container(
                  height: 240,
                  child: pw.Image(pw.MemoryImage(_idBack!), fit: pw.BoxFit.contain),
                ),
            ],
          ),
        ),
      );
    } else {
      if (_scannedPages.isEmpty) return;
      for (final p in _scannedPages) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (_) => pw.Center(
              child: pw.Image(pw.MemoryImage(p), fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
    }
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await out.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(out.path)], text: 'Scanned Document');
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'الماسح الضوئي الذكي',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (id == 'scan_id_card') ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.Flip_to_front),
                    label: Text(AppStrings.tr('Scan Front Side', 'مسح الوجه الأمامي')),
                    onPressed: () => _captureImage(fromCamera: true, idSide: 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.flip_to_back),
                    label: Text(AppStrings.tr('Scan Back Side', 'مسح الوجه الخلفي')),
                    onPressed: () => _captureImage(fromCamera: true, idSide: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _captureImage(fromCamera: false, idSide: 1),
                    child: Text(AppStrings.tr('Pick Front (Gallery)', 'الأمامي من المعرض')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _captureImage(fromCamera: false, idSide: 2),
                    child: Text(AppStrings.tr('Pick Back (Gallery)', 'الخلفي من المعرض')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_idFront != null) ...[
              Text(AppStrings.tr('Front Side:', 'الوجه الأمامي:')),
              const SizedBox(height: 6),
              Image.memory(_idFront!, height: 160),
            ],
            if (_idBack != null) ...[
              const SizedBox(height: 12),
              Text(AppStrings.tr('Back Side:', 'الوجه الخلفي:')),
              const SizedBox(height: 6),
              Image.memory(_idBack!, height: 160),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(AppStrings.tr('Export 2-Sided ID Card PDF', 'تصدير الهوية في صفحة PDF واحدة')),
              onPressed: (_idFront == null && _idBack == null) ? null : _exportScannedPdf,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(AppStrings.tr('Camera Capture', 'التقاط بالكاميرا')),
                    onPressed: () => _captureImage(fromCamera: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: Text(AppStrings.tr('From Gallery', 'من المعرض')),
                    onPressed: () => _captureImage(fromCamera: false),
                  ),
                ),
              ],
            ),
            if (id == 'scan_edge') ...[
              const SizedBox(height: 12),
              Text(AppStrings.tr('Edge Border Auto-Trim: ${_cropMarginPct.toInt()}%', 'نسبة قص الحواف التلقائي: ${_cropMarginPct.toInt()}%')),
              Slider(
                value: _cropMarginPct,
                min: 2,
                max: 25,
                divisions: 23,
                onChanged: (v) => setState(() => _cropMarginPct = v),
              ),
            ],
            if (id == 'scan_filters') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(AppStrings.tr('Original', 'أصلي')),
                    selected: _selectedFilter == 'original',
                    onSelected: (_) => setState(() => _selectedFilter = 'original'),
                  ),
                  ChoiceChip(
                    label: Text(AppStrings.tr('B&W Document', 'أبيض وأسود عالي التباين')),
                    selected: _selectedFilter == 'bw',
                    onSelected: (_) => setState(() => _selectedFilter = 'bw'),
                  ),
                  ChoiceChip(
                    label: Text(AppStrings.tr('Magic Color', 'ألوان محسنة')),
                    selected: _selectedFilter == 'magic',
                    onSelected: (_) => setState(() => _selectedFilter = 'magic'),
                  ),
                  ChoiceChip(
                    label: Text(AppStrings.tr('Invert', 'عكس الألوان')),
                    selected: _selectedFilter == 'invert',
                    onSelected: (_) => setState(() => _selectedFilter = 'invert'),
                  ),
                ],
              ),
            ],
            if (_scannedPages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionHeader(AppStrings.tr('Scanned Pages (${_scannedPages.length})', 'الصفحات الممسوحة (${_scannedPages.length})')),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _scannedPages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_scannedPages[i], height: 230),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _scannedPages.removeAt(i)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (id != 'scan_ocr')
                FilledButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(AppStrings.tr('Save & Share Scanned PDF', 'حفظ ومشاركة ملف PDF')),
                  onPressed: _exportScannedPdf,
                ),
            ],
            if (_ocrText.isNotEmpty) ...[
              const SizedBox(height: 16),
              ResultCard(
                title: AppStrings.tr('OCR Extracted Text', 'النص المستخرج من الصورة'),
                value: _ocrText,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
