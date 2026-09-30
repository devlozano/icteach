import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/lrn_csv_parser.dart';

class LrnImportResult {
  final int added, skipped;
  const LrnImportResult(this.added, this.skipped);
}

class LrnImportFailure implements Exception {
  final int added, skipped;
  final Object cause;
  const LrnImportFailure(this.added, this.skipped, this.cause);
  @override
  String toString() =>
      'Import interrupted. $added new records confirmed, $skipped existing records skipped. Reconnect and retry the same file; existing records will not be overwritten.';
}

class LrnCsvImportService {
  static const chunkSize = 100;
  final Future<int> Function(List<LrnCsvRecord>) _createMissing;
  LrnCsvImportService({
    Future<int> Function(List<LrnCsvRecord>)? createMissing,
    String folderId = '',
    FirebaseFirestore? firestore,
  }) : _createMissing =
           createMissing ??
           ((rows) => _writeChunk(
             rows,
             folderId,
             firestore ?? FirebaseFirestore.instance,
           ));

  static Future<int> _writeChunk(
    List<LrnCsvRecord> rows,
    String folderId,
    FirebaseFirestore db,
  ) async {
    return db.runTransaction<int>((transaction) async {
      final refs = rows
          .map((r) => db.collection('lrn_master_list').doc(r.lrn))
          .toList();
      // All reads happen before writes. Concurrent registrations/imports cause retries.
      final existing = await Future.wait(refs.map(transaction.get));
      var added = 0;
      for (var i = 0; i < rows.length; i++) {
        if (existing[i].exists) continue;
        transaction.set(refs[i], {
          ...rows[i].names,
          'isRegistered': false,
          'uploadedAt': FieldValue.serverTimestamp(),
          'folderId': folderId,
        });
        added++;
      }
      return added;
    });
  }

  Future<LrnImportResult> importRecords(
    List<LrnCsvRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    var added = 0, skipped = 0;
    for (var start = 0; start < records.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, records.length);
      final chunk = records.sublist(start, end);
      try {
        final count = await _createMissing(chunk);
        added += count;
        skipped += chunk.length - count;
      } catch (e) {
        throw LrnImportFailure(added, skipped, e);
      }
      onProgress?.call(end, records.length);
    }
    return LrnImportResult(added, skipped);
  }
}
