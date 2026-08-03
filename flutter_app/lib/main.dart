import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:html/parser.dart' as html_parser;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ✅ کتابخانه Glass (فقط برای نوار پایین استفاده می‌شود)
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

part 'main.g.dart';

// -------------------- Helpers --------------------
String formatRial(double amount) {
  final formatted = NumberFormat('#,###').format(amount);
  return formatted.toPersianDigit();
}

String formatDoubleWithoutTrailingZeros(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  } else {
    String str = value.toString();
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0*$'), '');
      if (str.endsWith('.')) str = str.substring(0, str.length - 1);
    }
    return str;
  }
}

String formatWithSeparator(double value) {
  if (value == 0) return '';
  return NumberFormat('#,###').format(value);
}

String formatJalaliDate(DateTime dt) {
  final j = Jalali.fromDateTime(dt);
  return '${j.year}/${j.month.toString().padLeft(2,'0')}/${j.day.toString().padLeft(2,'0')}';
}

String coinName(String t) {
  switch(t) {
    case 'coin_new': return 'سکه تمام (امامی)';
    case 'coin_old': return 'سکه تمام (قدیم)';
    case 'coin_half': return 'نیم سکه';
    case 'coin_quarter': return 'ربع سکه';
    case 'coin_1g': return 'سکه یک گرمی';
    default: return t;
  }
}

String goldTypeName(String k) {
  switch(k) {
    case 'gold_18': return 'طلای ۱۸ عیار';
    case 'gold_24': return 'طلای ۲۴ عیار';
    case 'gold_ons': return 'انس طلا';
    case 'gold_mazneh': return 'مظنه تهران';
    case 'coin_old': return 'سکه قدیم';
    case 'coin_new': return 'سکه جدید';
    case 'coin_half': return 'نیم سکه';
    case 'coin_quarter': return 'ربع سکه';
    case 'coin_1g': return 'سکه یک گرمی';
    default: return k;
  }
}

String formatToman(double amount) {
  final toman = amount / 10;
  final formatted = NumberFormat('#,###').format(toman);
  return '${formatted.toPersianDigit()} تومان';
}

String numberToTomanWords(double amount) {
  final toman = amount / 10;
  final intValue = toman.round();
  final words = intValue.toString().toWord();
  return words.toPersianDigit() + ' تومان';
}

class NumberInputWithToman extends StatefulWidget {
  final String label;
  final String? initialValue;
  final ValueChanged<String> onSaved;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final bool isPrice;

  const NumberInputWithToman({
    Key? key,
    required this.label,
    this.initialValue,
    required this.onSaved,
    this.keyboardType = TextInputType.number,
    this.validator,
    this.isPrice = true,
  }) : super(key: key);

  @override
  _NumberInputWithTomanState createState() => _NumberInputWithTomanState();
}

class _NumberInputWithTomanState extends State<NumberInputWithToman> {
  late TextEditingController _controller;
  String _tomanText = '';
  String _wordsText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _updateDisplay(_controller.text);
    _controller.addListener(() {
      _updateDisplay(_controller.text);
    });
  }

  void _updateDisplay(String value) {
    final clean = value.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isNotEmpty && widget.isPrice) {
      final num = double.tryParse(clean) ?? 0;
      setState(() {
        _tomanText = formatToman(num);
        _wordsText = numberToTomanWords(num);
      });
    } else {
      setState(() {
        _tomanText = '';
        _wordsText = '';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(fontFamily: 'Vazir'),
          ),
          keyboardType: widget.keyboardType,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ThousandsSeparatorInputFormatter(),
          ],
          validator: widget.validator,
          onSaved: (v) {
            final cleaned = v?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
            widget.onSaved(cleaned);
          },
        ),
        if (_tomanText.isNotEmpty && widget.isPrice)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, right: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tomanText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  _wordsText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final clean = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return newValue;
    final intValue = int.tryParse(clean);
    if (intValue == null) return newValue;
    final formatted = NumberFormat('#,###').format(intValue);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Future<DateTime?> pickJalaliDate(BuildContext context, DateTime initial) async {
  final picked = await showPersianDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1370, 1, 1),
    lastDate: DateTime.now(),
  );
  return picked;
}

// -------------------- Utility Calculator --------------------
class Calculator {
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  static double calculateProfit({
    required double currentPrice,
    required double purchasePrice,
    required double quantity,
    required double paidAmount,
    required double interestRate,
    required int days,
  }) {
    final currentValue = currentPrice * quantity;
    final purchaseProfit = currentValue - paidAmount;
    double years = days / 365.0;
    double bankProfit = paidAmount * (pow(1 + interestRate / 100, years) - 1);
    return purchaseProfit - bankProfit;
  }
}

// -------------------- Models --------------------
@HiveType(typeId: 0)
class GoldTransaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String type;
  @HiveField(2) DateTime purchaseDate;
  @HiveField(3) double purchasePricePerUnit;
  @HiveField(4) double quantity;
  @HiveField(5) String description;
  @HiveField(6) double remainingQuantity;

  GoldTransaction({
    required this.id, required this.type, required this.purchaseDate,
    required this.purchasePricePerUnit, required this.quantity,
    required this.description, double? remainingQuantity,
  }) : remainingQuantity = remainingQuantity ?? quantity;
}

@HiveType(typeId: 1)
class CoinTransaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String coinType;
  @HiveField(2) DateTime purchaseDate;
  @HiveField(3) double purchasePricePerUnit;
  @HiveField(4) int count;
  @HiveField(5) String description;
  @HiveField(6) int remainingCount;

  CoinTransaction({
    required this.id, required this.coinType, required this.purchaseDate,
    required this.purchasePricePerUnit, required this.count,
    required this.description, int? remainingCount,
  }) : remainingCount = remainingCount ?? count;
}

@HiveType(typeId: 2)
class SaleTransaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String lotId;
  @HiveField(2) DateTime saleDate;
  @HiveField(3) double salePricePerUnit;
  @HiveField(4) double quantity;
  @HiveField(5) bool isGold;
  @HiveField(6) String? coinType;
  @HiveField(7) double purchasePricePerUnit;
  @HiveField(8) DateTime purchaseDate;

  SaleTransaction({
    required this.id, required this.lotId, required this.saleDate,
    required this.salePricePerUnit, required this.quantity,
    required this.isGold, this.coinType,
    required this.purchasePricePerUnit,
    required this.purchaseDate,
  });
}

// -------------------- Price Models --------------------
class PriceResponse {
  final String name;
  final double? currentPrice;
  final double? high;
  final double? low;
  final double? yesterdayAvg;
  final Change? change;

  PriceResponse({required this.name, this.currentPrice, this.high, this.low, this.yesterdayAvg, this.change});

  factory PriceResponse.fromJson(Map<String, dynamic> json) => PriceResponse(
    name: json['name'] ?? '',
    currentPrice: json['current_price'] != null ? (json['current_price'] as num).toDouble() : null,
    high: json['high'] != null ? (json['high'] as num).toDouble() : null,
    low: json['low'] != null ? (json['low'] as num).toDouble() : null,
    yesterdayAvg: json['yesterday_avg'] != null ? (json['yesterday_avg'] as num).toDouble() : null,
    change: json['change'] != null ? Change.fromJson(json['change']) : null,
  );
}

class Change {
  final double? value;
  final double? percent;
  final String? direction;
  Change({this.value, this.percent, this.direction});
  factory Change.fromJson(Map<String, dynamic> json) => Change(
    value: json['value'] != null ? (json['value'] as num).toDouble() : null,
    percent: json['percent'] != null ? (json['percent'] as num).toDouble() : null,
    direction: json['direction'],
  );
}

// -------------------- API Service --------------------
class ApiService {
  static const String _pageUrl = 'https://www.estjt.ir/price/';
  static const Map<String, String> _nameToKey = {
    'انس طلا': 'gold_ons', 'مظنه تهران': 'gold_mazneh',
    'طلای ۱۸ عیار': 'gold_18', 'طلای ۲۴ عیار': 'gold_24',
    'سکه طرح قدیم': 'coin_old', 'سکه طرح جدید': 'coin_new',
    'نیم سکه': 'coin_half', 'ربع سکه': 'coin_quarter', 'سکه یک گرمی': 'coin_1g',
  };

