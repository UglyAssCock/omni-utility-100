import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class RandomizerToolScreen extends StatefulWidget {
  final String toolId;
  const RandomizerToolScreen({super.key, required this.toolId});

  @override
  State<RandomizerToolScreen> createState() => _RandomizerToolScreenState();
}

class _RandomizerToolScreenState extends State<RandomizerToolScreen> {
  final Random _rng = Random();

  // Dice
  int _diceCount = 2;
  List<int> _diceValues = [4, 6];
  int _customSides = 20;
  int _customRoll = 20;

  // Number
  final TextEditingController _minCtrl = TextEditingController(text: '1');
  final TextEditingController _maxCtrl = TextEditingController(text: '100');
  String _resultText = '';

  // List input (Wheel, Names, Teams)
  final TextEditingController _listCtrl = TextEditingController(
    text: 'Alice\nBob\nCharlie\nDiana\nOmar\nLayla',
  );
  int _teamCount = 2;

  // RPS
  String _rpsResult = '';

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  List<String> _parseList() {
    return _listCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'العشوائيات والألعاب',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildContent(id),
          if (_resultText.isNotEmpty) ...[
            const SizedBox(height: 20),
            ResultCard(
              title: AppStrings.tr('Result', 'النتيجة'),
              value: _resultText,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(String id) {
    switch (id) {
      case 'rand_dice':
        final sum = _diceValues.fold<int>(0, (a, b) => a + b);
        return Column(
          children: [
            Text(AppStrings.tr('Number of Dice: $_diceCount', 'عدد أحجار النرد: $_diceCount')),
            Slider(
              value: _diceCount.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              onChanged: (v) {
                setState(() {
                  _diceCount = v.round();
                  _diceValues = List.generate(_diceCount, (_) => _rng.nextInt(6) + 1);
                });
              },
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _diceValues
                  .map(
                    (val) => Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$val',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              '${AppStrings.tr('Total Sum', 'المجموع')}: $sum',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.casino),
              label: Text(AppStrings.tr('Roll Dice', 'ارمِ النرد')),
              onPressed: () {
                NativeBridge.vibrate();
                setState(() {
                  _diceValues = List.generate(_diceCount, (_) => _rng.nextInt(6) + 1);
                });
              },
            ),
          ],
        );

      case 'rand_custom_dice':
        return Column(
          children: [
            Wrap(
              spacing: 8,
              children: [4, 6, 8, 10, 12, 20, 100]
                  .map(
                    (s) => ChoiceChip(
                      label: Text('D$s'),
                      selected: _customSides == s,
                      onSelected: (_) => setState(() => _customSides = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            ResultCard(title: 'D$_customSides Roll', value: '$_customRoll'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.hexagon),
              label: Text(AppStrings.tr('Roll D$_customSides', 'ارمِ نرد D$_customSides')),
              onPressed: () {
                NativeBridge.vibrate();
                setState(() => _customRoll = _rng.nextInt(_customSides) + 1);
              },
            ),
          ],
        );

      case 'rand_wheel':
      case 'rand_name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _listCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Enter Options / Names (1 per line)', 'أدخل الخيارات أو الأسماء (كل اسم في سطر)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: Icon(id == 'rand_wheel' ? Icons.pie_chart : Icons.person_search),
              label: Text(
                id == 'rand_wheel'
                    ? AppStrings.tr('Spin the Wheel!', 'أدر عجلة الحظ!')
                    : AppStrings.tr('Pick Random Winner', 'اختر اسماً عشوائياً'),
              ),
              onPressed: () {
                final items = _parseList();
                if (items.isEmpty) return;
                NativeBridge.vibrate();
                setState(() {
                  _resultText = '🎉 ${items[_rng.nextInt(items.length)]}';
                });
              },
            ),
          ],
        );

      case 'rand_coin':
        return FilledButton.icon(
          icon: const Icon(Icons.monetization_on),
          label: Text(AppStrings.tr('Flip Coin', 'ارمِ العملة')),
          onPressed: () {
            NativeBridge.vibrate();
            final heads = _rng.nextBool();
            setState(() {
              _resultText = heads
                  ? AppStrings.tr('🪙 HEADS', '🪙 ملك (صورة)')
                  : AppStrings.tr('🪙 TAILS', '🪙 كتابة');
            });
          },
        );

      case 'rand_number':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('Min', 'الحد الأدنى'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('Max', 'الحد الأقصى'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.pin),
              label: Text(AppStrings.tr('Generate Random Number', 'توليد رقم عشوائي')),
              onPressed: () {
                final min = int.tryParse(_minCtrl.text) ?? 1;
                final max = int.tryParse(_maxCtrl.text) ?? 100;
                final low = min < max ? min : max;
                final high = max > min ? max : min + 1;
                setState(() {
                  _resultText = '${low + _rng.nextInt(high - low + 1)}';
                });
              },
            ),
          ],
        );

      case 'rand_card':
        return FilledButton.icon(
          icon: const Icon(Icons.style),
          label: Text(AppStrings.tr('Draw Playing Card', 'اسحب ورقة لعب')),
          onPressed: () {
            const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
            const suits = ['♠ Spades', '♥ Hearts', '♦ Diamonds', '♣ Clubs'];
            NativeBridge.vibrate();
            setState(() {
              _resultText = '${ranks[_rng.nextInt(ranks.length)]} of ${suits[_rng.nextInt(suits.length)]}';
            });
          },
        );

      case 'rand_yesno':
        return FilledButton.icon(
          icon: const Icon(Icons.help_outline),
          label: Text(AppStrings.tr('Decide YES or NO', 'قرر نعم أم لا')),
          onPressed: () {
            const answers = ['YES ✅', 'NO ❌', 'DEFINITELY YES 🔥', 'PROBABLY NOT ⚠️', 'ASK AGAIN 🔄'];
            NativeBridge.vibrate();
            setState(() {
              _resultText = answers[_rng.nextInt(answers.length)];
            });
          },
        );

      case 'rand_teams':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _listCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppStrings.tr('Player Names (1 per line)', 'أسماء اللاعبين (كل اسم في سطر)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(AppStrings.tr('Number of Teams: $_teamCount', 'عدد الفرق: $_teamCount')),
            Slider(
              value: _teamCount.toDouble(),
              min: 2,
              max: 8,
              divisions: 6,
              onChanged: (v) => setState(() => _teamCount = v.round()),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.groups),
              label: Text(AppStrings.tr('Shuffle & Split into Teams', 'تقسيم الفرق عشوائياً')),
              onPressed: () {
                final list = _parseList()..shuffle(_rng);
                final teams = List.generate(_teamCount, (_) => <String>[]);
                for (int i = 0; i < list.length; i++) {
                  teams[i % _teamCount].add(list[i]);
                }
                final buf = StringBuffer();
                for (int t = 0; t < teams.length; t++) {
                  buf.writeln('Team ${t + 1}: ${teams[t].join(", ")}');
                }
                setState(() => _resultText = buf.toString().trim());
              },
            ),
          ],
        );

      case 'rand_lottery':
        return FilledButton.icon(
          icon: const Icon(Icons.confirmation_number),
          label: Text(AppStrings.tr('Generate 6 Lottery Numbers (1-49)', 'توليد 6 أرقام يانصيب')),
          onPressed: () {
            final set = <int>{};
            while (set.length < 6) {
              set.add(_rng.nextInt(49) + 1);
            }
            final sorted = set.toList()..sort();
            final bonus = _rng.nextInt(10) + 1;
            setState(() {
              _resultText = '${sorted.join("  •  ")}   [+$bonus]';
            });
          },
        );

      case 'rand_rps':
      default:
        const moves = ['🪨 Rock', '📄 Paper', '✂️ Scissors'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.tr('Choose your move:', 'اختر حركتك:')),
            const SizedBox(height: 10),
            Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.tonal(
                      onPressed: () {
                        final cpu = _rng.nextInt(3);
                        String outcome;
                        if (i == cpu) {
                          outcome = AppStrings.tr('DRAW 🤝', 'تعادل 🤝');
                        } else if ((i == 0 && cpu == 2) || (i == 1 && cpu == 0) || (i == 2 && cpu == 1)) {
                          outcome = AppStrings.tr('YOU WIN 🏆', 'أنت الفائز 🏆');
                        } else {
                          outcome = AppStrings.tr('CPU WINS 🤖', 'فاز الهاتف 🤖');
                        }
                        setState(() {
                          _rpsResult = 'You: ${moves[i]}\nCPU: ${moves[cpu]}\n\n$outcome';
                        });
                      },
                      child: Text(moves[i], textAlign: TextAlign.center),
                    ),
                  ),
                );
              }),
            ),
            if (_rpsResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              ResultCard(title: 'Match Outcome', value: _rpsResult),
            ],
          ],
        );
    }
  }
}
