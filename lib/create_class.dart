import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin/staff_assignment_page.dart';
import 'services/principal_assignments.dart';
import 'widgets/principal_workspace_shell.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});
  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  late final _access = PrincipalAssignments().requirePrincipal();
  @override
  Widget build(BuildContext context) => PrincipalDetailScaffold(
    title: 'Add section',
    subtitle: 'Choose the teacher who will own the new class and section.',
    icon: Icons.add_home_work_rounded,
    maxWidth: 960,
    child: FutureBuilder<void>(
      future: _access,
      builder: (context, access) {
        if (access.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (access.hasError) {
          return const Center(
            child: Text('Classes and sections are assigned by the principal.'),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'teacher')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load teachers. Please reopen this page.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs
                .where((d) => d.data()['isActive'] != false)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFBFD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF0369A1)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The principal creates sections. Teachers receive them automatically and cannot create their own classes.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Select a teacher',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${docs.length} active ${docs.length == 1 ? 'teacher' : 'teachers'} available',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.person_off_outlined, size: 34),
                        SizedBox(height: 10),
                        Text('Add an active teacher first.'),
                      ],
                    ),
                  ),
                for (final doc in docs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StaffAssignmentPage(
                              uid: doc.id,
                              role: 'teacher',
                              name: doc.data()['name'] ?? 'Teacher',
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE2F7F9),
                                foregroundColor: Color(0xFF0891B2),
                                child: Icon(Icons.school_outlined),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.data()['name'] ?? 'Teacher',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if ((doc.data()['email'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        doc.data()['email'].toString(),
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