  static String _persianToEnglish(String s) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const english = '0123456789';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      final i = persian.indexOf(c);
      buf.write(i != -1 ? english[i] : c);
    }
    return buf.toString();
  }

  static double? _parsePrice(String text) {
    if (text.trim() == '—') return null;
    final cleaned = _persianToEnglish(text).replaceAll(RegExp(r'[^\d.]'), '');
    return cleaned.isEmpty ? null : double.tryParse(cleaned);
  }

  static Map<String, double?>? _parseChange(String text) {
    final t = _persianToEnglish(text);
    final m = RegExp(r'([\d.]+)\s*\(([\d.]+)\)').firstMatch(t);
    if (m != null) return {'value': double.tryParse(m.group(1)!), 'percent': double.tryParse(m.group(2)!)};
    return null;
  }

  static Future<Map<String, PriceResponse>> fetchAllPrices() async {
    try {
      final res = await http.get(Uri.parse(_pageUrl), headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html',
        'Accept-Language': 'en-US,en;q=0.5',
      });
      if (res.statusCode != 200) return {};
      final doc = html_parser.parse(res.body);
      final rows = doc.querySelectorAll('div.price-box table tbody tr');
      final Map<String, PriceResponse> prices = {};
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 6) continue;
        final name = cells[0].text.trim();
        final key = _nameToKey[name];
        if (key == null) continue;
        var cur = _parsePrice(cells[1].text.trim());
        var high = _parsePrice(cells[2].text.trim());
        var low = _parsePrice(cells[3].text.trim());
        var yday = _parsePrice(cells[4].text.trim());
        String? dir; double? cVal; double? cPct;
        final span = cells[5].querySelector('span');
        if (span != null) {
          if (span.classes.contains('asc')) dir = 'up';
          else if (span.classes.contains('desc')) dir = 'down';
          final cd = _parseChange(span.text.trim());
          if (cd != null) { cVal = cd['value']; cPct = cd['percent']; }
        }

        const rialsMultiplier = 10.0;
        if (key != 'gold_ons') {
          cur = cur != null ? cur * rialsMultiplier : null;
          high = high != null ? high * rialsMultiplier : null;
          low = low != null ? low * rialsMultiplier : null;
          yday = yday != null ? yday * rialsMultiplier : null;
          if (cVal != null) cVal = cVal * rialsMultiplier;
        }

        prices[key] = PriceResponse(
          name: name,
          currentPrice: cur,
          high: high,
          low: low,
          yesterdayAvg: yday,
          change: Change(value: cVal, percent: cPct, direction: dir),
        );
      }
      return prices;
    } catch (_) { return {}; }
  }
}

// -------------------- Providers --------------------
class PriceProvider extends ChangeNotifier {
  Map<String, PriceResponse> _prices = {};
  Map<String, PriceResponse> _lastSavedPrices = {};
  DateTime _lastUpdated = DateTime(2000);
  Timer? _timer;
  final SharedPreferences _prefs;
  static const List<String> _priceKeys = [
    'gold_18','gold_24','gold_ons','gold_mazneh',
    'coin_old','coin_new','coin_half','coin_quarter','coin_1g'
  ];
  Map<String, PriceResponse> get prices => UnmodifiableMapView(_prices);
  DateTime get lastUpdated => _lastUpdated;

  PriceProvider(this._prefs) {
    _loadSavedPrices(); fetchPrices(); startAutoUpdate();
  }

  void _loadSavedPrices() {
    _lastSavedPrices = {};
    for (var key in _priceKeys) {
      String? jsonStr = _prefs.getString('price_$key');
      if (jsonStr != null) {
        try {
          final json = jsonDecode(jsonStr);
          _lastSavedPrices[key] = PriceResponse.fromJson(json);
        } catch (_) {}
      }
    }
    if (_lastSavedPrices.isNotEmpty) {
      _prices = Map.from(_lastSavedPrices);
      int? t = _prefs.getInt('last_update');
      if (t != null) _lastUpdated = DateTime.fromMillisecondsSinceEpoch(t);
    }
  }

  Future<void> _savePrices(Map<String, PriceResponse> prices) async {
    for (var e in prices.entries) {
      final jsonStr = jsonEncode({
        'name': e.value.name,
        'current_price': e.value.currentPrice,
        'high': e.value.high,
        'low': e.value.low,
        'yesterday_avg': e.value.yesterdayAvg,
        'change': e.value.change != null ? {
          'value': e.value.change!.value,
          'percent': e.value.change!.percent,
          'direction': e.value.change!.direction,
        } : null,
      });
      await _prefs.setString('price_${e.key}', jsonStr);
    }
    await _prefs.setInt('last_update', DateTime.now().millisecondsSinceEpoch);
  }

  void startAutoUpdate({int intervalSeconds = 300}) {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => fetchPrices());
  }
  void setAutoUpdateInterval(int s) { startAutoUpdate(intervalSeconds: s); }

  Future<void> fetchPrices() async {
    final newPrices = await ApiService.fetchAllPrices();
    if (newPrices.isNotEmpty) {
      _prices = newPrices;
      _lastSavedPrices = Map.from(newPrices);
      _lastUpdated = DateTime.now();
      await _savePrices(newPrices);
    }
    notifyListeners();
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }
}

class SettingsProvider extends ChangeNotifier {
  double _bankInterestRate = 26.0;
  int _autoUpdateInterval = 300;
  Color _secondaryColor = Colors.amber;
  double get bankInterestRate => _bankInterestRate;
  int get autoUpdateInterval => _autoUpdateInterval;
  Color get secondaryColor => _secondaryColor;
  final SharedPreferences _prefs;
  SettingsProvider(this._prefs) { _loadSettings(); }
  void _loadSettings() {
    _bankInterestRate = _prefs.getDouble('bankInterestRate') ?? 26.0;
    _autoUpdateInterval = _prefs.getInt('autoUpdateInterval') ?? 300;
    final colorStr = _prefs.getString('secondaryColor');
    if (colorStr != null) {
      try {
        _secondaryColor = Color(int.parse(colorStr));
      } catch (_) {}
    }
  }
  Future<void> setBankInterestRate(double v) async { _bankInterestRate = v; await _prefs.setDouble('bankInterestRate', v); notifyListeners(); }
  Future<void> setAutoUpdateInterval(int s) async { _autoUpdateInterval = s; await _prefs.setInt('autoUpdateInterval', s); notifyListeners(); }
  Future<void> setSecondaryColor(Color c) async {
    _secondaryColor = c;
    await _prefs.setString('secondaryColor', c.value.toString());
    notifyListeners();
  }
}

/// BasePriceProvider با قابلیت ذخیره‌سازی در SharedPreferences
class BasePriceProvider extends ChangeNotifier {
  Map<String, double> _basePrices = {};
  final SharedPreferences _prefs;

  BasePriceProvider(this._prefs) {
    _loadBasePrices();
  }

  Map<String, double> get basePrices => UnmodifiableMapView(_basePrices);

  void _loadBasePrices() {
    final jsonStr = _prefs.getString('basePrices');
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _basePrices = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {
        _setDefaultBasePrices();
      }
    } else {
      _setDefaultBasePrices();
    }
    notifyListeners();
  }

  void _setDefaultBasePrices() {
    _basePrices = {
      'gold_18': 201226000.0,
      'gold_24': 268301333.0,
      'gold_ons': 0,
      'gold_mazneh': 20122600.0,
      'coin_old': 2089850000.0,
      'coin_new': 2089850000.0,
      'coin_half': 1081900000.0,
      'coin_quarter': 595200000.0,
      'coin_1g': 185000000.0,
    };
    _saveBasePrices();
  }

  Future<void> _saveBasePrices() async {
    await _prefs.setString('basePrices', jsonEncode(_basePrices));
  }

  Future<void> setBasePrice(String key, double value) async {
    _basePrices[key] = value;
    await _saveBasePrices();
    notifyListeners();
  }
}

