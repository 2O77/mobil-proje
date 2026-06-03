import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/session_report_pdf_service.dart';

class SessionReportCard extends StatefulWidget {
  const SessionReportCard({
    super.key,
    required this.title,
    required this.body,
    this.sessionDate,
  });

  final String title;
  final String body;
  final DateTime? sessionDate;

  factory SessionReportCard.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return SessionReportCard(
      title: (data['title'] as String?) ?? 'Rapor',
      body: (data['body'] as String?) ?? '',
      sessionDate: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  @override
  State<SessionReportCard> createState() => _SessionReportCardState();
}

class _SessionReportCardState extends State<SessionReportCard> {
  var _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await openSessionReportPdf(
        title: widget.title,
        body: widget.body,
        sessionDate: widget.sessionDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF açılamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatSessionReportDate(widget.sessionDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _downloading ? null : _download,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.description_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    if (widget.body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'PDF indirmek için dokunun',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: _downloading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
