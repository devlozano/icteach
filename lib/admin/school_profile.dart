import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SchoolIdentity extends StatelessWidget {
  final bool compact;
  const SchoolIdentity({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc('school_profile')
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SchoolLogo(
                url: data['logoUrl']?.toString(),
                size: compact ? 34 : 64,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  data['name']?.toString() ?? 'School profile',
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

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('school_profile')
          .set({
            'name': name.text.trim(),
            'logoUrl': logo.text.trim(),
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
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
              TextFormField(
                controller: logo,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'School logo image URL (HTTPS)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final uri = Uri.tryParse(v?.trim() ?? '');
                  return uri == null ||
                          uri.scheme != 'https' ||
                          uri.host.isEmpty
                      ? 'Enter a valid HTTPS image URL.'
                      : null;
                },
              ),
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
