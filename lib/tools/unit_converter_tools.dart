import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';

class UnitConverterToolScreen extends StatefulWidget {
  final String toolId;
  const UnitConverterToolScreen({super.key, required this.toolId});

  @override
  State<UnitConverterToolScreen> createState() => _UnitConverterToolScreenState();
}

class _UnitConverterToolScreenState extends State<UnitConverterToolScreen> {
  final TextEditingController _inputCtrl = TextEditingController(text: '1');
  late String _fromUnit;
  late String _toUnit;

  // Currency rates relative to USD (offline fallback + live update)
  Map<String, double> _currencyRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'SAR': 3.75,
    'AED': 3.67,
    'EGP': 48.50,
    'DZD': 134.50,
    'MAD': 9.95,
    'TND': 3.10,
    'KWD': 0.31,
    'QAR': 3.64,
    'TRY': 34.20,
    'JPY': 152.0,
    'CNY': 7.12,
    'CAD': 1.38,
  };
  String _currencyStatus = 'Offline Built-in Rates (Tap Sync for Live Rates)';
  bool _syncingRates = false;

  // Number base state
  int _sourceBase = 10;

  @override
  void initState() {
    super.initState();
    final units = _getUnitsForTool(widget.toolId);
    _fromUnit = units.first;
    _toUnit = units.length > 1 ? units[1] : units.first;
    if (widget.toolId == 'unit_currency') {
      _loadCachedRates();
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_currency_rates');
    if (raw != null) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw));
        setState(() {
          _currencyRates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
          _currencyStatus = AppStrings.tr('Using cached rates', 'يستخدم أسعار الصرف المخزنة');
        });
      } catch (_) {}
    }
  }

  Future<void> _fetchLiveCurrencyRates() async {
    setState(() => _syncingRates = true);
    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rates = Map<String, dynamic>.from(data['rates']);
        final updated = <String, double>{};
        for (final k in _currencyRates.keys) {
          if (rates.containsKey(k)) {
            updated[k] = (rates[k] as num).toDouble();
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_currency_rates', jsonEncode(updated));
        setState(() {
          _currencyRates = updated;
          _currencyStatus = AppStrings.tr('Live rates updated!', 'تم تحديث الأسعار مباشرة!');
        });
      } else {
        setState(() => _currencyStatus = AppStrings.tr('Offline mode (Server error)', 'وضع عدم الاتصال'));
      }
    } catch (_) {
      setState(() => _currencyStatus = AppStrings.tr('No internet - Using offline rates', 'لا يوجد إنترنت - أسعار محفوظة'));
    } finally {
      setState(() => _syncingRates = false);
    }
  }

  Map<String, double> _factorMap(String id) {
    switch (id) {
      case 'unit_length':
        return {
          'Meter (m)': 1.0,
          'Kilometer (km)': 1000.0,
          'Centimeter (cm)': 0.01,
          'Millimeter (mm)': 0.001,
          'Mile (mi)': 1609.344,
          'Yard (yd)': 0.9144,
          'Foot (ft)': 0.3048,
          'Inch (in)': 0.0254,
          'Nautical Mile': 1852.0,
        };
      case 'unit_weight':
        return {
          'Kilogram (kg)': 1.0,
          'Gram (g)': 0.001,
          'Milligram (mg)': 0.000001,
          'Metric Ton (t)': 1000.0,
          'Pound (lb)': 0.45359237,
          'Ounce (oz)': 0.02834952,
          'Stone (st)': 6.350293,
        };
      case 'unit_volume':
        return {
          'Liter (L)': 1.0,
          'Milliliter (mL)': 0.001,
          'Cubic Meter (m³)': 1000.0,
          'US Gallon (gal)': 3.78541178,
          'US Quart (qt)': 0.9463529,
          'US Cup': 0.236588,
          'US Fluid Ounce (fl oz)': 0.0295735,
          'Imperial Gallon': 4.54609,
        };
      case 'unit_area':
        return {
          'Square Meter (m²)': 1.0,
          'Square Kilometer (km²)': 1000000.0,
          'Square Centimeter (cm²)': 0.0001,
          'Hectare (ha)': 10000.0,
          'Acre': 4046.8564,
          'Square Foot (ft²)': 0.092903,
          'Square Inch (in²)': 0.00064516,
        };
      case 'unit_speed':
        return {
          'Meters/sec (m/s)': 1.0,
          'Kilometers/hour (km/h)': 0.27777778,
          'Miles/hour (mph)': 0.44704,
          'Knot (kn)': 0.514444,
          'Mach': 343.0,
        };
      case 'unit_time':
        return {
          'Second (s)': 1.0,
          'Millisecond (ms)': 0.001,
          'Minute (min)': 60.0,
          'Hour (hr)': 3600.0,
          'Day': 86400.0,
          'Week': 604800.0,
          'Month (30d)': 2592000.0,
          'Year (365d)': 31536000.0,
        };
      case 'unit_data':
        return {
          'Byte (B)': 1.0,
          'Kilobyte (KB)': 1024.0,
          'Megabyte (MB)': 1048576.0,
          'Gigabyte (GB)': 1073741824.0,
          'Terabyte (TB)': 1099511627776.0,
          'Bit (b)': 0.125,
        };
      case 'unit_cooking':
        return {
          'Milliliter (mL)': 1.0,
          'Teaspoon (tsp)': 4.92892,
          'Tablespoon (tbsp)': 14.7868,
          'US Cup': 236.588,
          'Fluid Ounce (fl oz)': 29.5735,
          'Pint (pt)': 473.176,
          'Liter (L)': 1000.0,
        };
      default:
        return {'Unit': 1.0};
    }
  }

  List<String> _getUnitsForTool(String id) {
    if (id == 'unit_temp') {
      return ['Celsius (°C)', 'Fahrenheit (°F)', 'Kelvin (K)'];
    } else if (id == 'unit_fuel') {
      return ['km/L', 'MPG (US)', 'MPG (UK)', 'L/100km'];
    } else if (id == 'unit_currency') {
      return _currencyRates.keys.toList();
    } else if (id == 'unit_bases') {
      return ['BIN (2)', 'OCT (8)', 'DEC (10)', 'HEX (16)'];
    }
    return _factorMap(id).keys.toList();
  }

  double _convertValue(double val) {
    final id = widget.toolId;
    if (id == 'unit_temp') {
      double celsius;
      if (_fromUnit.startsWith('Celsius')) {
        celsius = val;
      } else if (_fromUnit.startsWith('Fahrenheit')) {
        celsius = (val - 32) * 5 / 9;
      } else {
        celsius = val - 273.15;
      }
      if (_toUnit.startsWith('Celsius')) return celsius;
      if (_toUnit.startsWith('Fahrenheit')) return celsius * 9 / 5 + 32;
      return celsius + 273.15;
    }

    if (id == 'unit_fuel') {
      // Base: km/L
      double kml;
      if (val <= 0) return 0;
      if (_fromUnit == 'km/L') {
        kml = val;
      } else if (_fromUnit == 'MPG (US)') {
        kml = val * 0.4251437;
      } else if (_fromUnit == 'MPG (UK)') {
        kml = val * 0.354006;
      } else {
        kml = 100.0 / val;
      }
      if (kml <= 0) return 0;
      if (_toUnit == 'km/L') return kml;
      if (_toUnit == 'MPG (US)') return kml / 0.4251437;
      if (_toUnit == 'MPG (UK)') return kml / 0.354006;
      return 100.0 / kml;
    }

    if (id == 'unit_currency') {
      final fromRate = _currencyRates[_fromUnit] ?? 1.0;
      final toRate = _currencyRates[_toUnit] ?? 1.0;
      return (val / fromRate) * toRate;
    }

    final map = _factorMap(id);
    final f1 = map[_fromUnit] ?? 1.0;
    final f2 = map[_toUnit] ?? 1.0;
    return (val * f1) / f2;
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.toolId;
    if (id == 'unit_bases') {
      return _buildNumberBasesScreen();
    }

    final units = _getUnitsForTool(id);
    final inputVal = double.tryParse(_inputCtrl.text) ?? 0.0;
    final converted = _convertValue(inputVal);

    return ToolScaffold(
      titleEn: id.toUpperCase().replaceAll('_', ' '),
      titleAr: 'محول الوحدات',
      actions: id == 'unit_currency'
          ? [
              IconButton(
                icon: _syncingRates
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                tooltip: AppStrings.tr('Update Live Rates', 'تحديث الأسعار'),
                onPressed: _syncingRates ? null : _fetchLiveCurrencyRates,
              ),
            ]
          : null,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (id == 'unit_currency')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_currencyStatus, style: const TextStyle(fontSize: 13)),
            ),
          TextField(
            controller: _inputCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: AppStrings.tr('Enter Value', 'أدخل القيمة'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _fromUnit,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('From', 'من'),
                    border: const OutlineInputBorder(),
                  ),
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _fromUnit = v ?? units.first),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  setState(() {
                    final tmp = _fromUnit;
                    _fromUnit = _toUnit;
                    _toUnit = tmp;
                  });
                },
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _toUnit,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('To', 'إلى'),
                    border: const OutlineInputBorder(),
                  ),
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _toUnit = v ?? units.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ResultCard(
            title: '$_fromUnit → $_toUnit',
            value: converted.toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), ''),
            subtitle: '$inputVal $_fromUnit',
          ),
        ],
      ),
    );
  }

  Widget _buildNumberBasesScreen() {
    final raw = _inputCtrl.text.trim();
    final parsed = int.tryParse(raw, radix: _sourceBase);

    return ToolScaffold(
      titleEn: 'Number Bases (Bin / Oct / Dec / Hex)',
      titleAr: 'تحويل الأنظمة العددية',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: _sourceBase,
            decoration: InputDecoration(
              labelText: AppStrings.tr('Input Base', 'النظام العددي للمدخل'),
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 2, child: Text('Binary (Base 2)')),
              DropdownMenuItem(value: 8, child: Text('Octal (Base 8)')),
              DropdownMenuItem(value: 10, child: Text('Decimal (Base 10)')),
              DropdownMenuItem(value: 16, child: Text('Hexadecimal (Base 16)')),
            ],
            onChanged: (v) => setState(() => _sourceBase = v ?? 10),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.tr('Input Number', 'أدخل الرقم'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (parsed == null)
            Text(
              AppStrings.tr('Invalid number for Base $_sourceBase', 'رقم غير صالح لهذا النظام العددي'),
              style: const TextStyle(color: Colors.redAccent),
            )
          else ...[
            ResultCard(title: 'Decimal (Base 10)', value: parsed.toRadixString(10)),
            const SizedBox(height: 8),
            ResultCard(title: 'Binary (Base 2)', value: parsed.toRadixString(2)),
            const SizedBox(height: 8),
            ResultCard(title: 'Octal (Base 8)', value: parsed.toRadixString(8)),
            const SizedBox(height: 8),
            ResultCard(title: 'Hexadecimal (Base 16)', value: parsed.toRadixString(16).toUpperCase()),
          ],
        ],
      ),
    );
  }
}
