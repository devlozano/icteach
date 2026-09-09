import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/module_model.dart';
import 'learning_path_service.dart';

class ModuleAccessSummary {
  final int accessed, downloaded, requested;
  ModuleAccessSummary._(this.accessed, this.downloaded, this.requested);
  factory ModuleAccessSummary.fromRecords(
    Iterable<Map<String, dynamic>> records,
    Set<String> enrolled,
  ) {
    final opened = <String>{}, saved = <String>{}, requests = <String>{};
    for (final r in records) {
      final id = r['studentId'];
      if (id is! String || !enrolled.contains(id)) continue;
      if (r['accessed'] == true) opened.add(id);
      if (r['downloaded'] == true) saved.add(id);
      if (r['downloadRequested'] == true) requests.add(id);
    }
    return ModuleAccessSummary._(opened.length, saved.length, requests.length);
  }
}

class ModuleAccessService {
  static DocumentReference<Map<String, dynamic>> record(
    String classId,
    String moduleId,
    String uid,
  ) => FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('module_access')
      .doc('${moduleId}_$uid');
  static Future<void> resourceOpened(String classId, ModuleModel module) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await record(classId, module.id, uid).set({
      'studentId': uid,
      'moduleId': module.id,
      'accessed': true,
      'resourceOpenedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String> download(String classId, ModuleModel module) async {
    await LearningPathService.requireActive(classId);
    final uri = Uri.tryParse(module.attachmentUrl ?? '');
    if (uri == null || !['http', 'https'].contains(uri.scheme))
      throw StateError('No downloadable file is attached.');
    final client = http.Client();
    late Uint8List bytes;
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200)
        throw StateError('The file could not be downloaded.');
      if (response.headers['content-type']?.contains('text/html') == true) {
        throw StateError(
          'This is a preview page. Use Open resource, or ask your teacher for a direct file link.',
        );
      }
      const maximum = 50 * 1024 * 1024;
      if ((response.contentLength ?? 0) > maximum)
        throw StateError('Use Open resource for files over 50 MB.');
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (buffer.length + chunk.length > maximum)
          throw StateError('Use Open resource for files over 50 MB.');
        buffer.add(chunk);
      }
      bytes = buffer.takeBytes();
      if (bytes.isEmpty) throw StateError('The file is empty.');
    } finally {
      client.close();
    }
    final suggested =
        (module.fileName?.isNotEmpty == true
                ? module.fileName!
                : (uri.pathSegments.isEmpty
                      ? 'module.pdf'
                      : uri.pathSegments.last))
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save module',
      fileName: suggested.isEmpty ? 'module.pdf' : suggested,
      bytes: bytes,
    );
    if (!kIsWeb && path == null) return 'Download cancelled.';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await record(classId, module.id, uid).set({
        'studentId': uid,
        'moduleId': module.id,
        'accessed': true,
        'downloadRequested': true,
        'downloadRequestedAt': FieldValue.serverTimestamp(),
        if (!kIsWeb) 'downloaded': true,
        if (!kIsWeb) 'downloadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      return 'File saved or sent to your browser, but tracking could not be updated. Reconnect and retry.';
    }
    return kIsWeb
        ? 'Download sent to your browser. Browser save completion cannot be confirmed.'
        : 'Module downloaded successfully.';
  }
}
