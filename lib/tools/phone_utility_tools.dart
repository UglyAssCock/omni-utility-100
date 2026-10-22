import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class PhoneUtilityToolScreen extends StatefulWidget {
  final String toolId;
  const PhoneUtilityToolScreen({super.key, required this.toolId});

  @override
  State<PhoneUtilityToolScreen> createState() => _PhoneUtilityToolScreenState();
}

class _PhoneUtilityToolScreenState extends State<PhoneUtilityToolScreen> {
  // Flashlight
  bool _torchOn = false;
  bool _sosActive = false;
  Timer? _periodicTimer;

  // Sensors (Compass & Level)
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  double _headingDeg = 0;
  double _tiltX = 0;
  double _tiltY = 0;

  // Sound Meter
  bool _micListening = false;
  double _currentDb = 30.0;
  double _peakDb = 30.0;
  String _micError = '';

  // Battery & Device Info
  Map<String, dynamic> _batteryData = {};
  Map<String, dynamic> _deviceData = {};

  // Magnifier
  File? _magnifierImage;

  // Dead pixel test
  bool _fullScreenTest = false;
  int _colorIndex = 0;
  final List<Color> _testColors = const [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.cyan,
  ];

  // Speed test
  bool _testingSpeed = false;
  String _speedResult = '';