class DataProvider extends ChangeNotifier {
  final Box<GoldTransaction> goldBox;
  final Box<CoinTransaction> coinBox;
  final Box<SaleTransaction> saleBox;

  DataProvider({required this.goldBox, required this.coinBox, required this.saleBox}) {
    if (goldBox.isEmpty && coinBox.isEmpty) _addDefaultData();
  }

  void _addDefaultData() {
    goldBox.addAll([
      GoldTransaction(id:'1',type:'gold_18',purchaseDate:DateTime(2025,1,2),purchasePricePerUnit:52518583,quantity:100,description:''),
      GoldTransaction(id:'2',type:'gold_18',purchaseDate:DateTime(2025,2,9),purchasePricePerUnit:65792511,quantity:61.195,description:''),
      GoldTransaction(id:'3',type:'gold_18',purchaseDate:DateTime(2025,4,13),purchasePricePerUnit:76180802,quantity:50,description:''),
      GoldTransaction(id:'4',type:'gold_18',purchaseDate:DateTime(2025,10,6),purchasePricePerUnit:105960571,quantity:100,description:''),
      GoldTransaction(id:'5',type:'gold_18',purchaseDate:DateTime(2025,11,10),purchasePricePerUnit:105730000,quantity:60,description:''),
      GoldTransaction(id:'6',type:'gold_18',purchaseDate:DateTime(2025,12,14),purchasePricePerUnit:138048000,quantity:15,description:''),
    ]);
    coinBox.addAll([
      CoinTransaction(id:'c1',coinType:'coin_quarter',purchaseDate:DateTime(2023,1,17),purchasePricePerUnit:70500000,count:3,description:'خرید از بورس کالای کارگزاری آگاه'),
      CoinTransaction(id:'c2',coinType:'coin_new',purchaseDate:DateTime(2025,1,1),purchasePricePerUnit:560000000,count:2,description:'خرید از زهرا'),
      CoinTransaction(id:'c3',coinType:'coin_quarter',purchaseDate:DateTime(2025,1,1),purchasePricePerUnit:174000000,count:1,description:'خرید از زهرا'),
      CoinTransaction(id:'c4',coinType:'coin_new',purchaseDate:DateTime(2025,9,8),purchasePricePerUnit:832224932,count:6,description:'خرید از مرکز مبادلات سکه و ارز'),
      CoinTransaction(id:'c5',coinType:'coin_half',purchaseDate:DateTime(2025,9,8),purchasePricePerUnit:441195425,count:10,description:'خرید از مرکز مبادلات سکه و ارز'),
      CoinTransaction(id:'c6',coinType:'coin_quarter',purchaseDate:DateTime(2025,9,8),purchasePricePerUnit:257758617,count:14,description:'خرید از مرکز مبادلات سکه و ارز'),
      CoinTransaction(id:'c7',coinType:'coin_half',purchaseDate:DateTime(2025,11,12),purchasePricePerUnit:575585000,count:1,description:'خرید از مرکز مبادلات کاربری مریم'),
      CoinTransaction(id:'c8',coinType:'coin_quarter',purchaseDate:DateTime(2025,11,12),purchasePricePerUnit:327850000,count:2,description:'خرید از مرکز مبادلات کابری مریم'),
      CoinTransaction(id:'c9',coinType:'coin_new',purchaseDate:DateTime(2026,2,15),purchasePricePerUnit:1930000000,count:4,description:'خرید از علی بابت پول ماشین'),
      CoinTransaction(id:'c10',coinType:'coin_quarter',purchaseDate:DateTime(2026,2,15),purchasePricePerUnit:525000000,count:6,description:'خرید از علی بابت پول ماشین'),
      CoinTransaction(id:'c11',coinType:'coin_half',purchaseDate:DateTime(2026,2,15),purchasePricePerUnit:970000000,count:3,description:'خرید از علی بابت پول ماشین'),
    ]);
  }

  List<GoldTransaction> get activeGold => goldBox.values.where((g) => g.remainingQuantity > 0.0001).toList();
  List<CoinTransaction> get activeCoins => coinBox.values.where((c) => c.remainingCount > 0).toList();

  Future<void> addGold(GoldTransaction t) async { await goldBox.add(t); notifyListeners(); }
  Future<void> updateGold(GoldTransaction t) async { await t.save(); notifyListeners(); }
  Future<void> deleteGold(GoldTransaction t) async {
    final salesToDelete = saleBox.values.where((s) => s.lotId == t.id && s.isGold).toList();
    for (var s in salesToDelete) await s.delete();
    await t.delete();
    notifyListeners();
  }
  Future<void> addCoin(CoinTransaction t) async { await coinBox.add(t); notifyListeners(); }
  Future<void> updateCoin(CoinTransaction t) async { await t.save(); notifyListeners(); }
  Future<void> deleteCoin(CoinTransaction t) async {
    final salesToDelete = saleBox.values.where((s) => s.lotId == t.id && !s.isGold).toList();
    for (var s in salesToDelete) await s.delete();
    await t.delete();
    notifyListeners();
  }

