import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/module_model.dart';
import 'learning_path_service.dart';
import 'module_resource_link.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final uri = ModuleResourceLink.parse(module.attachmentUrl);
    if (kIsWeb) {
      // Preserve actionable host errors when CORS permits a metadata check.
      // A CORS failure alone must not prevent normal browser navigation.
      try {
        final response = await http
            .head(uri)
            .timeout(const Duration(seconds: 10));
        if (const [401, 403, 404, 410].contains(response.statusCode)) {
          throw StateError(
            ModuleResourceLink.responseError(uri, response.statusCode),
          );
        }
      } on http.ClientException {
        // File providers may disallow browser fetches but allow navigation.
      } on TimeoutException {
        // Let the browser handle slow providers and their own download UI.
      }
      // Browser navigation supports cross-origin files and preview providers.
      // Same-tab navigation remains usable after the asynchronous access check;
      // browsers can block a new popup once the original click has expired.
      final launched = await launchUrl(
        ModuleResourceLink.download(uri),
        webOnlyWindowName: '_self',
      );
      if (!launched)
        throw StateError(
          'Unable to open the download link. Try Open resource.',
        );
      return _recordDownload(classId, module, confirmed: false);
    }
    final client = http.Client();
    late Uint8List bytes;
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200)
        throw StateError(
          ModuleResourceLink.responseError(uri, response.statusCode),
        );
      if (response.headers['content-type']?.contains('text/html') == true) {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened)
          throw StateError(
            'Unable to open the file provider. Try Open resource.',
          );
        await _recordDownload(classId, module, confirmed: false);
        return 'Opened the file provider. Use its Download or Save button to save the module.';
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
    return _recordDownload(classId, module, confirmed: true);
  }

  static Future<String> _recordDownload(
    String classId,
    ModuleModel module, {
    required bool confirmed,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await record(classId, module.id, uid).set({
        'studentId': uid,
        'moduleId': module.id,
        'accessed': true,
        'downloadRequested': true,
        'downloadRequestedAt': FieldValue.serverTimestamp(),
        if (confirmed) 'downloaded': true,
        if (confirmed) 'downloadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      return 'File saved or sent to your browser, but tracking could not be updated. Reconnect and retry.';
    }
    return !confirmed
        ? 'Download sent to your browser. Browser save completion cannot be confirmed.'
        : 'Module downloaded successfully.';
  }
}