  @override
  void initState() {
    super.initState();
    final id = widget.toolId;
    if (id == 'phone_compass') {
      _magSub = magnetometerEventStream().listen((e) {
        final angle = atan2(e.y, e.x) * (180 / pi);
        if (mounted) {
          setState(() => _headingDeg = (angle + 360) % 360);
        }
      });
    } else if (id == 'phone_level') {
      _accSub = accelerometerEventStream().listen((e) {
        if (mounted) {
          setState(() {
            _tiltX = e.x.clamp(-10.0, 10.0);
            _tiltY = e.y.clamp(-10.0, 10.0);
          });
        }
      });
    } else if (id == 'phone_battery') {
      _loadBattery();
    } else if (id == 'phone_device') {
      _loadDevice();
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _magSub?.cancel();
    _accSub?.cancel();
    if (_torchOn) {
      NativeBridge.toggleFlashlight(false);
    }
    if (_micListening) {
      NativeBridge.stopMic();
    }
    super.dispose();
  }

  Future<void> _loadBattery() async {
    final info = await NativeBridge.getBatteryInfo();
    if (mounted) setState(() => _batteryData = info);
  }

  Future<void> _loadDevice() async {
    final info = await NativeBridge.getDeviceInfo();
    if (mounted) setState(() => _deviceData = info);
  }

  Future<void> _toggleMic() async {
    if (_micListening) {
      _periodicTimer?.cancel();
      await NativeBridge.stopMic();
      setState(() => _micListening = false);
    } else {
      final err = await NativeBridge.startMic();
      if (err != null) {
        setState(() => _micError = err);
        return;
      }
      setState(() {
        _micError = '';
        _micListening = true;
      });
      _periodicTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
        final db = await NativeBridge.getMicDb();
        if (mounted) {
          setState(() {
            _currentDb = db;
            if (db > _peakDb) _peakDb = db;
          });
        }
      });
    }
  }

  Future<void> _runSpeedTest() async {
    setState(() {
      _testingSpeed = true;
      _speedResult = AppStrings.tr('Measuring download throughput...', 'جارٍ قياس سرعة التحميل...');
    });
    try {
      final sw = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('https://speed.cloudflare.com/__down?bytes=2000000'))
          .timeout(const Duration(seconds: 12));
      sw.stop();
      if (response.statusCode == 200) {
        final bits = response.bodyBytes.length * 8;
        final seconds = sw.elapsedMilliseconds / 1000.0;
        final mbps = (bits / seconds) / 1000000.0;
        setState(() {
          _speedResult = '${mbps.toStringAsFixed(2)} Mbps\n(Downloaded ${(response.bodyBytes.length / 1024).round()} KB in ${seconds.toStringAsFixed(2)}s)';
        });
      } else {
        setState(() => _speedResult = 'Server returned ${response.statusCode}');
      }
    } catch (_) {
      setState(() {
        _speedResult = AppStrings.tr(
          'Offline / No Internet Connection Detected.',
          'لا يوجد اتصال بالإنترنت حالياً.',
        );
      });
    } finally {
      setState(() => _testingSpeed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    if (id == 'phone_screen_test' && _fullScreenTest) {
      return Scaffold(
        body: GestureDetector(
          onTap: () => setState(() => _colorIndex = (_colorIndex + 1) % _testColors.length),
          onLongPress: () => setState(() => _fullScreenTest = false),
          child: Container(
            color: _testColors[_colorIndex],
            alignment: Alignment.center,
            child: Text(
              AppStrings.tr('Tap to cycle colors • Long-press to exit', 'اضغط لتغيير اللون • اضغط مطولاً للخروج'),
              style: TextStyle(
                color: _testColors[_colorIndex] == Colors.white || _testColors[_colorIndex] == Colors.yellow
                    ? Colors.black54
                    : Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'أدوات وحساسات الهاتف',
      child: _buildUtilityBody(id),
    );
  }

  Widget _buildUtilityBody(String id) {
    switch (id) {
      case 'phone_flashlight':
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
              size: 110,
              color: _torchOn ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: Icon(_torchOn ? Icons.power_settings_new : Icons.flash_on),
              label: Text(_torchOn ? AppStrings.tr('Turn OFF Flashlight', 'إيقاف الكشاف') : AppStrings.tr('Turn ON Flashlight', 'تشغيل الكشاف')),
              onPressed: () async {
                _periodicTimer?.cancel();
                _sosActive = false;
                final next = !_torchOn;
                await NativeBridge.toggleFlashlight(next);
                setState(() => _torchOn = next);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.sos),
              label: Text(_sosActive ? AppStrings.tr('Stop SOS Strobe', 'إيقاف وميض الطوارئ') : AppStrings.tr('SOS Strobe Mode', 'وضع وميض الطوارئ SOS')),
              onPressed: () {
                if (_sosActive) {
                  _periodicTimer?.cancel();
                  NativeBridge.toggleFlashlight(false);
                  setState(() {
                    _sosActive = false;
                    _torchOn = false;
                  });
                } else {
                  setState(() => _sosActive = true);
                  _periodicTimer = Timer.periodic(const Duration(milliseconds: 450), (_) async {
                    _torchOn = !_torchOn;
                    await NativeBridge.toggleFlashlight(_torchOn);
                    if (mounted) setState(() {});
                  });
                }
              },
            ),
          ],
        );

      case 'phone_compass':
        const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
        final dir = dirs[((_headingDeg + 22.5) % 360 ~/ 45)];
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: -_headingDeg * (pi / 180),
                child: const Icon(Icons.navigation, size: 140, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              Text(
                '${_headingDeg.toStringAsFixed(0)}° $dir',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );

      case 'phone_level':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 3),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.add, size: 40, color: Colors.white54),
                    Transform.translate(
                      offset: Offset(-_tiltX * 9, _tiltY * 9),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'X: ${_tiltX.toStringAsFixed(2)}°   |   Y: ${_tiltY.toStringAsFixed(2)}°',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );

      case 'phone_ruler':
        return SizedBox(
          height: 600,
          child: CustomPaint(
            painter: _RulerPainter(),
            size: Size.infinite,
          ),
        );

      case 'phone_sound':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_micError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_micError, style: const TextStyle(color: Colors.orangeAccent)),
              ),
            ResultCard(
              title: AppStrings.tr('Sound Level (dB)', 'شدة الصوت الحالية'),
              value: '${_currentDb.toStringAsFixed(1)} dB',
              subtitle: 'Peak: ${_peakDb.toStringAsFixed(1)} dB',
              copyable: false,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: ((_currentDb - 20) / 100).clamp(0.0, 1.0),
              minHeight: 16,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(_micListening ? Icons.stop : Icons.mic),
              label: Text(_micListening ? AppStrings.tr('Stop Meter', 'إيقاف القياس') : AppStrings.tr('Start Sound Meter', 'بدء قياس الصوت')),
              onPressed: _toggleMic,
            ),
          ],
        );

      case 'phone_magnifier':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(AppStrings.tr('Snap Close-Up to Magnify (8x)', 'التقط صورة للتكبير 8x')),
                    onPressed: () async {
                      final x = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (x != null) setState(() => _magnifierImage = File(x.path));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off),
                  onPressed: () async {
                    _torchOn = !_torchOn;
                    await NativeBridge.toggleFlashlight(_torchOn);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_magnifierImage != null)
              SizedBox(
                height: 440,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 8.0,
                  child: Image.file(_magnifierImage!),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(AppStrings.tr('Capture any small text/object and pinch-zoom up to 8x.', 'التقط صورة لأي نص صغير وكبّرها حتى 8 أضعاف.')),
                ),
              ),
          ],
        );

      case 'phone_battery':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ResultCard(
              title: AppStrings.tr('Battery Charge Level', 'نسبة شحن البطارية'),
              value: '${_batteryData['level'] ?? '--'}%',
              subtitle: (_batteryData['charging'] == true) ? '⚡ Charging' : 'On Battery',
              copyable: false,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(title: const Text('Temperature'), trailing: Text('${_batteryData['temperature'] ?? '--'} °C')),
                  ListTile(title: const Text('Voltage'), trailing: Text('${_batteryData['voltage'] ?? '--'} mV')),
                  ListTile(title: const Text('Health'), trailing: Text('${_batteryData['health'] ?? '--'}')),
                  ListTile(title: const Text('Technology'), trailing: Text('${_batteryData['technology'] ?? '--'}')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.tr('Refresh Battery Stats', 'تحديث بيانات البطارية')),
              onPressed: _loadBattery,
            ),
          ],
        );

      case 'phone_device':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: _deviceData.entries
              .map(
                (e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.key.toUpperCase()),
                    trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              )
              .toList(),
        );

      case 'phone_screen_test':
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              AppStrings.tr(
                'Inspect your screen for dead or stuck pixels by cycling through pure primary RGB colors in fullscreen.',
                'افحص شاشة هاتفك لاكتشاف أي بكسل تالف عبر التبديل بين الألوان الأساسية بملء الشاشة.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.fullscreen),
              label: Text(AppStrings.tr('Start Fullscreen Pixel Test', 'بدء فحص الشاشة الكاملة')),
              onPressed: () => setState(() => _fullScreenTest = true),
            ),
          ],
        );

      case 'phone_speed_test':
      default:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.speed),
              label: Text(AppStrings.tr('Start Download Speed Test', 'بدء قياس سرعة التحميل')),
              onPressed: _testingSpeed ? null : _runSpeedTest,
            ),
            const SizedBox(height: 16),
            if (_testingSpeed) const LinearProgressIndicator(),
            if (_speedResult.isNotEmpty) ...[
              const SizedBox(height: 12),
              ResultCard(
                title: AppStrings.tr('Internet Speed Result', 'نتيجة سرعة الإنترنت'),
                value: _speedResult,
              ),
            ],
          ],
        );
    }
  }
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 1.5;
    const textStyle = TextStyle(color: Colors.amber, fontSize: 11);

    // ~38 logical pixels per cm on standard Android density
    const pxPerMm = 3.78;
    for (int mm = 0; mm <= 150; mm++) {
      final y = mm * pxPerMm + 16;
      if (y > size.height) break;
      final isCm = mm % 10 == 0;
      final isHalf = mm % 5 == 0;
      final len = isCm ? 42.0 : (isHalf ? 28.0 : 16.0);
      canvas.drawLine(Offset(0, y), Offset(len, y), paint);
      if (isCm) {
        final tp = TextPainter(
          text: TextSpan(text: '${mm ~/ 10} cm', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(48, y - 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
