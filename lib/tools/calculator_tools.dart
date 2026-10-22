import 'dart:math';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class CalculatorToolScreen extends StatefulWidget {
  final String toolId;
  const CalculatorToolScreen({super.key, required this.toolId});

  @override
  State<CalculatorToolScreen> createState() => _CalculatorToolScreenState();
}

class _CalculatorToolScreenState extends State<CalculatorToolScreen> {
  // Scientific
  String _expr = '';
  String _sciResult = '0';

  // Generic numeric inputs
  final TextEditingController _c1 = TextEditingController(text: '100');
  final TextEditingController _c2 = TextEditingController(text: '15');
  final TextEditingController _c3 = TextEditingController(text: '5');

  // GPA courses
  final List<Map<String, double>> _courses = [
    {'grade': 4.0, 'credits': 3.0},
    {'grade': 3.5, 'credits': 3.0},
    {'grade': 3.0, 'credits': 4.0},
  ];

  // Birthdate for Age
  DateTime _birthDate = DateTime(2000, 1, 1);

  @override
  void initState() {
    super.initState();
    if (widget.toolId == 'calc_bmi') {
      _c1.text = '72'; // kg
      _c2.text = '175'; // cm
    } else if (widget.toolId == 'calc_loan' || widget.toolId == 'calc_compound') {
      _c1.text = '10000'; // Principal
      _c2.text = '6.5'; // Annual %
      _c3.text = '5'; // Years
    }
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  void _evalScientific() {
    if (_expr.trim().isEmpty) return;
    try {
      final sanitized = _expr
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793');
      final p = Parser();
      final exp = p.parse(sanitized);
      final eval = exp.evaluate(EvaluationType.REAL, ContextModel());
      setState(() => _sciResult = eval.toString());
    } catch (_) {
      setState(() => _sciResult = 'Syntax Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'الحاسبات الذكية',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildCalculator(id)],
      ),
    );
  }

  Widget _buildCalculator(String id) {
    final v1 = double.tryParse(_c1.text) ?? 0.0;
    final v2 = double.tryParse(_c2.text) ?? 0.0;
    final v3 = double.tryParse(_c3.text) ?? 1.0;

    switch (id) {
      case 'calc_scientific':
        final keys = [
          'sin(', 'cos(', 'tan(', 'sqrt(',
          '(', ')', '^', '÷',
          '7', '8', '9', '×',
          '4', '5', '6', '-',
          '1', '2', '3', '+',
          '0', '.', 'π', '=',
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_expr.isEmpty ? '0' : _expr, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(_sciResult, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _expr = '';
                      _sciResult = '0';
                    }),
                    child: const Text('AC'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
                    }),
                    child: const Text('⌫ DEL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.4,
              ),
              itemCount: keys.length,
              itemBuilder: (context, i) {
                final k = keys[i];
                return FilledButton.tonal(
                  onPressed: () {
                    if (k == '=') {
                      _evalScientific();
                    } else {
                      setState(() => _expr += k);
                    }
                  },
                  child: Text(k, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ],
        );

      case 'calc_percent':
        final pctOf = (v2 / 100.0) * v1;
        final isWhatPct = v1 != 0 ? (v2 / v1) * 100.0 : 0.0;
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Base Value (X)', 'القيمة الأساسية (X)')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Percentage / Part (Y)', 'النسبة المئوية أو الجزء (Y)')),
            const SizedBox(height: 16),
            ResultCard(
              title: '$v2% of $v1',
              value: pctOf.toStringAsFixed(2),
              subtitle: '$v2 is ${isWhatPct.toStringAsFixed(2)}% of $v1',
            ),
          ],
        );

      case 'calc_tip':
        final people = v3 <= 0 ? 1.0 : v3;
        final tipAmt = v1 * (v2 / 100.0);
        final total = v1 + tipAmt;
        final perPerson = total / people;
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Bill Amount', 'قيمة الفاتورة')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Tip Percentage (%)', 'نسبة الإكرامية (%)')),
            const SizedBox(height: 12),
            _numField(_c3, AppStrings.tr('Number of People', 'عدد الأشخاص')),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Each Person Pays', 'حصة كل شخص'),
              value: perPerson.toStringAsFixed(2),
              subtitle: 'Total: ${total.toStringAsFixed(2)}  •  Tip: ${tipAmt.toStringAsFixed(2)}',
            ),
          ],
        );

      case 'calc_loan':
        final r = (v2 / 100.0) / 12.0;
        final n = (v3 <= 0 ? 1.0 : v3) * 12.0;
        final emi = r == 0
            ? (v1 / n)
            : (v1 * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
        final totalPay = emi * n;
        final totalInterest = totalPay - v1;
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Loan Principal', 'مبلغ القرض')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Annual Interest Rate (%)', 'نسبة الفائدة السنوية (%)')),
            const SizedBox(height: 12),
            _numField(_c3, AppStrings.tr('Loan Term (Years)', 'مدة القرض (سنوات)')),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Monthly EMI Payment', 'القسط الشهري'),
              value: emi.toStringAsFixed(2),
              subtitle: 'Total Interest: ${totalInterest.toStringAsFixed(2)}  •  Total Payment: ${totalPay.toStringAsFixed(2)}',
            ),
          ],
        );

      case 'calc_bmi':
        final heightM = (v2 <= 0 ? 170.0 : v2) / 100.0;
        final bmi = v1 / (heightM * heightM);
        String cat = 'Normal Weight';
        if (bmi < 18.5) {
          cat = 'Underweight';
        } else if (bmi >= 25 && bmi < 30) {
          cat = 'Overweight';
        } else if (bmi >= 30) {
          cat = 'Obese';
        }
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Weight (kg)', 'الوزن (كجم)')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Height (cm)', 'الطول (سم)')),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Body Mass Index (BMI)', 'مؤشر كتلة الجسم'),
              value: bmi.toStringAsFixed(1),
              subtitle: 'Category: $cat',
            ),
          ],
        );

      case 'calc_discount':
        final saved = v1 * (v2 / 100.0);
        final finalPrice = v1 - saved;
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Original Price', 'السعر الأصلي')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Discount (%)', 'نسبة الخصم (%)')),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Final Price After Discount', 'السعر النهائي بعد الخصم'),
              value: finalPrice.toStringAsFixed(2),
              subtitle: 'You Save: ${saved.toStringAsFixed(2)}',
            ),
          ],
        );

      case 'calc_gpa':
        double totalPts = 0;
        double totalCr = 0;
        for (final c in _courses) {
          totalPts += (c['grade'] ?? 0) * (c['credits'] ?? 0);
          totalCr += (c['credits'] ?? 0);
        }
        final gpa = totalCr > 0 ? totalPts / totalCr : 0.0;
        return Column(
          children: [
            ...List.generate(_courses.length, (i) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('Course #${i + 1}'),
                  subtitle: Text('Grade Points: ${_courses[i]['grade']}  •  Credits: ${_courses[i]['credits']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _courses.length <= 1 ? null : () => setState(() => _courses.removeAt(i)),
                  ),
                ),
              );
            }),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [4.0, 3.5, 3.0, 2.5, 2.0]
                  .map(
                    (g) => FilledButton.tonal(
                      onPressed: () => setState(() => _courses.add({'grade': g, 'credits': 3.0})),
                      child: Text('+ $g'),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Cumulative GPA', 'المعدل التراكمي GPA'),
              value: gpa.toStringAsFixed(2),
              subtitle: 'Total Credits: ${totalCr.toStringAsFixed(0)}',
            ),
          ],
        );

      case 'calc_age':
        final now = DateTime.now();
        final days = now.difference(_birthDate).inDays;
        final yrs = days ~/ 365;
        final mos = (days % 365) ~/ 30;
        final remDays = (days % 365) % 30;
        return Column(
          children: [
            ListTile(
              title: Text(AppStrings.tr('Date of Birth', 'تاريخ الميلاد')),
              subtitle: Text(_birthDate.toIso8601String().split('T').first),
              trailing: const Icon(Icons.cake),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
            const SizedBox(height: 12),
            ResultCard(
              title: AppStrings.tr('Exact Age', 'العمر الدقيق'),
              value: '$yrs Years, $mos Months, $remDays Days',
              subtitle: 'Total Days Lived: $days days',
            ),
          ],
        );

      case 'calc_tax':
        final taxAmt = v1 * (v2 / 100.0);
        final gross = v1 + taxAmt;
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Net Amount', 'المبلغ الصافي')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Tax / VAT Rate (%)', 'نسبة الضريبة (%)')),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Total Including Tax', 'الإجمالي شامل الضريبة'),
              value: gross.toStringAsFixed(2),
              subtitle: 'Tax Amount: ${taxAmt.toStringAsFixed(2)}',
            ),
          ],
        );

      case 'calc_compound':
      default:
        final amount = v1 * pow(1 + (v2 / 100.0), v3);
        final profit = amount - v1;
        return Column(
          children: [
            _numField(_c1, AppStrings.tr('Initial Principal', 'رأس المال الأساسي')),
            const SizedBox(height: 12),
            _numField(_c2, AppStrings.tr('Annual Return Rate (%)', 'نسبة العائد السنوي (%)')),
            const SizedBox(height: 12),
            _numField(_c3, AppStrings.tr('Time Period (Years)', 'عدد السنوات')),
            const SizedBox(height: 16),
            ResultCard(
              title: AppStrings.tr('Future Compound Value', 'القيمة المستقبلية المركبة'),
              value: amount.toStringAsFixed(2),
              subtitle: 'Compound Profit: +${profit.toStringAsFixed(2)}',
            ),
          ],
        );
    }
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
