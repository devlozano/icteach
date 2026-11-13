import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageQuestionnairesPage extends StatelessWidget {
  const ManageQuestionnairesPage({
    super.key,
    required this.classId,
    required this.className,
  });

  final String classId;
  final String className;

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection('classes')
      .doc(classId)
      .collection('questionnaires');

  Future<void> _createQuestionnaire(BuildContext context) async {
    final title = TextEditingController(text: 'Teaching and Learning Check-in');
    final description = TextEditingController(
      text:
          'Tell your trainer which topics are clear and where you need more support.',
    );
    final promptOne = TextEditingController(
      text: 'How clearly was this lesson explained?',
    );
    final promptTwo = TextEditingController(
      text: 'How difficult was the lesson or practical activity?',
    );
    final promptThree = TextEditingController(
      text: 'Which topic or step needs more explanation?',
    );
    var questionnaireType = 'teaching_feedback';
    var publishNow = true;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create questionnaire'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: questionnaireType,
                    decoration: const InputDecoration(
                      labelText: 'Evaluation type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'teaching_feedback',
                        child: Text('Teaching difficulty check-in'),
                      ),
                      DropdownMenuItem(
                        value: 'course_evaluation',
                        child: Text('End-of-course evaluation'),
                      ),
                      DropdownMenuItem(
                        value: 'system_evaluation',
                        child: Text('ICTeach system evaluation'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => questionnaireType = value);
                        if (value == 'system_evaluation') {
                          title.text = 'ICTeach system evaluation';
                          promptOne.text =
                              'How easy is ICTeach to use? (1 very difficult, 5 very easy)';
                          promptTwo.text =
                              'How useful is ICTeach for learning? (1 not useful, 5 very useful)';
                          promptThree.text =
                              'What problems did you experience and what should we improve?';
                        } else {
                          title.text = value == 'course_evaluation'
                              ? 'End-of-course evaluation'
                              : 'Teaching and Learning Check-in';
                          promptOne.text =
                              'How clearly does your teacher explain lessons? (1 unclear, 5 very clear)';
                          promptTwo.text =
                              'How difficult are the lessons? (1 easy, 5 very difficult)';
                          promptThree.text =
                              'Which topics need more explanation, and how could your teacher help?';
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: promptOne,
                    decoration: const InputDecoration(
                      labelText: 'Rating question 1',
                      helperText: 'Students answer from 1 to 5.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: promptTwo,
                    decoration: const InputDecoration(
                      labelText: 'Rating question 2',
                      helperText: 'Students answer from 1 to 5.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: promptThree,
                    decoration: const InputDecoration(
                      labelText: 'Written response question',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish immediately'),
                    value: publishNow,
                    onChanged: (value) =>
                        setDialogState(() => publishNow = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (shouldCreate != true || !context.mounted) return;
    if (title.text.trim().isEmpty ||
        promptOne.text.trim().isEmpty ||
        promptTwo.text.trim().isEmpty ||
        promptThree.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete the title and all questions.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    await _collection.add({
      'classId': classId,
      'title': title.text.trim(),
      'description': description.text.trim(),
      'type': questionnaireType,
      'isPublished': publishNow,
      'questions': [
        {'id': 'rating_1', 'prompt': promptOne.text.trim(), 'type': 'rating'},
        {'id': 'rating_2', 'prompt': promptTwo.text.trim(), 'type': 'rating'},
        {'id': 'comment', 'prompt': promptThree.text.trim(), 'type': 'text'},
      ],
      'createdBy': user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showResponses(
    BuildContext context,
    String questionnaireId,
    String title,
  ) async {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 650,
          height: 480,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('questionnaire_responses')
                .where('questionnaireId', isEqualTo: questionnaireId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final responses = snapshot.data!.docs;
              if (responses.isEmpty) {
                return const Center(child: Text('No student responses yet.'));
              }
              return ListView.separated(
                itemCount: responses.length,
                separatorBuilder: (_, index) => const Divider(),
                itemBuilder: (context, index) {
                  final data = responses[index].data();
                  final ratings = Map<String, dynamic>.from(
                    (data['ratings'] as Map?) ?? const {},
                  );
                  return ListTile(
                    leading: const Icon(Icons.rate_review),
                    title: Text(
                      data['studentName']?.toString() ?? 'Anonymous student',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${data['summary'] ?? 'No written response'}\n'
                      '${ratings.entries.map((e) => '${e.key}: ${e.value}/5').join(' | ')}\n'
                      'Interpret clarity and difficulty separately; high difficulty is not high teaching quality.',
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Questionnaires & Evaluations'),
            Text(className, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createQuestionnaire(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New questionnaire'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final questionnaires = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.millisecondsSinceEpoch ?? 0,
              );
            });
          if (questionnaires.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Create a teaching check-in, end-of-course evaluation, or '
                  'ICTeach system evaluation to collect student feedback.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: questionnaires.length,
            itemBuilder: (context, index) {
              final doc = questionnaires[index];
              final data = doc.data();
              final published = data['isPublished'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: published
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    child: Icon(
                      published
                          ? Icons.visibility_rounded
                          : Icons.edit_note_rounded,
                      color: published ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    data['title']?.toString() ?? 'Questionnaire',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${data['type']?.toString().replaceAll('_', ' ') ?? 'evaluation'} '
                    '- ${published ? 'Published' : 'Draft'}',
                  ),
                  onTap: () => _showResponses(
                    context,
                    doc.id,
                    data['title']?.toString() ?? 'Responses',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'toggle') {
                        await doc.reference.update({
                          'isPublished': !published,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      } else if (action == 'delete') {
                        await doc.reference.delete();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(published ? 'Unpublish' : 'Publish'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
