import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models/evaluation_input.dart';

/// Builds and downloads a PDF grading report from an [EvaluationInput].
class ReportGenerator {
  static const PdfColor _ink = PdfColor.fromInt(0xFF232F3E);
  static const PdfColor _orange = PdfColor.fromInt(0xFFFF9900);
  static const PdfColor _teal = PdfColor.fromInt(0xFF00687A);

  static String _money(num? value, String currency) {
    if (value == null) return '—';
    final symbol = currency == 'INR' ? 'Rs. ' : '$currency ';
    return '$symbol${value.toStringAsFixed(0)}';
  }

  /// Generates the report and triggers a browser/OS download.
  static Future<void> downloadReport(EvaluationInput e) async {
    final doc = pw.Document();
    final currency = e.currency ?? 'INR';
    final generatedOn = DateTime.now().toLocal().toString().split('.').first;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(color: _ink),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AmazeLoop',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'AmazeLoop HealthCard',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(width: double.infinity, height: 4, color: _orange),
              pw.SizedBox(height: 20),

              // Product + condition summary
              pw.Text(
                e.productName ?? 'Graded Item',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: $generatedOn',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),

              // Condition + resale value highlight
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _highlightBox(
                      'CONDITION',
                      (e.condition ?? 'N/A').toUpperCase(),
                      _teal,
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: _highlightBox(
                      'ESTIMATED RESALE VALUE',
                      _money(
                        e.estimatedResaleValue ?? e.normalizedPrice,
                        currency,
                      ),
                      _orange,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              if ((e.conditionReason ?? '').isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFFF8EF),
                    border: pw.Border.all(color: _orange, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Assessment: ${e.conditionReason}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Details table
              pw.Text(
                'Evaluation Details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 8),
              _detailTable([
                ['Evaluation ID', e.evaluationId ?? '—'],
                ['Category', e.category ?? '—'],
                ['Reason for return', e.reason ?? '—'],
                if (e.orderId != null) ['Order ID', e.orderId!],
                if (e.originalPrice != null)
                  ['Original price', _money(e.originalPrice, currency)],
                if (e.reportedPrice != null)
                  ['Reported price', _money(e.reportedPrice, currency)],
                ['Normalized price', _money(e.normalizedPrice, currency)],
                if (e.avgPrice != null)
                  ['Category average', _money(e.avgPrice, currency)],
                [
                  'Estimated resale value',
                  _money(e.estimatedResaleValue ?? e.normalizedPrice, currency),
                ],
                ['Sorting queue', e.sortingQueue ?? '—'],
                ['Priority', e.priority ?? '—'],
                if (e.currentPincode != null && e.currentPincode!.isNotEmpty)
                  ['Pincode', e.currentPincode!],
              ]),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Text(
                'This report was generated automatically by AmazeLoop. Condition assessed via AI vision analysis of submitted photos.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final safeName = (e.productName ?? 'item').replaceAll(
      RegExp(r'[^a-zA-Z0-9]+'),
      '_',
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'AmazeLoop_Report_$safeName.pdf',
    );
  }

  static pw.Widget _highlightBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _detailTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.map((r) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                r[0],
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                r[1],
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