  Future<void> sellGold(GoldTransaction lot, double quantity, double pricePerUnit, DateTime saleDate) async {
    if (quantity <= 0 || quantity > lot.remainingQuantity) return;
    final sale = SaleTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lotId: lot.id,
      saleDate: saleDate,
      salePricePerUnit: pricePerUnit,
      quantity: quantity,
      isGold: true,
      purchasePricePerUnit: lot.purchasePricePerUnit,
      purchaseDate: lot.purchaseDate,
    );
    lot.remainingQuantity -= quantity;
    await saleBox.add(sale);
    if (lot.remainingQuantity <= 0.0001) await lot.delete();
    else await lot.save();
    notifyListeners();
  }

  Future<void> sellCoin(CoinTransaction lot, int count, double pricePerUnit, DateTime saleDate) async {
    if (count <= 0 || count > lot.remainingCount) return;
    final sale = SaleTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lotId: lot.id,
      saleDate: saleDate,
      salePricePerUnit: pricePerUnit,
      quantity: count.toDouble(),
      isGold: false,
      coinType: lot.coinType,
      purchasePricePerUnit: lot.purchasePricePerUnit,
      purchaseDate: lot.purchaseDate,
    );
    lot.remainingCount -= count;
    await saleBox.add(sale);
    if (lot.remainingCount == 0) await lot.delete();
    else await lot.save();
    notifyListeners();
  }

  double get totalRealizedProfit {
    double profit = 0;
    for (var sale in saleBox.values) {
      profit += (sale.salePricePerUnit - sale.purchasePricePerUnit) * sale.quantity;
    }
    return profit;
  }

  double getSaleProfit(SaleTransaction sale) {
    return (sale.salePricePerUnit - sale.purchasePricePerUnit) * sale.quantity;
  }

  double getRealizedProfitUntil(DateTime date) {
    double profit = 0;
    final endOfDay = date.add(const Duration(days: 1));
    for (var sale in saleBox.values) {
      if (sale.saleDate.isBefore(endOfDay)) {
        profit += (sale.salePricePerUnit - sale.purchasePricePerUnit) * sale.quantity;
      }
    }
    return profit;
  }

  double getUnrealizedProfit(Map<String, double> currentPrices, double interestRate) {
    double profit = 0;
    for (var g in activeGold) {
      final cp = currentPrices[g.type] ?? 0;
      final paid = g.purchasePricePerUnit * g.remainingQuantity;
      final days = Calculator.daysBetween(g.purchaseDate, DateTime.now());
      profit += Calculator.calculateProfit(
        currentPrice: cp,
        purchasePrice: g.purchasePricePerUnit,
        quantity: g.remainingQuantity,
        paidAmount: paid,
        interestRate: interestRate,
        days: days,
      );
    }
    for (var c in activeCoins) {
      final cp = currentPrices[c.coinType] ?? 0;
      final paid = c.purchasePricePerUnit * c.remainingCount;
      final days = Calculator.daysBetween(c.purchaseDate, DateTime.now());
      profit += Calculator.calculateProfit(
        currentPrice: cp,
        purchasePrice: c.purchasePricePerUnit,
        quantity: c.remainingCount.toDouble(),
        paidAmount: paid,
        interestRate: interestRate,
        days: days,
      );
    }
    return profit;
  }

  double getProfitFromDate(DateTime startDate, double bankRate, Map<String, double> basePrices, Map<String, double> currentPrices) {
    double currentValue = 0;
    for (var g in activeGold) {
      final cp = currentPrices[g.type] ?? 0;
      currentValue += cp * g.remainingQuantity;
    }
    for (var c in activeCoins) {
      final cp = currentPrices[c.coinType] ?? 0;
      currentValue += cp * c.remainingCount;
    }

    double totalSaleProceeds = 0;
    for (var sale in saleBox.values) {
      if (sale.saleDate.isAfter(startDate)) {
        totalSaleProceeds += sale.salePricePerUnit * sale.quantity;
      }
    }

    double totalPurchaseCostAfter = 0;
    for (var g in goldBox.values) {
      if (g.purchaseDate.isAfter(startDate)) {
        totalPurchaseCostAfter += g.purchasePricePerUnit * g.quantity;
      }
    }
    for (var c in coinBox.values) {
      if (c.purchaseDate.isAfter(startDate)) {
        totalPurchaseCostAfter += c.purchasePricePerUnit * c.count;
      }
    }

    double startValue = 0;
    for (var g in goldBox.values) {
      double qtyAtStart = g.quantity;
      for (var sale in saleBox.values) {
        if (sale.lotId == g.id && sale.isGold && sale.saleDate.isBefore(startDate)) {
          qtyAtStart -= sale.quantity;
        }
      }
      if (qtyAtStart > 0) {
        final basePrice = basePrices[g.type] ?? 0;
        startValue += basePrice * qtyAtStart;
      }
    }
    for (var c in coinBox.values) {
      int countAtStart = c.count;
      for (var sale in saleBox.values) {
        if (sale.lotId == c.id && !sale.isGold && sale.saleDate.isBefore(startDate)) {
          countAtStart -= sale.quantity.toInt();
        }
      }
      if (countAtStart > 0) {
        final basePrice = basePrices[c.coinType] ?? 0;
        startValue += basePrice * countAtStart;
      }
    }

    double bankInterest = 0;
    for (var g in goldBox.values) {
      double remaining = g.remainingQuantity;
      if (remaining > 0) {
        final paid = g.purchasePricePerUnit * remaining;
        final days = Calculator.daysBetween(g.purchaseDate, DateTime.now());
        bankInterest += paid * (pow(1 + bankRate / 100, days / 365.0) - 1);
      }
      for (var sale in saleBox.values) {
        if (sale.lotId == g.id && sale.isGold) {
          final paid = g.purchasePricePerUnit * sale.quantity;
          final days = Calculator.daysBetween(g.purchaseDate, sale.saleDate);
          bankInterest += paid * (pow(1 + bankRate / 100, days / 365.0) - 1);
        }
      }
    }
    for (var c in coinBox.values) {
      int remaining = c.remainingCount;
      if (remaining > 0) {
        final paid = c.purchasePricePerUnit * remaining;
        final days = Calculator.daysBetween(c.purchaseDate, DateTime.now());
        bankInterest += paid * (pow(1 + bankRate / 100, days / 365.0) - 1);
      }
      for (var sale in saleBox.values) {
        if (sale.lotId == c.id && !sale.isGold) {
          final paid = c.purchasePricePerUnit * sale.quantity;
          final days = Calculator.daysBetween(c.purchaseDate, sale.saleDate);
          bankInterest += paid * (pow(1 + bankRate / 100, days / 365.0) - 1);
        }
      }
    }

    double profit = (currentValue + totalSaleProceeds) - (totalPurchaseCostAfter + startValue) - bankInterest;
    return profit;
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final goldData = goldBox.values.map((g) => {
      'id': g.id,
      'type': g.type,
      'purchaseDate': g.purchaseDate.toIso8601String(),
      'purchasePricePerUnit': g.purchasePricePerUnit,
      'quantity': g.quantity,
      'description': g.description,
      'remainingQuantity': g.remainingQuantity,
    }).toList();
    final coinData = coinBox.values.map((c) => {
      'id': c.id,
      'coinType': c.coinType,
      'purchaseDate': c.purchaseDate.toIso8601String(),
      'purchasePricePerUnit': c.purchasePricePerUnit,
      'count': c.count,
      'description': c.description,
      'remainingCount': c.remainingCount,
    }).toList();
    final saleData = saleBox.values.map((s) => {
      'id': s.id,
      'lotId': s.lotId,
      'saleDate': s.saleDate.toIso8601String(),
      'salePricePerUnit': s.salePricePerUnit,
      'quantity': s.quantity,
      'isGold': s.isGold,
      'coinType': s.coinType,
      'purchasePricePerUnit': s.purchasePricePerUnit,
      'purchaseDate': s.purchaseDate.toIso8601String(),
    }).toList();
    return {
      'goldTransactions': goldData,
      'coinTransactions': coinData,
      'saleTransactions': saleData,
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    await goldBox.clear();
    await coinBox.clear();
    await saleBox.clear();

    final goldList = data['goldTransactions'] as List? ?? [];
    for (var item in goldList) {
      final g = GoldTransaction(
        id: item['id'],
        type: item['type'],
        purchaseDate: DateTime.parse(item['purchaseDate']),
        purchasePricePerUnit: (item['purchasePricePerUnit'] as num).toDouble(),
        quantity: (item['quantity'] as num).toDouble(),
        description: item['description'] ?? '',
        remainingQuantity: (item['remainingQuantity'] as num).toDouble(),
      );
      await goldBox.add(g);
    }

    final coinList = data['coinTransactions'] as List? ?? [];
    for (var item in coinList) {
      final c = CoinTransaction(
        id: item['id'],
        coinType: item['coinType'],
        purchaseDate: DateTime.parse(item['purchaseDate']),
        purchasePricePerUnit: (item['purchasePricePerUnit'] as num).toDouble(),
        count: item['count'],
        description: item['description'] ?? '',
        remainingCount: item['remainingCount'],
      );
      await coinBox.add(c);
    }

    final saleList = data['saleTransactions'] as List? ?? [];
    for (var item in saleList) {
      final s = SaleTransaction(
        id: item['id'],
        lotId: item['lotId'],
        saleDate: DateTime.parse(item['saleDate']),
        salePricePerUnit: (item['salePricePerUnit'] as num).toDouble(),
        quantity: (item['quantity'] as num).toDouble(),
        isGold: item['isGold'],
        coinType: item['coinType'],
        purchasePricePerUnit: (item['purchasePricePerUnit'] as num).toDouble(),
        purchaseDate: DateTime.parse(item['purchaseDate']),
      );
      await saleBox.add(s);
    }
    notifyListeners();
  }
}

// ======================== صفحات (بدون استفاده از Glass به جز نوار پایین) ========================

