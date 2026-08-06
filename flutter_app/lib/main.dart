import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:fl_chart/fl_chart.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'logic.dart';
import 'handler.dart';

// -------------------- Helpers --------------------
double _dailyBankProfit({
  required double paidAmount,
  required double interestRate,
  required int days,
}) {
  if (days <= 0 || paidAmount <= 0) return 0;

  final dailyRate = interestRate / 100 / 365;
  return (paidAmount * (math.pow(1 + dailyRate, days) - 1)).toDouble();
}

double _dailyProfit({
  required double currentPrice,
  required double quantity,
  required double paidAmount,
  required double interestRate,
  required int days,
}) {
  final currentValue = currentPrice * quantity;
  final purchaseProfit = currentValue - paidAmount;

  final bankProfit = _dailyBankProfit(
    paidAmount: paidAmount,
    interestRate: interestRate,
    days: days,
  );

  return purchaseProfit - bankProfit;
}

String _convertPersianDigitsToEnglish(String input) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';

  String result = input;

  for (int i = 0; i < 10; i++) {
    result = result
        .replaceAll(persian[i], i.toString())
        .replaceAll(arabic[i], i.toString());
  }

  return result;
}

String _formatRial(double amount) {
  final formatted = NumberFormat('#,###').format(amount);
  return formatted.toPersianDigit();
}

String _formatNumber(dynamic value) {
  final double v = value is num
      ? value.toDouble()
      : double.tryParse(value.toString()) ?? 0;

  final formatted = NumberFormat('#,###.###').format(v);
  return formatted.toPersianDigit();
}

String _formatWithSeparator(double value) {
  if (value == 0) return '';
  return NumberFormat('#,###').format(value);
}

String _editableDouble(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  String str = value.toString();
  if (str.contains('.')) {
    str = str.replaceAll(RegExp(r'0*$'), '');
    if (str.endsWith('.')) str = str.substring(0, str.length - 1);
  }

  return str;
}

String _formatJalali(DateTime dt) {
  final j = Jalali.fromDateTime(dt);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}'
      .toPersianDigit();
}

String _formatTime(DateTime dt) {
  return DateFormat('HH:mm').format(dt).toPersianDigit();
}

String _coinName(String t) {
  switch (t) {
    case 'coin_new':
      return 'سکه تمام (امامی)';
    case 'coin_old':
      return 'سکه تمام (قدیم)';
    case 'coin_half':
      return 'نیم سکه';
    case 'coin_quarter':
      return 'ربع سکه';
    case 'coin_1g':
      return 'سکه یک گرمی';
    default:
      return t;
  }
}

String _goldTypeName(String k) {
  switch (k) {
    case 'gold_18':
      return 'طلای ۱۸ عیار';
    case 'gold_24':
      return 'طلای ۲۴ عیار';
    case 'gold_ons':
      return 'انس طلا';
    case 'gold_mazneh':
      return 'مظنه تهران';
    case 'coin_old':
      return 'سکه قدیم';
    case 'coin_new':
      return 'سکه جدید';
    case 'coin_half':
      return 'نیم سکه';
    case 'coin_quarter':
      return 'ربع سکه';
    case 'coin_1g':
      return 'سکه یک گرمی';
    default:
      return k;
  }
}

String _shortAssetName(String key) {
  switch (key) {
    case 'gold_18':
      return 'طلا';
    case 'gold_24':
      return '۲۴';
    case 'gold_ons':
      return 'انس';
    case 'gold_mazneh':
      return 'مظنه';
    case 'coin_old':
      return 'قدیم';
    case 'coin_new':
      return 'تمام';
    case 'coin_half':
      return 'نیم';
    case 'coin_quarter':
      return 'ربع';
    case 'coin_1g':
      return '۱گ';
    default:
      return key;
  }
}

String _formatCompact(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();

  String text;

  if (abs >= 1000000000) {
    text = '$sign${(abs / 1000000000).toStringAsFixed(1)} میلیارد';
  } else if (abs >= 1000000) {
    text = '$sign${(abs / 1000000).toStringAsFixed(0)} میلیون';
  } else if (abs >= 1000) {
    text = '$sign${(abs / 1000).toStringAsFixed(0)} هزار';
  } else {
    text = '$sign${abs.toStringAsFixed(0)}';
  }

  return text.toPersianDigit();
}

