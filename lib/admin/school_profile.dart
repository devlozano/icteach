import '../services/workspace_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../services/cloudinary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SchoolIdentity extends StatefulWidget {
  final bool compact;
  const SchoolIdentity({super.key, this.compact = false});
  @override
  State<SchoolIdentity> createState() => _SchoolIdentityState();
}

class _SchoolIdentityState extends State<SchoolIdentity> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream =
      FirebaseFirestore.instance
          .collection('settings')
          .doc('school_profile')
          .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final loadedName = data?['name']?.toString().trim();
          if (loadedName != null &&
              loadedName.isNotEmpty &&
              loadedName != WorkspacePreferences.selection('school_name')) {
            WorkspacePreferences.saveSelection('school_name', loadedName);
          }
          final schoolName = loadedName?.isNotEmpty == true
              ? loadedName
              : data == null
              ? WorkspacePreferences.selection('school_name')
              : null;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SchoolLogo(
                url: data?['logoUrl']?.toString(),
                size: widget.compact ? 34 : 64,
              ),
              const SizedBox(width: 10),
              Flexible(
                child:
                    schoolName == null &&
                        snapshot.connectionState == ConnectionState.waiting
                    ? const SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    : Text(
                        schoolName ?? 'School name not set',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      );
}

class SchoolLogo extends StatelessWidget {
  final String? url;
  final double size;
  const SchoolLogo({super.key, this.url, this.size = 64});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: url?.isNotEmpty == true
        ? Image.network(
            url!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.school_outlined, color: Color(0xFF0891B2)),
          )
        : const Icon(Icons.school_outlined, color: Color(0xFF0891B2)),
  );
}

class SchoolProfileEditor extends StatefulWidget {
  const SchoolProfileEditor({super.key});
  @override
  State<SchoolProfileEditor> createState() => _SchoolProfileEditorState();
}

class _SchoolProfileEditorState extends State<SchoolProfileEditor> {
  final name = TextEditingController();
  final logo = TextEditingController();
  final form = GlobalKey<FormState>();
  PlatformFile? selectedLogo;
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          (await FirebaseFirestore.instance
                  .collection('settings')
                  .doc('school_profile')
                  .get())
              .data();
      if (!mounted) return;
      name.text = data?['name']?.toString() ?? '';
      logo.text = data?['logoUrl']?.toString() ?? '';
      setState(() {
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load school profile. Tap to retry.');
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.bytes == null || file.size > 5 * 1024 * 1024) {
        throw StateError('Choose an image up to 5 MB.');
      }
      final image = await decodeImageFromList(file.bytes!);
      image.dispose();
      if (mounted && !saving) setState(() => selectedLogo = file);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a valid PNG, JPG or WebP image up to 5 MB.'),
          ),
        );
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      if (selectedLogo != null) {
        final uploaded = await CloudinaryService.uploadFile(
          file: selectedLogo!,
          folder: 'icteach/school',
        );
        logo.text = uploaded.url;
        selectedLogo = null;
      }
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('school_profile')
          .set({
            'name': name.text.trim(),
            'logoUrl': logo.text.trim(),
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await WorkspacePreferences.saveSelection('school_name', name.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('School profile saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save school profile. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return TextButton(onPressed: _load, child: Text(error!));
    if (loading) return const Center(child: CircularProgressIndicator());
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'School profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'The school name and logo represent the administrator throughout the workspace.',
              ),
              const SizedBox(height: 20),
              if (selectedLogo?.bytes != null)
                Image.memory(
                  selectedLogo!.bytes!,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                )
              else
                SchoolLogo(url: logo.text.trim(), size: 90),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'School name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the school name.'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: saving ? null : _pickLogo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose logo image'),
              ),
              if (selectedLogo != null) Text(selectedLogo!.name),
              const Text('PNG, JPG or WebP, up to 5 MB.'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving…' : 'Save school profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
