import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class TimeToolScreen extends StatefulWidget {
  final String toolId;
  const TimeToolScreen({super.key, required this.toolId});

  @override
  State<TimeToolScreen> createState() => _TimeToolScreenState();
}

class _TimeToolScreenState extends State<TimeToolScreen> {
  Timer? _timer;

  // Stopwatch & Laps
  int _elapsedMs = 0;
  bool _running = false;
  final List<String> _laps = [];

  // Countdown & Pomodoro & HIIT
  int _remainingSec = 300;
  int _inputMinutes = 5;
  String _phaseLabel = 'Work / Focus';
  int _hiitRound = 1;

  // Multi timers
  final List<int> _multiRemaining = [60, 180, 300, 600];
  final List<bool> _multiRunning = [false, false, false, false];

  // Chess clock
  int _chessP1Ms = 300000;
  int _chessP2Ms = 300000;
  int _activeChessPlayer = 0; // 0 = paused, 1 = P1, 2 = P2

  // Date diff & Alarm
  DateTime _dateA = DateTime.now();
  DateTime _dateB = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _alarmTime = const TimeOfDay(hour: 7, minute: 30);
  bool _alarmArmed = false;

  @override
  void initState() {
    super.initState();
    if (widget.toolId == 'time_pomodoro') {
      _remainingSec = 25 * 60;
    } else if (widget.toolId == 'time_hiit') {
      _remainingSec = 30;
      _phaseLabel = 'HIGH INTENSITY (30s)';
    }
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer t) {
    if (!mounted) return;
    final id = widget.toolId;

    if ((id == 'time_stopwatch' || id == 'time_laps') && _running) {
      setState(() => _elapsedMs += 100);
    }

    if ((id == 'time_countdown' || id == 'time_pomodoro' || id == 'time_hiit') &&
        _running &&
        t.tick % 10 == 0) {
      setState(() {
        if (_remainingSec > 0) {
          _remainingSec--;
        } else {
          NativeBridge.vibrate(400);
          if (id == 'time_hiit') {
            if (_phaseLabel.startsWith('HIGH')) {
              _phaseLabel = 'REST (15s)';
              _remainingSec = 15;
            } else {
              _hiitRound++;
              _phaseLabel = 'HIGH INTENSITY (30s)';
              _remainingSec = 30;
            }
          } else {
            _running = false;
          }
        }
      });
    }

    if (id == 'time_multi' && t.tick % 10 == 0) {
      bool anyChanged = false;
      for (int i = 0; i < _multiRemaining.length; i++) {
        if (_multiRunning[i] && _multiRemaining[i] > 0) {
          _multiRemaining[i]--;
          anyChanged = true;
          if (_multiRemaining[i] == 0) {
            _multiRunning[i] = false;
            NativeBridge.vibrate(300);
          }
        }
      }
      if (anyChanged) setState(() {});
    }

    if (id == 'time_chess' && _activeChessPlayer != 0) {
      setState(() {
        if (_activeChessPlayer == 1) {
          _chessP1Ms = (_chessP1Ms - 100).clamp(0, 99999999);
          if (_chessP1Ms == 0) {
            _activeChessPlayer = 0;
            NativeBridge.vibrate(500);
          }
        } else if (_activeChessPlayer == 2) {
          _chessP2Ms = (_chessP2Ms - 100).clamp(0, 99999999);
          if (_chessP2Ms == 0) {
            _activeChessPlayer = 0;
            NativeBridge.vibrate(500);
          }
        }
      });
    }

    if (id == 'time_alarm' && _alarmArmed && t.tick % 10 == 0) {
      final now = DateTime.now();
      if (now.hour == _alarmTime.hour && now.minute == _alarmTime.minute && now.second == 0) {
        NativeBridge.vibrate(800);
        setState(() => _alarmArmed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.tr('⏰ ALARM RINGING!', '⏰ حان وقت المنبه!'))),
        );
      }
    }

    if (id == 'time_world' && t.tick % 10 == 0) {
      setState(() {});
    }
  }

  String _formatMs(int ms) {
    final totalSec = ms ~/ 1000;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    final tenths = ((ms % 1000) ~/ 100).toString();
    return '$m:$s.$tenths';
  }

  String _formatSec(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'أدوات الوقت والمؤقتات',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildBody(id)],
      ),
    );
  }

  Widget _buildBody(String id) {
    switch (id) {
      case 'time_stopwatch':
      case 'time_laps':
        return Column(
          children: [
            ResultCard(
              title: AppStrings.tr('Elapsed Time', 'الوقت المنقضي'),
              value: _formatMs(_elapsedMs),
              copyable: false,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? AppStrings.tr('Pause', 'إيقاف مؤقت') : AppStrings.tr('Start', 'بدء')),
                  onPressed: () => setState(() => _running = !_running),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.flag),
                  label: Text(AppStrings.tr('Lap', 'جولة')),
                  onPressed: () {
                    if (_elapsedMs > 0) {
                      setState(() => _laps.insert(0, 'Lap ${_laps.length + 1}: ${_formatMs(_elapsedMs)}'));
                    }
                  },
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _running = false;
                    _elapsedMs = 0;
                    _laps.clear();
                  }),
                  child: Text(AppStrings.tr('Reset', 'تصفير')),
                ),
              ],
            ),
            if (_laps.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._laps.map((l) => ListTile(dense: true, leading: const Icon(Icons.flag), title: Text(l))),
            ],
          ],
        );

      case 'time_countdown':
      case 'time_pomodoro':
      case 'time_hiit':
        return Column(
          children: [
            if (id == 'time_hiit')
              Text('Round $_hiitRound • $_phaseLabel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (id == 'time_pomodoro')
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Focus (25m)'),
                    selected: _phaseLabel == 'Work / Focus',
                    onSelected: (_) => setState(() {
                      _running = false;
                      _phaseLabel = 'Work / Focus';
                      _remainingSec = 25 * 60;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Short Break (5m)'),
                    selected: _phaseLabel == 'Short Break',
                    onSelected: (_) => setState(() {
                      _running = false;
                      _phaseLabel = 'Short Break';
                      _remainingSec = 5 * 60;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Long Break (15m)'),
                    selected: _phaseLabel == 'Long Break',
                    onSelected: (_) => setState(() {
                      _running = false;
                      _phaseLabel = 'Long Break';
                      _remainingSec = 15 * 60;
                    }),
                  ),
                ],
              ),
            if (id == 'time_countdown') ...[
              Text(AppStrings.tr('Preset Duration: $_inputMinutes min', 'المدة: $_inputMinutes دقيقة')),
              Slider(
                value: _inputMinutes.toDouble(),
                min: 1,
                max: 120,
                divisions: 119,
                onChanged: (v) {
                  setState(() {
                    _inputMinutes = v.round();
                    if (!_running) _remainingSec = _inputMinutes * 60;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            ResultCard(
              title: AppStrings.tr('Remaining', 'الوقت المتبقي'),
              value: _formatSec(_remainingSec),
              copyable: false,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? AppStrings.tr('Pause', 'إيقاف مؤقت') : AppStrings.tr('Start', 'بدء')),
                  onPressed: () => setState(() => _running = !_running),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _running = false;
                    _remainingSec = id == 'time_pomodoro'
                        ? 25 * 60
                        : (id == 'time_hiit' ? 30 : _inputMinutes * 60);
                  }),
                  child: Text(AppStrings.tr('Reset', 'إعادة ضبط')),
                ),
              ],
            ),
          ],
        );

      case 'time_multi':
        final presets = [60, 180, 300, 600];
        return Column(
          children: List.generate(4, (i) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Timer #${i + 1} (${presets[i] ~/ 60} min)'),
                subtitle: Text(
                  _formatSec(_multiRemaining[i]),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_multiRunning[i] ? Icons.pause : Icons.play_arrow),
                      onPressed: () => setState(() => _multiRunning[i] = !_multiRunning[i]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() {
                        _multiRunning[i] = false;
                        _multiRemaining[i] = presets[i];
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),
        );

      case 'time_world':
        final utc = DateTime.now().toUtc();
        final cities = {
          'UTC / GMT': 0,
          'London (UK)': 0,
          'Algiers / Oran / Paris (CET)': 1,
          'Cairo / Jerusalem': 2,
          'Makkah / Riyadh / Doha': 3,
          'Dubai (UAE)': 4,
          'Tokyo (Japan)': 9,
          'New York (EST)': -5,
          'Los Angeles (PST)': -8,
        };
        return Column(
          children: cities.entries.map((e) {
            final cityTime = utc.add(Duration(hours: e.value));
            final hh = cityTime.hour.toString().padLeft(2, '0');
            final mm = cityTime.minute.toString().padLeft(2, '0');
            final ss = cityTime.second.toString().padLeft(2, '0');
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.public),
                title: Text(e.key),
                subtitle: Text('UTC${e.value >= 0 ? "+${e.value}" : e.value}'),
                trailing: Text(
                  '$hh:$mm:$ss',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        );

      case 'time_alarm':
        return Column(
          children: [
            ResultCard(
              title: AppStrings.tr('Alarm Time', 'وقت المنبه'),
              value: _alarmTime.format(context),
              subtitle: _alarmArmed
                  ? AppStrings.tr('Status: ARMED 🔔', 'الحالة: مفعل 🔔')
                  : AppStrings.tr('Status: Off', 'الحالة: غير مفعل'),
              copyable: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(AppStrings.tr('Pick Time', 'اختر الوقت')),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _alarmTime);
                      if (picked != null) {
                        setState(() => _alarmTime = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(_alarmArmed ? Icons.alarm_off : Icons.alarm_on),
                    label: Text(_alarmArmed ? AppStrings.tr('Disarm', 'إيقاف') : AppStrings.tr('Arm Alarm', 'تفعيل المنبه')),
                    onPressed: () => setState(() => _alarmArmed = !_alarmArmed),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'time_chess':
        return Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _activeChessPlayer = 2),
              child: Container(
                height: 170,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeChessPlayer == 1 ? Colors.green.withOpacity(0.3) : Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('PLAYER 1 (Tap to switch turn)'),
                    Text(_formatMs(_chessP1Ms), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.pause),
                  label: Text(AppStrings.tr('Pause', 'إيقاف مؤقت')),
                  onPressed: () => setState(() => _activeChessPlayer = 0),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(AppStrings.tr('Reset (5m)', 'تصفير (5 د)')),
                  onPressed: () => setState(() {
                    _activeChessPlayer = 0;
                    _chessP1Ms = 300000;
                    _chessP2Ms = 300000;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _activeChessPlayer = 1),
              child: Container(
                height: 170,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeChessPlayer == 2 ? Colors.green.withOpacity(0.3) : Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('PLAYER 2 (Tap to switch turn)'),
                    Text(_formatMs(_chessP2Ms), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'time_datediff':
      default:
        final diffDays = _dateB.difference(_dateA).inDays.abs();
        final years = diffDays ~/ 365;
        final months = (diffDays % 365) ~/ 30;
        final days = (diffDays % 365) % 30;
        return Column(
          children: [
            ListTile(
              title: Text(AppStrings.tr('Start Date', 'تاريخ البداية')),
              subtitle: Text(_dateA.toIso8601String().split('T').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateA,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dateA = d);
              },
            ),
            ListTile(
              title: Text(AppStrings.tr('End Date', 'تاريخ النهاية')),
              subtitle: Text(_dateB.toIso8601String().split('T').first),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateB,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dateB = d);
              },
            ),
            const SizedBox(height: 12),
            ResultCard(
              title: AppStrings.tr('Date Difference', 'الفرق بين التاريخين'),
              value: '$diffDays Days',
              subtitle: '$years years, $months months, $days days  •  ${diffDays * 24} hours',
            ),
          ],
        );
    }
  }
}
