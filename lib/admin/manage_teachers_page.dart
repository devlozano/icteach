import 'create_staff_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageTeachersPage extends StatelessWidget {
  const ManageTeachersPage({super.key, this.embedded = false, this.firestore});
  final bool embedded;
  final FirebaseFirestore? firestore;

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<QuerySnapshot>(
      stream: (firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError)
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load accounts. Check your connection.'),
          );
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No teachers found.'));
        }

        return ListView.builder(
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(data['name'] ?? data['displayName'] ?? 'Teacher'),
              subtitle: Text(data['email'] ?? ''),
            );
          },
        );
      },
    );
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Teachers'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateStaffPage(selectedRole: 'teacher'),
              ),
            ),
          ),
        ],
      ),
      body: content,
    );
  }
}