// -------------------- صفحه اصلی (HomeScreen) --------------------
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final priceProvider = Provider.of<PriceProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final basePriceProvider = Provider.of<BasePriceProvider>(context);
    final basePrices = basePriceProvider.basePrices;

    final DateTime startOf1405 = DateTime(2026, 3, 21);
    final DateTime endOf1404 = DateTime(2026, 3, 20);

    double totalGoldValue = 0, totalGoldCost = 0;
    double totalCoinValue = 0, totalCoinCost = 0;
    for (var g in dataProvider.activeGold) {
      final cp = priceProvider.prices[g.type]?.currentPrice ?? 0;
      totalGoldValue += cp * g.remainingQuantity;
      totalGoldCost += g.purchasePricePerUnit * g.remainingQuantity;
    }
    for (var c in dataProvider.activeCoins) {
      final cp = priceProvider.prices[c.coinType]?.currentPrice ?? 0;
      totalCoinValue += cp * c.remainingCount;
      totalCoinCost += c.purchasePricePerUnit * c.remainingCount;
    }

    final totalAssets = totalGoldValue + totalCoinValue;
    final realizedProfit = dataProvider.totalRealizedProfit;
    final unrealizedProfit = dataProvider.getUnrealizedProfit(
      priceProvider.prices.map((k,v) => MapEntry(k, v.currentPrice ?? 0)),
      settings.bankInterestRate,
    );

    final realized1404 = dataProvider.getRealizedProfitUntil(endOf1404);

    final profitFrom1405 = dataProvider.getProfitFromDate(
      startOf1405,
      settings.bankInterestRate,
      basePrices,
      priceProvider.prices.map((k,v) => MapEntry(k, v.currentPrice ?? 0)),
    );

    final priceEntries = priceProvider.prices.entries
        .where((e) => e.key != 'coin_1g')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('خلاصه دارایی'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.purple.shade800, Colors.deepPurple.shade900],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: priceProvider.fetchPrices,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 16),
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'آخرین به‌روزرسانی: ${priceProvider.lastUpdated.year > 2000 ? formatJalaliDate(priceProvider.lastUpdated) + ' ' + DateFormat('HH:mm').format(priceProvider.lastUpdated) : '---'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _summaryRow('ارزش کل دارایی', formatRial(totalAssets), Colors.green),
                    _summaryRow('ارزش طلای آب شده', formatRial(totalGoldValue), Colors.blue),
                    _summaryRow('ارزش سکه‌ها', formatRial(totalCoinValue), Colors.purple),
                    _summaryRow('سود محقق‌شده', formatRial(realizedProfit), realizedProfit >= 0 ? Colors.green : Colors.red),
                    _summaryRow('سود تحقق‌نیافته', formatRial(unrealizedProfit), unrealizedProfit >= 0 ? Colors.green : Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'عملکرد از ابتدای ۱۴۰۵',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      formatRial(profitFrom1405),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: profitFrom1405 >= 0 ? Colors.green : Colors.red,
                      ),
                      maxLines: 1,
                    ),
                    const Text(
                      '(با کسر هزینه فرصت بانکی)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'سود محقق‌شدهٔ پایان ۱۴۰۴',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      formatRial(realized1404),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: realized1404 >= 0 ? Colors.green : Colors.red,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'قیمت‌های لحظه‌ای (ریال)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              children: priceEntries.map((e) {
                final price = e.value.currentPrice ?? 0;
                return Card(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AutoSizeText(
                            goldTypeName(e.key),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                          ),
                          AutoSizeText(
                            formatRial(price),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          AutoSizeText(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// -------------------- صفحه گزارش فروش (ReportsScreen) --------------------
class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final saleBox = dataProvider.saleBox;

    List<Map<String, dynamic>> reportItems = [];
    for (var sale in saleBox.values) {
      String type;
      String purchaseDateStr = formatJalaliDate(sale.purchaseDate);
      String saleDateStr = formatJalaliDate(sale.saleDate);
      double purchasePrice = sale.purchasePricePerUnit;
      double salePrice = sale.salePricePerUnit;
      double quantity = sale.quantity;
      double profit = (salePrice - purchasePrice) * quantity;
      String description = '';
      if (sale.isGold) {
        final lot = dataProvider.goldBox.get(sale.lotId);
        type = 'فروش طلا';
        description = lot?.description ?? '';
      } else {
        type = 'فروش سکه ${coinName(sale.coinType ?? '')}';
        final lot = dataProvider.coinBox.get(sale.lotId);
        description = lot?.description ?? '';
      }
      reportItems.add({
        'type': type,
        'purchaseDate': purchaseDateStr,
        'saleDate': sale.saleDate,
        'saleDateStr': saleDateStr,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'salePrice': salePrice,
        'profit': profit,
        'description': description,
      });
    }

    reportItems.sort((a, b) => a['saleDate'].compareTo(b['saleDate']));
    double totalProfit = reportItems.fold(0, (sum, item) => sum + (item['profit'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش خرید و فروش'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.purple.shade800, Colors.deepPurple.shade900],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePDF(context, reportItems, totalProfit),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareReport(context, reportItems, totalProfit),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('جمع سود/زیان کل:'),
                  Text(
                    formatRial(totalProfit),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: totalProfit >= 0 ? Colors.green : Colors.red,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: reportItems.map((item) {
                final profit = item['profit'] as double;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(item['type']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تاریخ خرید: ${item['purchaseDate']}'),
                        Text('تاریخ فروش: ${item['saleDateStr']}'),
                        Text('مقدار: ${formatDoubleWithoutTrailingZeros(item['quantity'])}'),
                        Text('قیمت خرید: ${formatRial(item['purchasePrice'])}'),
                        Text('قیمت فروش: ${formatRial(item['salePrice'])}'),
                        if (item['description'].isNotEmpty)
                          Text('توضیحات: ${item['description']}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatRial(profit),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: profit >= 0 ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          profit >= 0 ? 'سود' : 'زیان',
                          style: TextStyle(fontSize: 12, color: profit >= 0 ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF(BuildContext context, List<Map<String, dynamic>> items, double totalProfit) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('گزارش خرید و فروش', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('نوع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('تاریخ خرید', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('تاریخ فروش', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('مقدار', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('سود/زیان', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...items.map((item) {
                      final profit = item['profit'] as double;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item['type'])),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item['purchaseDate'])),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item['saleDateStr'])),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(formatDoubleWithoutTrailingZeros(item['quantity']))),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(
                            formatRial(profit),
                            style: pw.TextStyle(color: profit >= 0 ? PdfColors.green : PdfColors.red),
                          )),
                        ],
                      );
                    }),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('جمع کل:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(
                          formatRial(totalProfit),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: totalProfit >= 0 ? PdfColors.green : PdfColors.red),
                        )),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'report.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ساخت PDF: $e')),
      );
    }
  }

  Future<void> _shareReport(BuildContext context, List<Map<String, dynamic>> items, double totalProfit) async {
    try {
      String report = 'گزارش خرید و فروش\n';
      report += '=' * 50 + '\n\n';
      for (var item in items) {
        report += 'نوع: ${item['type']}\n';
        report += 'تاریخ خرید: ${item['purchaseDate']}\n';
        report += 'تاریخ فروش: ${item['saleDateStr']}\n';
        report += 'مقدار: ${formatDoubleWithoutTrailingZeros(item['quantity'])}\n';
        report += 'قیمت خرید: ${formatRial(item['purchasePrice'])}\n';
        report += 'قیمت فروش: ${formatRial(item['salePrice'])}\n';
        final profit = item['profit'] as double;
        report += 'سود/زیان: ${formatRial(profit)}\n';
        if (item['description'].isNotEmpty) {
          report += 'توضیحات: ${item['description']}\n';
        }
        report += '-' * 30 + '\n';
      }
      report += '\nجمع سود/زیان کل: ${formatRial(totalProfit)}\n';
      final tempDir = await path_provider.getTemporaryDirectory();
      final file = File('${tempDir.path}/report.txt');
      await file.writeAsString(report);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        text: 'گزارش خرید و فروش',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در اشتراک‌گذاری: $e')),
      );
    }
  }
}

// -------------------- صفحه طلای آب شده (GoldListScreen) --------------------
class GoldListScreen extends StatefulWidget {
  @override
  _GoldListScreenState createState() => _GoldListScreenState();
}

