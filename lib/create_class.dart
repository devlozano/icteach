import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  // Generate a unique class code (like Google Classroom)
  String _generateClassCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    String code = '';
    for (int i = 0; i < 7; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  // Check if class code already exists
  Future<bool> _isClassCodeUnique(String code) async {
    final query = await FirebaseFirestore.instance
        .collection('classes')
        .where('classCode', isEqualTo: code)
        .get();
    return query.docs.isEmpty;
  }

  // Generate unique class code (retry if duplicate)
  Future<String> _generateUniqueClassCode() async {
    String code;
    bool isUnique;
    int attempts = 0;
    do {
      code = _generateClassCode();
      isUnique = await _isClassCodeUnique(code);
      attempts++;
      if (attempts > 10) {
        // If we can't generate a unique code after 10 attempts, add timestamp
        code = '$code${DateTime.now().millisecondsSinceEpoch % 1000}';
        break;
      }
    } while (!isUnique);
    return code;
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _sectionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      _showMessage("No teacher account found.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final className = _classNameController.text.trim();
      final sectionCode = _sectionController.text.trim();
      final description = _descriptionController.text.trim();

      // Check duplicate class
      final existing = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: teacher.uid)
          .where('name', isEqualTo: className)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMessage("You already created this class.");
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Get the teacher's full name from Firestore users collection
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacher.uid)
          .get();

      final teacherData = teacherDoc.data();

      // ✅ Get the proper teacher name from the users collection
      String teacherName = 'Unknown Teacher';
      if (teacherData != null) {
        // Try to get the 'name' field first (which has the full formatted name)
        if (teacherData['name'] != null &&
            teacherData['name'].toString().isNotEmpty) {
          teacherName = teacherData['name'].toString();
          print('✅ Using teacher name from "name" field: $teacherName');
        }
        // Fallback to building the name from parts
        else {
          final firstName = teacherData['firstName']?.toString() ?? '';
          final middleInitial = teacherData['middleInitial']?.toString() ?? '';
          final middleName = teacherData['middleName']?.toString() ?? '';
          final lastName = teacherData['lastName']?.toString() ?? '';
          final extension = teacherData['extension']?.toString() ?? '';

          // If middleName exists, use it instead of middleInitial
          final middlePart = middleName.isNotEmpty ? middleName : middleInitial;

          final parts = [firstName, middlePart, lastName, extension];
          teacherName = parts.where((p) => p.isNotEmpty).join(' ');
          print('✅ Built teacher name from parts: $teacherName');

          if (teacherName.isEmpty) {
            teacherName =
                teacher.displayName ?? teacher.email ?? 'Unknown Teacher';
            print('⚠️ Fallback to displayName/email: $teacherName');
          }
        }
      } else {
        // Fallback to email if no user data found
        teacherName = teacher.displayName ?? teacher.email ?? 'Unknown Teacher';
        print('⚠️ No teacher data found, using: $teacherName');
      }

      // Generate unique class code
      final classCode = await _generateUniqueClassCode();
      final classRef = FirebaseFirestore.instance.collection('classes').doc();

      // Get current school year
      final settingsSnapshot = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('academic_year')
          .get();
      final configuredYear = settingsSnapshot
          .data()?['activeSchoolYear']
          ?.toString()
          .trim();
      if (configuredYear == null || configuredYear.isEmpty) {
        _showMessage(
          'The principal must set the active School Year before classes can be created.',
        );
        return;
      }
      final schoolYear = configuredYear;

      // Use the proper teacher name
      String teacherEmail = teacher.email ?? "No email provided";

      // ✅ Create class data with ALL fields
      final classData = {
        "id": classRef.id,
        "classCode": classCode,
        "name": className,
        "description": description,
        "sectionCode": sectionCode,
        "teacherId": teacher.uid,
        "teacherName": teacherName,
        "teacherEmail": teacherEmail,
        "enrolledStudentIds": [],
        "pendingReviews": 0,
        "status": "active",
        "schoolYear": schoolYear,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      };

      print("✅ Creating class with teacherName: $teacherName");
      print("📦 Full class data: $classData");

      await classRef.set(classData);

      if (!mounted) return;

      // Show success message with class details
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("✅ Class created successfully!"),
              const SizedBox(height: 4),
              Text(
                "Class Code: $classCode",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "Teacher: $teacherName",
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                "School Year: $schoolYear",
                style: const TextStyle(fontSize: 12),
              ),
              const Text("Share this code with your students to join."),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      print("❌ Error creating class: $error");
      _showMessage("Failed to create class: $error");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text("Create Class"),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Create New Class",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "A unique class code will be generated automatically. Share it with your students to join.",
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('system_settings')
                            .doc('academic_year')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final schoolYear = snapshot.data
                              ?.data()?['activeSchoolYear']
                              ?.toString()
                              .trim();
                          final configured =
                              schoolYear != null && schoolYear.isNotEmpty;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: configured
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: configured
                                    ? Colors.blue.shade200
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  configured
                                      ? Icons.calendar_today
                                      : Icons.warning_amber_rounded,
                                  color: configured
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade800,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    configured
                                        ? 'School Year: $schoolYear'
                                        : 'The principal must set the active School Year before a class can be created.',
                                    style: TextStyle(
                                      color: configured
                                          ? Colors.blue.shade900
                                          : Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _classNameController,
                        decoration: const InputDecoration(
                          labelText: "Class Name",
                          hintText: "Example: Computer Systems Servicing",
                          prefixIcon: Icon(Icons.class_),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Class name is required.";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sectionController,
                        decoration: const InputDecoration(
                          labelText: "Section",
                          hintText: "Example: Grade 12 ICT A",
                          prefixIcon: Icon(Icons.groups),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: "Description (optional)",
                          hintText: "Brief description of the class",
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createClass,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B2B4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Create Class"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