Color _coinColor(String type) {
  switch (type) {
    case 'coin_quarter':
      return Colors.amber;
    case 'coin_half':
      return Colors.green;
    case 'coin_new':
    case 'coin_old':
      return Colors.purple;
    case 'coin_1g':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

Widget _legendDot(BuildContext context, Color color, String label) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _SeparatedNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final converted = _convertPersianDigitsToEnglish(newValue.text);
    final clean = converted.replaceAll(RegExp(r'[^\d]'), '');

    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final intValue = int.tryParse(clean);
    if (intValue == null) return newValue;

    final formatted = NumberFormat('#,###').format(intValue);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// -------------------- HomeScreen --------------------
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
    final DateTime today = DateTime.now();

    final currentPrices = priceProvider.prices.map(
      (k, v) => MapEntry(k, v.currentPrice ?? 0),
    );

    double totalGoldValue = 0;
    double totalCoinValue = 0;
    double unrealizedProfit = 0;

    for (var g in dataProvider.activeGold) {
      final rawPrice = priceProvider.prices[g.type]?.currentPrice ?? 0;
      final cp = rawPrice > 0 ? rawPrice : g.purchasePricePerUnit;

      final paid = g.purchasePricePerUnit * g.remainingQuantity;
      final days = Calculator.daysBetween(g.purchaseDate, today);

      totalGoldValue += cp * g.remainingQuantity;

      unrealizedProfit += _dailyProfit(
        currentPrice: cp,
        quantity: g.remainingQuantity,
        paidAmount: paid,
        interestRate: settings.bankInterestRate,
        days: days,
      );
    }

    for (var c in dataProvider.activeCoins) {
      final rawPrice = priceProvider.prices[c.coinType]?.currentPrice ?? 0;
      final cp = rawPrice > 0 ? rawPrice : c.purchasePricePerUnit;

      final paid = c.purchasePricePerUnit * c.remainingCount;
      final days = Calculator.daysBetween(c.purchaseDate, today);

      totalCoinValue += cp * c.remainingCount;

      unrealizedProfit += _dailyProfit(
        currentPrice: cp,
        quantity: c.remainingCount.toDouble(),
        paidAmount: paid,
        interestRate: settings.bankInterestRate,
        days: days,
      );
    }

    final totalAssets = totalGoldValue + totalCoinValue;
    final realizedProfit = dataProvider.totalRealizedProfit;

    // ------------------------------------------------------------
    // سود محقق‌شده پایان ۱۴۰۴
    // ------------------------------------------------------------
    double realized1404 = 0;

    for (var g in dataProvider.goldBox.values) {
      if (g.purchaseDate.isAfter(endOf1404)) continue;

      final endPrice = basePrices[g.type] ?? 0;
      final paidAmount = g.purchasePricePerUnit * g.quantity;
      final days = Calculator.daysBetween(g.purchaseDate, endOf1404);
      final currentValue = endPrice * g.quantity;

      final bankProfit = _dailyBankProfit(
        paidAmount: paidAmount,
        interestRate: settings.bankInterestRate,
        days: days,
      );

      realized1404 += (currentValue - paidAmount) - bankProfit;
    }

    for (var c in dataProvider.coinBox.values) {
      if (c.purchaseDate.isAfter(endOf1404)) continue;

      final endPrice = basePrices[c.coinType] ?? 0;
      final paidAmount = c.purchasePricePerUnit * c.count;
      final days = Calculator.daysBetween(c.purchaseDate, endOf1404);
      final currentValue = endPrice * c.count;

      final bankProfit = _dailyBankProfit(
        paidAmount: paidAmount,
        interestRate: settings.bankInterestRate,
        days: days,
      );

      realized1404 += (currentValue - paidAmount) - bankProfit;
    }

    // ------------------------------------------------------------
    // عملکرد از ابتدای ۱۴۰۵
    // ------------------------------------------------------------
    double performanceGold = 0;
    double performanceCoin = 0;

    double startAssetGold1405 = 0;
    double startAssetCoin1405 = 0;

    double bankCost1405 = 0;

    for (var g in dataProvider.activeGold) {
      final basePrice = basePrices[g.type] ?? 0;
      final currentPriceRaw = currentPrices[g.type] ?? 0;
      final qty = g.remainingQuantity;

      if (g.purchaseDate.isBefore(startOf1405)) {
        final currentPrice = currentPriceRaw > 0 ? currentPriceRaw : basePrice;

        performanceGold += (currentPrice - basePrice) * qty;
        startAssetGold1405 += basePrice * qty;
      } else {
        final paidAmount = g.purchasePricePerUnit * qty;
        final currentValue =
            currentPriceRaw > 0 ? currentPriceRaw * qty : paidAmount;

        performanceGold += currentValue - paidAmount;

        bankCost1405 += _dailyBankProfit(
          paidAmount: paidAmount,
          interestRate: settings.bankInterestRate,
          days: Calculator.daysBetween(g.purchaseDate, today),
        );
      }
    }

    for (var c in dataProvider.activeCoins) {
      final basePrice = basePrices[c.coinType] ?? 0;
      final currentPriceRaw = currentPrices[c.coinType] ?? 0;
      final count = c.remainingCount;

      if (c.purchaseDate.isBefore(startOf1405)) {
        final currentPrice = currentPriceRaw > 0 ? currentPriceRaw : basePrice;

        performanceCoin += (currentPrice - basePrice) * count;
        startAssetCoin1405 += basePrice * count;
      } else {
        final paidAmount = c.purchasePricePerUnit * count;
        final currentValue =
            currentPriceRaw > 0 ? currentPriceRaw * count : paidAmount;

        performanceCoin += currentValue - paidAmount;

        bankCost1405 += _dailyBankProfit(
          paidAmount: paidAmount,
          interestRate: settings.bankInterestRate,
          days: Calculator.daysBetween(c.purchaseDate, today),
        );
      }
    }

    final totalStartAsset1405 = startAssetGold1405 + startAssetCoin1405;

    bankCost1405 += _dailyBankProfit(
      paidAmount: totalStartAsset1405,
      interestRate: settings.bankInterestRate,
      days: Calculator.daysBetween(endOf1404, today),
    );

    final totalPerformanceBeforeBank1405 = performanceGold + performanceCoin;
    final profitFrom1405 = totalPerformanceBeforeBank1405 - bankCost1405;

    final priceEntries = priceProvider.prices.entries
        .where((e) => e.key != 'coin_1g')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('خلاصه دارایی'),
      ),
      body: RefreshIndicator(
        onRefresh: priceProvider.fetchPrices,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'آخرین به‌روزرسانی: ${priceProvider.lastUpdated.year > 2000 ? '${_formatJalali(priceProvider.lastUpdated)} - ${_formatTime(priceProvider.lastUpdated)}' : '---'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _summaryRow('ارزش کل دارایی', _formatRial(totalAssets), Colors.green),
                    _summaryRow('ارزش طلای آب شده', _formatRial(totalGoldValue), Colors.blue),
                    _summaryRow('ارزش سکه‌ها', _formatRial(totalCoinValue), Colors.purple),
                    _summaryRow('سود محقق‌شده', _formatRial(realizedProfit), realizedProfit >= 0 ? Colors.green : Colors.red),
                    _summaryRow('سود تحقق‌نیافته', _formatRial(unrealizedProfit), unrealizedProfit >= 0 ? Colors.green : Colors.red),
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
                    const Text('عملکرد از ابتدای ۱۴۰۵', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      _formatRial(profitFrom1405),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: profitFrom1405 >= 0 ? Colors.green : Colors.red,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Text('عملکرد طلا: ${_formatRial(performanceGold)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text('عملکرد سکه: ${_formatRial(performanceCoin)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text('دارایی ابتدای سال: ${_formatRial(totalStartAsset1405)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text('هزینه فرصت بانکی: ${_formatRial(bankCost1405)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const Text('(با کسر هزینه فرصت بانکی روزشمار)', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                    const Text('سود محقق‌شدهٔ پایان ۱۴۰۴', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      _formatRial(realized1404),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: realized1404 >= 0 ? Colors.green : Colors.red,
                      ),
                      maxLines: 1,
                    ),
                    const Text('(بر اساس قیمت پایه و سود روزشمار تا پایان ۱۴۰۴)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('قیمت‌های لحظه‌ای (ریال)', style: Theme.of(context).textTheme.titleMedium),
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
                          AutoSizeText(_goldTypeName(e.key), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                          AutoSizeText(_formatRial(price), maxLines: 1),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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

// -------------------- ReportsScreen --------------------
class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final saleBox = dataProvider.saleBox;

    List<Map<String, dynamic>> reportItems = [];

    for (var sale in saleBox.values) {
      String type;
      String purchaseDateStr = _formatJalali(sale.purchaseDate);
      String saleDateStr = _formatJalali(sale.saleDate);
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
        type = 'فروش سکه ${_coinName(sale.coinType ?? '')}';
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

    reportItems.sort((a, b) => (a['saleDate'] as DateTime).compareTo(b['saleDate'] as DateTime));
    double totalProfit = reportItems.fold(0, (sum, item) => sum + (item['profit'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش خرید و فروش'),
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
                    _formatRial(totalProfit),
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
                final description = item['description'] as String;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(item['type'] as String),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تاریخ خرید: ${item['purchaseDate']}'),
                        Text('تاریخ فروش: ${item['saleDateStr']}'),
                        Text('مقدار: ${_formatNumber(item['quantity'] as double)}'),
                        Text('قیمت خرید: ${_formatRial(item['purchasePrice'] as double)}'),
                        Text('قیمت فروش: ${_formatRial(item['salePrice'] as double)}'),
                        if (description.isNotEmpty) Text('توضیحات: $description'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatRial(profit),
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
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item['type'] as String)),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item['purchaseDate'] as String)),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item['saleDateStr'] as String)),
                          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(_formatNumber(item['quantity'] as double))),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text(
                              _formatRial(profit),
                              style: pw.TextStyle(color: profit >= 0 ? PdfColors.green : PdfColors.red),
                            ),
                          ),
                        ],
                      );
                    }),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در ساخت PDF: $e')));
    }
  }

  Future<void> _shareReport(BuildContext context, List<Map<String, dynamic>> items, double totalProfit) async {
    try {
      String report = 'گزارش خرید و فروش\n';
      report += '=' * 50 + '\n\n';

      for (var item in items) {
        final description = item['description'] as String;
        final profit = item['profit'] as double;

        report += 'نوع: ${item['type']}\n';
        report += 'تاریخ خرید: ${item['purchaseDate']}\n';
        report += 'تاریخ فروش: ${item['saleDateStr']}\n';
        report += 'مقدار: ${_formatNumber(item['quantity'] as double)}\n';
        report += 'قیمت خرید: ${_formatRial(item['purchasePrice'] as double)}\n';
        report += 'قیمت فروش: ${_formatRial(item['salePrice'] as double)}\n';
        report += 'سود/زیان: ${_formatRial(profit)}\n';

        if (description.isNotEmpty) {
          report += 'توضیحات: $description\n';
        }

        report += '-' * 30 + '\n';
      }

      report += '\nجمع سود/زیان کل: ${_formatRial(totalProfit)}\n';

      final tempDir = await path_provider.getTemporaryDirectory();
      final file = File('${tempDir.path}/report.txt');
      await file.writeAsString(report);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        text: 'گزارش خرید و فروش',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در اشتراک‌گذاری: $e')));
    }
  }
}