class _GoldListScreenState extends State<GoldListScreen> {
  @override
  Widget build(BuildContext context) {
    final priceProvider = Provider.of<PriceProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final activeGold = dataProvider.activeGold;
    double totalWeight = activeGold.fold(0, (s, g) => s + g.remainingQuantity);
    double totalPaid = activeGold.fold(0, (s, g) => s + g.purchasePricePerUnit * g.remainingQuantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلای آب شده'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.purple.shade800, Colors.deepPurple.shade900],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditGoldDialog(context, null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('وزن کل'),
                          const SizedBox(height: 4),
                          Text(
                            '${formatDoubleWithoutTrailingZeros(totalWeight)} گرم',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('مبلغ پرداختی'),
                          const SizedBox(height: 4),
                          Text(
                            formatRial(totalPaid),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: activeGold.map((g) {
                final cp = priceProvider.prices[g.type]?.currentPrice ?? 0;
                final paid = g.purchasePricePerUnit * g.remainingQuantity;
                final currentValue = cp * g.remainingQuantity;
                final days = Calculator.daysBetween(g.purchaseDate, DateTime.now());
                final profit = Calculator.calculateProfit(
                  currentPrice: cp,
                  purchasePrice: g.purchasePricePerUnit,
                  quantity: g.remainingQuantity,
                  paidAmount: paid,
                  interestRate: settings.bankInterestRate,
                  days: days,
                );
                final sales = dataProvider.saleBox.values.where((s) => s.lotId == g.id && s.isGold).toList();
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${formatDoubleWithoutTrailingZeros(g.remainingQuantity)} گرم',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('فی خرید: ${formatRial(g.purchasePricePerUnit)}'),
                              Text('ارزش فعلی: ${formatRial(currentValue)}'),
                              Text(
                                'سود خالص: ${formatRial(profit)}',
                                style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red),
                              ),
                              if (g.description.isNotEmpty)
                                Text(g.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (sales.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('فروش‌های انجام شده:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ...sales.map((s) {
                                  final saleProfit = (s.salePricePerUnit - g.purchasePricePerUnit) * s.quantity;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${formatDoubleWithoutTrailingZeros(s.quantity)} گرم در ${formatJalaliDate(s.saleDate)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Text(
                                          formatRial(saleProfit),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: saleProfit >= 0 ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.attach_money, color: Colors.red),
                                onPressed: () => _showSellGoldDialog(context, g),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showAddEditGoldDialog(context, g),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تأیید حذف'),
                                      content: const Text('آیا از حذف این آیتم اطمینان دارید؟'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
                                        TextButton(
                                          onPressed: () {
                                            dataProvider.deleteGold(g);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditGoldDialog(BuildContext context, GoldTransaction? existing) {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = existing?.purchaseDate ?? DateTime.now();
    double price = existing?.purchasePricePerUnit ?? 0;
    double weight = existing?.quantity ?? 0;
    String desc = existing?.description ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'افزودن طلای آب شده' : 'ویرایش',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    NumberInputWithToman(
                      label: 'فی خرید (ریال)',
                      initialValue: price == 0 ? '' : formatWithSeparator(price),
                      onSaved: (v) => price = double.parse(v),
                      validator: (v) => v!.isEmpty ? 'وارد کنید' : null,
                    ),
                    TextFormField(
                      initialValue: weight == 0 ? '' : formatDoubleWithoutTrailingZeros(weight),
                      decoration: const InputDecoration(labelText: 'وزن (گرم)'),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                      validator: (v) => v!.isEmpty ? 'وارد کنید' : null,
                      onSaved: (v) => weight = double.parse(v!),
                    ),
                    ListTile(
                      title: Text('تاریخ خرید: ${formatJalaliDate(selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await pickJalaliDate(context, selectedDate);
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    TextFormField(
                      initialValue: desc,
                      decoration: const InputDecoration(labelText: 'توضیحات'),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      onSaved: (v) => desc = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('لغو'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              formKey.currentState!.save();
                              if (existing == null) {
                                Provider.of<DataProvider>(context, listen: false).addGold(GoldTransaction(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  type: 'gold_18',
                                  purchaseDate: selectedDate,
                                  purchasePricePerUnit: price,
                                  quantity: weight,
                                  description: desc,
                                ));
                              } else {
                                double sold = 0;
                                for (var sale in Provider.of<DataProvider>(context, listen: false).saleBox.values) {
                                  if (sale.lotId == existing.id && sale.isGold) {
                                    sold += sale.quantity;
                                  }
                                }
                                double newRemaining = weight - sold;
                                if (newRemaining < 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('وزن جدید کمتر از مقدار فروخته شده است!')),
                                  );
                                  return;
                                }
                                existing.purchaseDate = selectedDate;
                                existing.purchasePricePerUnit = price;
                                existing.quantity = weight;
                                existing.remainingQuantity = newRemaining;
                                existing.description = desc;
                                Provider.of<DataProvider>(context, listen: false).updateGold(existing);
                              }
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('ذخیره'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSellGoldDialog(BuildContext context, GoldTransaction lot) {
    final currentPrice = Provider.of<PriceProvider>(context, listen: false).prices[lot.type]?.currentPrice ?? 0;
    final priceCtrl = TextEditingController(
      text: currentPrice == 0 ? '' : formatWithSeparator(currentPrice)
    );
    final qtyCtrl = TextEditingController(text: formatDoubleWithoutTrailingZeros(lot.remainingQuantity));
    DateTime saleDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'فروش طلا',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('موجودی: ${formatDoubleWithoutTrailingZeros(lot.remainingQuantity)} گرم'),
                  TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'مقدار فروش (گرم)'),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                  ),
                  NumberInputWithToman(
                    label: 'قیمت فروش هر گرم (ریال)',
                    initialValue: priceCtrl.text,
                    onSaved: (v) => priceCtrl.text = v,
                    isPrice: true,
                  ),
                  ListTile(
                    title: Text('تاریخ فروش: ${formatJalaliDate(saleDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await pickJalaliDate(context, saleDate);
                      if (picked != null) {
                        setState(() {
                          saleDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('لغو'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final q = double.tryParse(qtyCtrl.text) ?? 0;
                          final p = double.tryParse(priceCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                          if (q > 0 && q <= lot.remainingQuantity && p > 0) {
                            Provider.of<DataProvider>(context, listen: false).sellGold(lot, q, p, saleDate);
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('مقدار یا قیمت نامعتبر است')),
                            );
                          }
                        },
                        child: const Text('فروش'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// -------------------- صفحه سکه‌ها (CoinListScreen) --------------------
class CoinListScreen extends StatefulWidget {
  @override
  _CoinListScreenState createState() => _CoinListScreenState();
}

class _CoinListScreenState extends State<CoinListScreen> {
  @override
  Widget build(BuildContext context) {
    final priceProvider = Provider.of<PriceProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final activeCoins = dataProvider.activeCoins;
    int totalCoins = activeCoins.fold(0, (s, c) => s + c.remainingCount);
    int rub = activeCoins.where((c) => c.coinType == 'coin_quarter').fold(0, (s, c) => s + c.remainingCount);
    int nim = activeCoins.where((c) => c.coinType == 'coin_half').fold(0, (s, c) => s + c.remainingCount);
    int tamam = activeCoins.where((c) => c.coinType == 'coin_new' || c.coinType == 'coin_old').fold(0, (s, c) => s + c.remainingCount);
    double totalPaid = activeCoins.fold(0, (s, c) => s + c.purchasePricePerUnit * c.remainingCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سکه‌ها'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.purple.shade800, Colors.deepPurple.shade900],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditCoinDialog(context, null),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn('ربع', rub.toString()),
                      _statColumn('نیم', nim.toString()),
                      _statColumn('تمام', tamam.toString()),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('تعداد کل: '),
                      Text(totalCoins.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ListTile(
              title: const Text('مجموع مبلغ پرداختی سکه‌ها'),
              trailing: Text(formatRial(totalPaid), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: activeCoins.map((c) {
                final cp = priceProvider.prices[c.coinType]?.currentPrice ?? 0;
                final paid = c.purchasePricePerUnit * c.remainingCount;
                final currentValue = cp * c.remainingCount;
                final days = Calculator.daysBetween(c.purchaseDate, DateTime.now());
                final profit = Calculator.calculateProfit(
                  currentPrice: cp,
                  purchasePrice: c.purchasePricePerUnit,
                  quantity: c.remainingCount.toDouble(),
                  paidAmount: paid,
                  interestRate: settings.bankInterestRate,
                  days: days,
                );
                final sales = dataProvider.saleBox.values.where((s) => s.lotId == c.id && !s.isGold).toList();
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${c.remainingCount} ${coinName(c.coinType)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('فی خرید: ${formatRial(c.purchasePricePerUnit)}'),
                              Text('ارزش فعلی: ${formatRial(currentValue)}'),
                              Text(
                                'سود خالص: ${formatRial(profit)}',
                                style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red),
                              ),
                              if (c.description.isNotEmpty)
                                Text(c.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (sales.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('فروش‌های انجام شده:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ...sales.map((s) {
                                  final saleProfit = (s.salePricePerUnit - c.purchasePricePerUnit) * s.quantity;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${s.quantity.toInt()} عدد در ${formatJalaliDate(s.saleDate)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Text(
                                          formatRial(saleProfit),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: saleProfit >= 0 ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.attach_money, color: Colors.red),
                                onPressed: () => _showSellCoinDialog(context, c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showAddEditCoinDialog(context, c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تأیید حذف'),
                                      content: const Text('آیا از حذف این آیتم اطمینان دارید؟'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
                                        TextButton(
                                          onPressed: () {
                                            dataProvider.deleteCoin(c);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showAddEditCoinDialog(BuildContext context, CoinTransaction? existing) {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = existing?.purchaseDate ?? DateTime.now();
    double price = existing?.purchasePricePerUnit ?? 0;
    int count = existing?.count ?? 1;
    String desc = existing?.description ?? '';
    String coinType = existing?.coinType ?? 'coin_new';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'افزودن سکه' : 'ویرایش',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: coinType,
                      items: const [
                        DropdownMenuItem(value: 'coin_new', child: Text('تمام (امامی)')),
                        DropdownMenuItem(value: 'coin_old', child: Text('تمام (قدیم)')),
                        DropdownMenuItem(value: 'coin_half', child: Text('نیم سکه')),
                        DropdownMenuItem(value: 'coin_quarter', child: Text('ربع سکه')),
                        DropdownMenuItem(value: 'coin_1g', child: Text('سکه یک گرمی')),
                      ],
                      onChanged: (v) => coinType = v!,
                      decoration: const InputDecoration(labelText: 'نوع سکه'),
                    ),
                    NumberInputWithToman(
                      label: 'فی خرید (ریال)',
                      initialValue: price == 0 ? '' : formatWithSeparator(price),
                      onSaved: (v) => price = double.parse(v),
                      validator: (v) => v!.isEmpty ? 'وارد کنید' : null,
                    ),
                    TextFormField(
                      initialValue: count == 0 ? '' : count.toString(),
                      decoration: const InputDecoration(labelText: 'تعداد'),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                      validator: (v) => v!.isEmpty ? 'وارد کنید' : null,
                      onSaved: (v) => count = int.parse(v!),
                    ),
                    ListTile(
                      title: Text('تاریخ خرید: ${formatJalaliDate(selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await pickJalaliDate(context, selectedDate);
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    TextFormField(
                      initialValue: desc,
                      decoration: const InputDecoration(labelText: 'توضیحات'),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      onSaved: (v) => desc = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('لغو'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              formKey.currentState!.save();
                              if (existing == null) {
                                Provider.of<DataProvider>(context, listen: false).addCoin(CoinTransaction(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  coinType: coinType,
                                  purchaseDate: selectedDate,
                                  purchasePricePerUnit: price,
                                  count: count,
                                  description: desc,
                                ));
                              } else {
                                int sold = 0;
                                for (var sale in Provider.of<DataProvider>(context, listen: false).saleBox.values) {
                                  if (sale.lotId == existing.id && !sale.isGold) {
                                    sold += sale.quantity.toInt();
                                  }
                                }
                                int newRemaining = count - sold;
                                if (newRemaining < 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تعداد جدید کمتر از تعداد فروخته شده است!')),
                                  );
                                  return;
                                }
                                existing.coinType = coinType;
                                existing.purchaseDate = selectedDate;
                                existing.purchasePricePerUnit = price;
                                existing.count = count;
                                existing.remainingCount = newRemaining;
                                existing.description = desc;
                                Provider.of<DataProvider>(context, listen: false).updateCoin(existing);
                              }
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('ذخیره'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSellCoinDialog(BuildContext context, CoinTransaction lot) {
    final currentPrice = Provider.of<PriceProvider>(context, listen: false).prices[lot.coinType]?.currentPrice ?? 0;
    final priceCtrl = TextEditingController(
      text: currentPrice == 0 ? '' : formatWithSeparator(currentPrice)
    );
    final cntCtrl = TextEditingController(text: lot.remainingCount.toString());
    DateTime saleDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'فروش سکه',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('موجودی: ${lot.remainingCount} عدد'),
                  TextField(
                    controller: cntCtrl,
                    decoration: const InputDecoration(labelText: 'تعداد فروش'),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                  ),
                  NumberInputWithToman(
                    label: 'قیمت فروش هر عدد (ریال)',
                    initialValue: priceCtrl.text,
                    onSaved: (v) => priceCtrl.text = v,
                    isPrice: true,
                  ),
                  ListTile(
                    title: Text('تاریخ فروش: ${formatJalaliDate(saleDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await pickJalaliDate(context, saleDate);
                      if (picked != null) {
                        setState(() {
                          saleDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('لغو'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final n = int.tryParse(cntCtrl.text) ?? 0;
                          final p = double.tryParse(priceCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                          if (n > 0 && n <= lot.remainingCount && p > 0) {
                            Provider.of<DataProvider>(context, listen: false).sellCoin(lot, n, p, saleDate);
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('مقدار یا قیمت نامعتبر است')),
                            );
                          }
                        },
                        child: const Text('فروش'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// -------------------- صفحه نمودارها (ChartsScreen) --------------------
class ChartsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final priceProvider = Provider.of<PriceProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final activeGold = dataProvider.activeGold;
    final activeCoins = dataProvider.activeCoins;

    double goldValue = activeGold.fold(0, (s, g) => s + (priceProvider.prices[g.type]?.currentPrice ?? 0) * g.remainingQuantity);
    Map<String, double> coinTypeValues = {};
    for (var c in activeCoins) {
      final v = (priceProvider.prices[c.coinType]?.currentPrice ?? 0) * c.remainingCount;
      coinTypeValues.update(c.coinType, (old) => old + v, ifAbsent: () => v);
    }
    final total = goldValue + coinTypeValues.values.fold(0.0, (a, b) => a + b);

    List<PieChartSectionData> sections = [];
    if (goldValue > 0) {
      sections.add(PieChartSectionData(
        value: goldValue,
        title: 'طلای آب شده\n${(goldValue/total*100).toStringAsFixed(1)}%',
        color: Colors.blue,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      ));
    }
    for (var e in coinTypeValues.entries) {
      if (e.value > 0) {
        sections.add(PieChartSectionData(
          value: e.value,
          title: '${coinName(e.key)}\n${(e.value/total*100).toStringAsFixed(1)}%',
          color: _coinColor(e.key),
          radius: 50,
          titleStyle: const TextStyle(fontSize: 9, color: Colors.white),
        ));
      }
    }

    List<BarChartGroupData> bars = [];
    int x = 0;
    for (var g in activeGold) {
      final cp = priceProvider.prices[g.type]?.currentPrice ?? 0;
      final paid = g.purchasePricePerUnit * g.remainingQuantity;
      final days = Calculator.daysBetween(g.purchaseDate, DateTime.now());
      final profit = Calculator.calculateProfit(
        currentPrice: cp,
        purchasePrice: g.purchasePricePerUnit,
        quantity: g.remainingQuantity,
        paidAmount: paid,
        interestRate: settings.bankInterestRate,
        days: days,
      );
      bars.add(BarChartGroupData(x: x++, barRods: [BarChartRodData(toY: profit, color: profit>=0?Colors.green:Colors.red, width: 10)]));
    }
    for (var c in activeCoins) {
      final cp = priceProvider.prices[c.coinType]?.currentPrice ?? 0;
      final paid = c.purchasePricePerUnit * c.remainingCount;
      final days = Calculator.daysBetween(c.purchaseDate, DateTime.now());
      final profit = Calculator.calculateProfit(
        currentPrice: cp,
        purchasePrice: c.purchasePricePerUnit,
        quantity: c.remainingCount.toDouble(),
        paidAmount: paid,
        interestRate: settings.bankInterestRate,
        days: days,
      );
      bars.add(BarChartGroupData(x: x++, barRods: [BarChartRodData(toY: profit, color: profit>=0?Colors.green:Colors.red, width: 10)]));
    }

    List<_Event> events = [];
    for (var g in dataProvider.goldBox.values) {
      events.add(_Event(g.purchaseDate, g.purchasePricePerUnit * g.quantity));
    }
    for (var c in dataProvider.coinBox.values) {
      events.add(_Event(c.purchaseDate, c.purchasePricePerUnit * c.count));
    }
    for (var s in dataProvider.saleBox.values) {
      events.add(_Event(s.saleDate, -s.salePricePerUnit * s.quantity));
    }
    events.sort((a,b) => a.date.compareTo(b.date));

    List<FlSpot> netInvestmentSpots = [];
    double cumulativeCost = 0;
    for (var e in events) {
      cumulativeCost += e.amount;
      netInvestmentSpots.add(FlSpot(e.date.millisecondsSinceEpoch.toDouble(), cumulativeCost));
    }
    double currentNetInvestment = 0;
    for (var g in dataProvider.activeGold) {
      currentNetInvestment += g.purchasePricePerUnit * g.remainingQuantity;
    }
    for (var c in dataProvider.activeCoins) {
      currentNetInvestment += c.purchasePricePerUnit * c.remainingCount;
    }
    netInvestmentSpots.add(FlSpot(DateTime.now().millisecondsSinceEpoch.toDouble(), currentNetInvestment));

    return Scaffold(
      appBar: AppBar(
        title: const Text('نمودارها'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.purple.shade800, Colors.deepPurple.shade900],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 16),
        children: [
          Text('توزیع دارایی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(height: 250, child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 40))),
          ),
          const SizedBox(height: 20),
          Text('سود/زیان هر لات', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  barGroups: bars,
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('روند سرمایه‌گذاری (هزینه خالص تجمعی)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: netInvestmentSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                          return AutoSizeText(formatJalaliDate(dt).substring(5), style: const TextStyle(fontSize: 10));
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return AutoSizeText(formatRial(value), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Color _coinColor(String type) {
    switch (type) {
      case 'coin_quarter': return Colors.amber;
      case 'coin_half': return Colors.green;
      case 'coin_new':
      case 'coin_old': return Colors.purple;
      case 'coin_1g': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class _Event {
  final DateTime date;
  final double amount;
  _Event(this.date, this.amount);
}

// -------------------- صفحه تنظیمات (SettingsScreen) --------------------
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final priceProvider = Provider.of<PriceProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final basePriceProvider = Provider.of<BasePriceProvider>(context);
    final basePrices = basePriceProvider.basePrices;
    final secondaryColor = settings.secondaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.purple.shade800, Colors.deepPurple.shade900],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('نرخ سود بانکی'),
                  Slider(
                    value: settings.bankInterestRate,
                    min: 0,
                    max: 50,
                    divisions: 100,
                    label: settings.bankInterestRate.toStringAsFixed(1) + '%',
                    onChanged: (v) => settings.setBankInterestRate(v),
                  ),
                  Text('${settings.bankInterestRate.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('فاصله به‌روزرسانی خودکار (ثانیه)'),
                  Slider(
                    value: settings.autoUpdateInterval.toDouble(),
                    min: 30,
                    max: 600,
                    divisions: (600 - 30) ~/ 10,
                    label: settings.autoUpdateInterval.toString(),
                    onChanged: (v) {
                      settings.setAutoUpdateInterval(v.toInt());
                      priceProvider.setAutoUpdateInterval(v.toInt());
                    },
                  ),
                  Text('${settings.autoUpdateInterval} ثانیه'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('به‌روزرسانی دستی قیمت‌ها'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: priceProvider.fetchPrices,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('رنگ ثانویه'),
              trailing: CircleAvatar(backgroundColor: secondaryColor, radius: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('انتخاب رنگ ثانویه'),
                    content: ColorPicker(
                      pickerColor: secondaryColor,
                      onColorChanged: (color) {
                        settings.setSecondaryColor(color);
                      },
                      colorPickerWidth: 300,
                      pickerAreaHeightPercent: 0.7,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('بستن'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('قیمت‌های پایه (۱/۱/۱۴۰۵)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...basePrices.keys.map((key) {
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(goldTypeName(key)),
                trailing: SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: basePrices[key] == 0 ? '' : basePrices[key].toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      hintText: 'ریال',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onFieldSubmitted: (value) {
                      final val = double.tryParse(value) ?? 0;
                      basePriceProvider.setBasePrice(key, val);
                    },
                  ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
          Text('مدیریت داده‌ها', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.green),
                  title: const Text('Export (خروجی گرفتن)'),
                  subtitle: const Text('ذخیره تمام داده‌ها در یک فایل JSON'),
                  trailing: _isExporting
                      ? const SizedBox(width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_forward),
                  onTap: _isExporting ? null : () => _exportData(context, dataProvider),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blue),
                  title: const Text('Import (وارد کردن)'),
                  subtitle: const Text('بازیابی داده‌ها از فایل JSON'),
                  trailing: _isImporting
                      ? const SizedBox(width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_forward),
                  onTap: _isImporting ? null : () => _importData(context, dataProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              title: const Text('نسخه ۲.۰.۰'),
              subtitle: const Text('ساخته شده توسط امیر - بنیانگذار نخودگرام'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, DataProvider dataProvider) async {
    setState(() => _isExporting = true);
    try {
      final data = await dataProvider.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final tempDir = await path_provider.getTemporaryDirectory();
      final file = File('${tempDir.path}/gold_coin_backup.json');
      await file.writeAsString(jsonString);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'فایل پشتیبان مدیریت طلا و سکه',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در خروجی گرفتن: $e')),
      );
    }
    setState(() => _isExporting = false);
  }

  Future<void> _importData(BuildContext context, DataProvider dataProvider) async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) {
        setState(() => _isImporting = false);
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('هشدار!'),
          content: const Text('آیا از جایگزینی تمام داده‌های فعلی با داده‌های فایل وارد شده اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأیید', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) {
        setState(() => _isImporting = false);
        return;
      }

      await dataProvider.importData(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('داده‌ها با موفقیت بازیابی شدند')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در وارد کردن: $e')),
      );
    }
    setState(() => _isImporting = false);
  }
}

// -------------------- Main --------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تنظیم شفافیت نوار ناوبری سیستم اندروید
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await initializeDateFormatting('fa', null);

  // ✅ مقداردهی اولیه Liquid Glass Widgets (برای نوار پایین)
  await LiquidGlassWidgets.initialize();

  final appDocDir = await path_provider.getApplicationDocumentsDirectory();
  Hive.init(appDocDir.path);
  Hive.registerAdapter(GoldTransactionAdapter());
  Hive.registerAdapter(CoinTransactionAdapter());
  Hive.registerAdapter(SaleTransactionAdapter());

  final goldBox = await Hive.openBox<GoldTransaction>('goldTransactions');
  final coinBox = await Hive.openBox<CoinTransaction>('coinTransactions');
  final saleBox = await Hive.openBox<SaleTransaction>('saleTransactions');
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PriceProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => BasePriceProvider(prefs)),
        ChangeNotifierProvider(create: (_) => DataProvider(goldBox: goldBox, coinBox: coinBox, saleBox: saleBox)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'مدیریت دارایی طلا و سکه',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: settings.secondaryColor,
              ),
              fontFamily: 'Vazir',
            ),
            home: const MainScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    ),
  );
}

// -------------------- صفحه اصلی با Navigation Bar شیشه‌ای (فقط نوار پایین) --------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    HomeScreen(),
    GoldListScreen(),
    CoinListScreen(),
    ChartsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: GlassTabBar.bottom(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) => setState(() => _selectedIndex = index),
        tabs: const [
          GlassTab(icon: Icon(Icons.home), label: 'خانه'),
          GlassTab(icon: Icon(Icons.monetization_on), label: 'طلا'),
          GlassTab(icon: Icon(Icons.account_balance_wallet), label: 'سکه'),
          GlassTab(icon: Icon(Icons.bar_chart), label: 'نمودار'),
          GlassTab(icon: Icon(Icons.settings), label: 'تنظیمات'),
        ],
      ),
    );
  }
}