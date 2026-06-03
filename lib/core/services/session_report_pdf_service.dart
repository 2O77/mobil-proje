import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

Future<Uint8List> buildSessionReportPdfBytes({
  required String title,
  required String body,
  DateTime? sessionDate,
}) async {
  final dateLabel = sessionDate == null ? null : DateFormat('dd.MM.yyyy HH:mm').format(sessionDate);
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (dateLabel != null) ...[
            pw.SizedBox(height: 8),
            pw.Text('Seans tarihi: $dateLabel', style: const pw.TextStyle(fontSize: 12)),
          ],
          pw.SizedBox(height: 12),
          pw.Text(body),
        ],
      ),
    ),
  );
  return doc.save();
}

String sessionReportPdfFilename(String title) {
  final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]', unicode: true), '').trim().replaceAll(RegExp(r'\s+'), '_');
  if (safeTitle.isEmpty) return 'auticare_seans.pdf';
  return '${safeTitle}_seans.pdf';
}

Future<void> openSessionReportPdf({
  required String title,
  required String body,
  DateTime? sessionDate,
}) async {
  final bytes = await buildSessionReportPdfBytes(title: title, body: body, sessionDate: sessionDate);
  final filename = sessionReportPdfFilename(title);

  try {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename.replaceAll('.pdf', ''),
    );
  } catch (_) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: filename)],
        subject: title,
      ),
    );
  }
}

String formatSessionReportDate(DateTime? date) {
  if (date == null) return 'Tarih yok';
  return DateFormat('dd.MM.yyyy HH:mm').format(date);
}