// -------------------- GoldListScreen --------------------
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
                            '${_formatNumber(totalWeight)} گرم',
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
                          Text(_formatRial(totalPaid), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                final rawPrice = priceProvider.prices[g.type]?.currentPrice ?? 0;
                final cp = rawPrice > 0 ? rawPrice : g.purchasePricePerUnit;

                final paid = g.purchasePricePerUnit * g.remainingQuantity;
                final currentValue = cp * g.remainingQuantity;
                final days = Calculator.daysBetween(g.purchaseDate, DateTime.now());

                final profit = _dailyProfit(
                  currentPrice: cp,
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
                            '${_formatNumber(g.remainingQuantity)} گرم',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تاریخ خرید: ${_formatJalali(g.purchaseDate)}'),
                              Text('فی خرید: ${_formatRial(g.purchasePricePerUnit)}'),
                              Text('ارزش فعلی: ${_formatRial(currentValue)}'),
                              Text(
                                'سود خالص: ${_formatRial(profit)}',
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
                                            '${_formatNumber(s.quantity)} گرم در ${_formatJalali(s.saleDate)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Text(
                                          _formatRial(saleProfit),
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                          initialValue: price == 0 ? '' : _formatWithSeparator(price),
                          onSaved: (v) => price = double.parse(v),
                          validator: (v) => v!.isEmpty ? 'وارد کنید' : null,
                        ),
                        TextFormField(
                          initialValue: weight == 0 ? '' : _editableDouble(weight),
                          decoration: const InputDecoration(labelText: 'وزن (گرم)'),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.left,
                          textDirection: TextDirection.ltr,
                          validator: (v) => v!.isEmpty ? 'وارد کنید' : null,
                          onSaved: (v) => weight = double.parse(_convertPersianDigitsToEnglish(v!)),
                        ),
                        ListTile(
                          title: Text('تاریخ خرید: ${_formatJalali(selectedDate)}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await pickJalaliDate(context, selectedDate);
                            if (picked != null) setState(() => selectedDate = picked);
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
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  formKey.currentState!.save();

                                  if (existing == null) {
                                    Provider.of<DataProvider>(context, listen: false).addGold(
                                      GoldTransaction(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        type: 'gold_18',
                                        purchaseDate: selectedDate,
                                        purchasePricePerUnit: price,
                                        quantity: weight,
                                        description: desc,
                                      ),
                                    );
                                  } else {
                                    double sold = 0;
                                    for (var sale in Provider.of<DataProvider>(context, listen: false).saleBox.values) {
                                      if (sale.lotId == existing.id && sale.isGold) sold += sale.quantity;
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
        ),
      ),
    );
  }

  void _showSellGoldDialog(BuildContext context, GoldTransaction lot) {
    final currentPrice = Provider.of<PriceProvider>(context, listen: false).prices[lot.type]?.currentPrice ?? 0;

    final priceCtrl = TextEditingController(
      text: currentPrice == 0 ? '' : _formatWithSeparator(currentPrice),
    );

    final qtyCtrl = TextEditingController(
      text: _editableDouble(lot.remainingQuantity),
    );

    DateTime saleDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                      const Text('فروش طلا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('موجودی: ${_formatNumber(lot.remainingQuantity)} گرم'),
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
                        title: Text('تاریخ فروش: ${_formatJalali(saleDate)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await pickJalaliDate(context, saleDate);
                          if (picked != null) setState(() => saleDate = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final q = double.tryParse(_convertPersianDigitsToEnglish(qtyCtrl.text).replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                              final p = double.tryParse(_convertPersianDigitsToEnglish(priceCtrl.text).replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

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
        ),
      ),
    );
  }
}

// -------------------- CoinListScreen --------------------
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
                      _statColumn('ربع', _formatNumber(rub)),
                      _statColumn('نیم', _formatNumber(nim)),
                      _statColumn('تمام', _formatNumber(tamam)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('تعداد کل: '),
                      Text(_formatNumber(totalCoins), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              trailing: Text(_formatRial(totalPaid), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: activeCoins.map((c) {
                final rawPrice = priceProvider.prices[c.coinType]?.currentPrice ?? 0;
                final cp = rawPrice > 0 ? rawPrice : c.purchasePricePerUnit;

                final paid = c.purchasePricePerUnit * c.remainingCount;
                final currentValue = cp * c.remainingCount;
                final days = Calculator.daysBetween(c.purchaseDate, DateTime.now());

                final profit = _dailyProfit(
                  currentPrice: cp,
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
                            '${_formatNumber(c.remainingCount)} ${_coinName(c.coinType)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تاریخ خرید: ${_formatJalali(c.purchaseDate)}'),
                              Text('فی خرید: ${_formatRial(c.purchasePricePerUnit)}'),
                              Text('ارزش فعلی: ${_formatRial(currentValue)}'),
                              Text(
                                'سود خالص: ${_formatRial(profit)}',
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
                                            '${_formatNumber(s.quantity.toInt())} عدد در ${_formatJalali(s.saleDate)}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Text(
                                          _formatRial(saleProfit),
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                          initialValue: price == 0 ? '' : _formatWithSeparator(price),
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
                          onSaved: (v) => count = int.parse(_convertPersianDigitsToEnglish(v!)),
                        ),
                        ListTile(
                          title: Text('تاریخ خرید: ${_formatJalali(selectedDate)}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await pickJalaliDate(context, selectedDate);
                            if (picked != null) setState(() => selectedDate = picked);
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
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  formKey.currentState!.save();

                                  if (existing == null) {
                                    Provider.of<DataProvider>(context, listen: false).addCoin(
                                      CoinTransaction(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        coinType: coinType,
                                        purchaseDate: selectedDate,
                                        purchasePricePerUnit: price,
                                        count: count,
                                        description: desc,
                                      ),
                                    );
                                  } else {
                                    int sold = 0;
                                    for (var sale in Provider.of<DataProvider>(context, listen: false).saleBox.values) {
                                      if (sale.lotId == existing.id && !sale.isGold) sold += sale.quantity.toInt();
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
        ),
      ),
    );
  }

  void _showSellCoinDialog(BuildContext context, CoinTransaction lot) {
    final currentPrice = Provider.of<PriceProvider>(context, listen: false).prices[lot.coinType]?.currentPrice ?? 0;

    final priceCtrl = TextEditingController(
      text: currentPrice == 0 ? '' : _formatWithSeparator(currentPrice),
    );

    final cntCtrl = TextEditingController(text: lot.remainingCount.toString());
    DateTime saleDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                      const Text('فروش سکه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('موجودی: ${_formatNumber(lot.remainingCount)} عدد'),
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
                        title: Text('تاریخ فروش: ${_formatJalali(saleDate)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await pickJalaliDate(context, saleDate);
                          if (picked != null) setState(() => saleDate = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final n = int.tryParse(_convertPersianDigitsToEnglish(cntCtrl.text).replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                              final p = double.tryParse(_convertPersianDigitsToEnglish(priceCtrl.text).replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

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
        ),
      ),
    );
  }
}

// -------------------- ChartsScreen --------------------
class ChartsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final priceProvider = Provider.of<PriceProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);

    final activeGold = dataProvider.activeGold;
    final activeCoins = dataProvider.activeCoins;

    double goldValue = 0;
    double totalCoinValue = 0;

    Map<String, double> valueByType = {};
    Map<String, double> costByType = {};
    Map<String, double> profitByType = {};
    Map<String, double> coinTypeValues = {};

    for (var g in activeGold) {
      final currentPriceRaw = priceProvider.prices[g.type]?.currentPrice ?? 0;
      final currentPrice = currentPriceRaw > 0 ? currentPriceRaw : g.purchasePricePerUnit;

      final value = currentPrice * g.remainingQuantity;
      final cost = g.purchasePricePerUnit * g.remainingQuantity;
      final profit = value - cost;

      goldValue += value;

      valueByType.update(g.type, (v) => v + value, ifAbsent: () => value);
      costByType.update(g.type, (v) => v + cost, ifAbsent: () => cost);
      profitByType.update(g.type, (v) => v + profit, ifAbsent: () => profit);
    }

    for (var c in activeCoins) {
      final currentPriceRaw = priceProvider.prices[c.coinType]?.currentPrice ?? 0;
      final currentPrice = currentPriceRaw > 0 ? currentPriceRaw : c.purchasePricePerUnit;

      final value = currentPrice * c.remainingCount;
      final cost = c.purchasePricePerUnit * c.remainingCount;
      final profit = value - cost;

      totalCoinValue += value;

      valueByType.update(c.coinType, (v) => v + value, ifAbsent: () => value);
      costByType.update(c.coinType, (v) => v + cost, ifAbsent: () => cost);
      profitByType.update(c.coinType, (v) => v + profit, ifAbsent: () => profit);
      coinTypeValues.update(c.coinType, (v) => v + value, ifAbsent: () => value);
    }

    final totalValue = goldValue + totalCoinValue;

    List<PieChartSectionData> distributionSections = [];

    if (goldValue > 0) {
      distributionSections.add(
        PieChartSectionData(
          value: goldValue,
          title: 'طلای آب شده\n${((goldValue / (totalValue == 0 ? 1 : totalValue)) * 100).toStringAsFixed(1).toPersianDigit()}٪',
          color: Colors.blue,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      );
    }

    for (var e in coinTypeValues.entries) {
      if (e.value > 0) {
        distributionSections.add(
          PieChartSectionData(
            value: e.value,
            title: '${_coinName(e.key)}\n${((e.value / (totalValue == 0 ? 1 : totalValue)) * 100).toStringAsFixed(1).toPersianDigit()}٪',
            color: _coinColor(e.key),
            radius: 50,
            titleStyle: const TextStyle(fontSize: 9, color: Colors.white),
          ),
        );
      }
    }

    List<PieChartSectionData> coinSections = [];
    for (var e in coinTypeValues.entries) {
      if (e.value > 0) {
        coinSections.add(
          PieChartSectionData(
            value: e.value,
            title: '${_coinName(e.key)}\n${((e.value / (totalCoinValue == 0 ? 1 : totalCoinValue)) * 100).toStringAsFixed(1).toPersianDigit()}٪',
            color: _coinColor(e.key),
            radius: 36,
            titleStyle: const TextStyle(fontSize: 9, color: Colors.white),
          ),
        );
      }
    }

    final groupedEntries = valueByType.entries
        .where((e) => e.value > 0 || (costByType[e.key] ?? 0) > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final profitEntries = profitByType.entries
        .where((e) => e.value.abs() > 0)
        .toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    Map<int, double> dailyPurchases = {};

    for (var g in dataProvider.goldBox.values) {
      final key = DateTime.utc(g.purchaseDate.year, g.purchaseDate.month, g.purchaseDate.day)
          .millisecondsSinceEpoch;

      final amount = g.purchasePricePerUnit * g.quantity;
      dailyPurchases[key] = (dailyPurchases[key] ?? 0) + amount;
    }

    for (var c in dataProvider.coinBox.values) {
      final key = DateTime.utc(c.purchaseDate.year, c.purchaseDate.month, c.purchaseDate.day)
          .millisecondsSinceEpoch;

      final amount = c.purchasePricePerUnit * c.count;
      dailyPurchases[key] = (dailyPurchases[key] ?? 0) + amount;
    }

    final sortedDays = dailyPurchases.keys.toList()..sort();

    List<FlSpot> investmentSpots = [];
    double cumulative = 0;

    for (var day in sortedDays) {
      cumulative += dailyPurchases[day]!;
      investmentSpots.add(FlSpot(day.toDouble(), cumulative));
    }

    final now = DateTime.now();
    final nowKey = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;

    if (investmentSpots.isNotEmpty) {
      if (nowKey > investmentSpots.last.x.toInt()) {
        investmentSpots.add(FlSpot(nowKey.toDouble(), cumulative));
      } else {
        investmentSpots.add(FlSpot(investmentSpots.last.x + 86400000, cumulative));
      }
    }

    double minX = 0;
    double maxX = 1;
    double maxY = 1;

    if (investmentSpots.length >= 2) {
      minX = investmentSpots.first.x;
      maxX = investmentSpots.last.x;
      maxY = investmentSpots.map((s) => s.y).reduce(math.max);
      maxY = maxY == 0 ? 1 : maxY * 1.15;
    }

    final double bottomInterval = maxX > minX ? (maxX - minX) / 4 : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نمودارها'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text('توزیع دارایی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 250,
              child: distributionSections.isEmpty
                  ? const Center(child: Text('داده‌ای برای نمایش وجود ندارد'))
                  : PieChart(
                      PieChartData(
                        sections: distributionSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          if (coinSections.isNotEmpty) ...[
            Text('توزیع سکه‌ها', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: SizedBox(
                height: 240,
                child: PieChart(
                  PieChartData(
                    sections: coinSections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 55,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Text('مقایسه هزینه خرید و ارزش فعلی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(context, Theme.of(context).colorScheme.secondary.withOpacity(0.45), 'هزینه خرید'),
              const SizedBox(width: 16),
              _legendDot(context, Colors.teal, 'ارزش فعلی'),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 280,
              child: groupedEntries.isEmpty
                  ? const Center(child: Text('داده‌ای برای نمایش وجود ندارد'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: groupedEntries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final key = entry.value.key;

                          final cost = costByType[key] ?? 0;
                          final value = valueByType[key] ?? 0;

                          return BarChartGroupData(
                            x: index,
                            barsSpace: 6,
                            barRods: [
                              BarChartRodData(
                                toY: cost,
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.45),
                                width: 14,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              BarChartRodData(
                                toY: value,
                                color: Colors.teal,
                                width: 14,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 70,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  _formatCompact(value),
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= groupedEntries.length) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _shortAssetName(groupedEntries[index].key),
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(enabled: true),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          Text('سود/زیان دارایی‌ها', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 280,
              child: profitEntries.isEmpty
                  ? const Center(child: Text('داده‌ای برای نمایش وجود ندارد'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: profitEntries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: item.value,
                                color: item.value >= 0 ? Colors.green : Colors.red,
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 70,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  _formatCompact(value),
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= profitEntries.length) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _shortAssetName(profitEntries[index].key),
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(enabled: true),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          Text('روند خرید تجمعی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: 240,
              child: investmentSpots.length < 2
                  ? const Center(child: Text('داده‌ای برای نمایش وجود ندارد'))
                  : LineChart(
                      LineChartData(
                        minX: minX,
                        maxX: maxX,
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: investmentSpots,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.secondary,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 70,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  _formatCompact(value),
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: bottomInterval,
                              getTitlesWidget: (value, meta) {
                                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                return Text(
                                  _formatJalali(dt).substring(5),
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(enabled: true),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- SettingsScreen --------------------
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                    label: '${settings.bankInterestRate.toStringAsFixed(1).toPersianDigit()}٪',
                    onChanged: (v) => settings.setBankInterestRate(v),
                  ),
                  Text('${settings.bankInterestRate.toStringAsFixed(1).toPersianDigit()}٪'),
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
                    label: _formatNumber(settings.autoUpdateInterval),
                    onChanged: (v) {
                      settings.setAutoUpdateInterval(v.toInt());
                      priceProvider.setAutoUpdateInterval(v.toInt());
                    },
                  ),
                  Text('${_formatNumber(settings.autoUpdateInterval)} ثانیه'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('به‌روزرسانی دستی قیمت‌ها'),
              trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: priceProvider.fetchPrices),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('رنگ ثانویه'),
              trailing: CircleAvatar(backgroundColor: settings.secondaryColor, radius: 16),
              onTap: () {
                Color selectedColor = settings.secondaryColor;

                showDialog(
                  context: context,
                  builder: (ctx) {
                    return StatefulBuilder(
                      builder: (ctx, setDialogState) {
                        return AlertDialog(
                          title: const Text('انتخاب رنگ ثانویه'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: selectedColor,
                              onColorChanged: (color) {
                                setDialogState(() => selectedColor = color);
                              },
                              colorPickerWidth: 300,
                              pickerAreaHeightPercent: 0.7,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('انصراف'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                settings.setSecondaryColor(selectedColor);
                                Navigator.pop(ctx);
                              },
                              child: const Text('تأیید'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('قیمت‌های پایه (۱/۱/۱۴۰۵)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...basePrices.keys.map((key) {
            final value = basePrices[key] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(_goldTypeName(key)),
                trailing: SizedBox(
                  width: 140,
                  child: TextFormField(
                    key: ValueKey('base_${key}_$value'),
                    initialValue: value == 0 ? '' : _formatWithSeparator(value),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      _SeparatedNumberFormatter(),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'ریال',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onFieldSubmitted: (text) {
                      final cleaned = _convertPersianDigitsToEnglish(text).replaceAll(RegExp(r'[^\d]'), '');
                      final val = double.tryParse(cleaned) ?? 0;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در خروجی گرفتن: $e')));
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأیید', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isImporting = false);
        return;
      }

      await dataProvider.importData(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('داده‌ها با موفقیت بازیابی شدند')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در وارد کردن: $e')));
    }

    setState(() => _isImporting = false);
  }
}

// -------------------- Main --------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await initializeDateFormatting('fa', null);
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
        ChangeNotifierProvider(
          create: (_) => DataProvider(goldBox: goldBox, coinBox: coinBox, saleBox: saleBox),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final baseScheme = ColorScheme.fromSeed(seedColor: settings.secondaryColor);

          final colorScheme = baseScheme.copyWith(
            secondary: settings.secondaryColor,
            secondaryContainer: settings.secondaryColor.withOpacity(0.16),
            onSecondaryContainer: settings.secondaryColor.withOpacity(0.95),
          );

          return MaterialApp(
            title: 'مدیریت دارایی طلا و سکه',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: colorScheme,
              scaffoldBackgroundColor: colorScheme.surface,
              cardColor: colorScheme.surface,
              appBarTheme: AppBarTheme(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                centerTitle: true,
                elevation: 0,
              ),
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
              fontFamily: 'Vazir',
            ),
            home: const MainScreen(),
          );
        },
      ),
    ),
  );
}

// -------------------- MainScreen --------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Offset _slideBegin = const Offset(0.06, 0);

  final List<Widget> _screens = [
    HomeScreen(),
    GoldListScreen(),
    CoinListScreen(),
    ChartsScreen(),
    SettingsScreen(),
  ];

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;

    _slideBegin = index > _selectedIndex
        ? const Offset(0.06, 0)
        : const Offset(-0.06, 0);

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final tween = Tween<Offset>(begin: _slideBegin, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: tween,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: GlassTabBar.bottom(
        selectedIndex: _selectedIndex,
        onTabSelected: _onTabSelected,
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