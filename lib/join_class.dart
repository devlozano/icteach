import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class JoinClassPage extends StatefulWidget {
  const JoinClassPage({super.key});

  @override
  State<JoinClassPage> createState() => _JoinClassPageState();
}

class _JoinClassPageState extends State<JoinClassPage> {
  final TextEditingController _classCodeController = TextEditingController();
  bool _isLoading = false;
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _classCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _applyScannedCode(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) return;

    final normalized = value.toUpperCase();
    final validCode = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (validCode.length != 7) {
      _showMessage('This QR code is not a valid class code.');
      return;
    }

    _classCodeController.text = validCode;
    _classCodeController.selection = TextSelection.collapsed(
      offset: _classCodeController.text.length,
    );
    setState(() {});
  }

  Future<void> _openScanner() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            await _scannerController.start();
          } catch (_) {
            // Ignore startup races while the controller initializes.
          }
        });

        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Scan class QR code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2B4A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _scannerController.stop();
                        Navigator.of(modalContext).pop();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: _scannerController,
                  fit: BoxFit.contain,
                  onDetect: (capture) {
                    if (!mounted) return;

                    final barcode = capture.barcodes.firstOrNull;
                    final rawValue = barcode?.rawValue;

                    if (rawValue == null || rawValue.isEmpty) {
                      return;
                    }

                    _applyScannedCode(rawValue);
                    _scannerController.stop();
                    if (mounted) {
                      Navigator.of(modalContext).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (mounted) {
      _scannerController.stop();
    }
  }

  Future<void> _joinClass() async {
    final classCode = _classCodeController.text.trim().toUpperCase();

    if (classCode.isEmpty) {
      _showMessage("Please enter a class code.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage("Please sign in first.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find class with the given code
      final query = await FirebaseFirestore.instance
          .collection('classes')
          .where('classCode', isEqualTo: classCode)
          .where('status', isEqualTo: 'active')
          .get();

      if (query.docs.isEmpty) {
        _showMessage("No class found with code: $classCode");
        return;
      }

      final classDoc = query.docs.first;
      final classData = classDoc.data();
      final classId = classDoc.id;

      // Check if user is already enrolled
      final enrolledStudents = List<String>.from(
        classData['enrolledStudentIds'] ?? [],
      );
      if (enrolledStudents.contains(user.uid)) {
        _showMessage("You are already enrolled in this class.");
        return;
      }

      // ✅ Get user role from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // ✅ If user doesn't exist in users collection, try students collection
      Map<String, dynamic> userData = {};
      String userRole = 'student';
      String userName = user.displayName ?? 'User';
      String userEmail = user.email ?? '';

      if (userDoc.exists) {
        userData = userDoc.data() ?? {};
        userRole = userData['role']?.toString() ?? 'student';
        userName =
            userData['name']?.toString() ??
            userData['displayName']?.toString() ??
            user.displayName ??
            'User';
        userEmail = userData['email']?.toString() ?? user.email ?? '';
      } else {
        // ✅ Check if user exists in students collection
        final studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data() ?? {};
          userRole = studentData['role']?.toString() ?? 'student';
          userName =
              studentData['name']?.toString() ??
              studentData['displayName']?.toString() ??
              user.displayName ??
              'User';
          userEmail = studentData['email']?.toString() ?? user.email ?? '';

          // ✅ Create user document in users collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': userName,
                'displayName': userName,
                'email': userEmail,
                'role': userRole,
                'firstName': studentData['firstName'] ?? '',
                'middleName': studentData['middleName'] ?? '',
                'lastName': studentData['lastName'] ?? '',
                'extension': studentData['extension'] ?? '',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
          debugPrint('✅ Created user document from students collection');
        } else {
          // ✅ Create minimal user document
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': user.displayName ?? 'Student',
                'displayName': user.displayName ?? 'Student',
                'email': user.email ?? '',
                'role': 'student',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
          debugPrint('✅ Created minimal user document');
        }
      }

      // ✅ Check if user already has a class (only for students, not trainers)
      if (userRole != 'trainer') {
        final existingClasses = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('classes')
            .get();

        var hasActiveClass = false;
        for (final membership in existingClasses.docs) {
          final previous = await FirebaseFirestore.instance
              .collection('classes')
              .doc(membership.id)
              .get();
          if (previous.exists && previous.data()?['status'] != 'archived')
            hasActiveClass = true;
        }
        if (hasActiveClass) {
          _showMessage(
            "You are already enrolled in a class. You can only join one class.",
          );
          return;
        }
      }

      // ✅ Get teacher name from class data
      if (classData['status'] == 'archived') {
        _showMessage(
          'This class is archived. Ask for your current school-year class code.',
        );
        return;
      }
      final teacherName =
          classData['teacherName']?.toString() ?? 'Unknown Teacher';
      final className = classData['name']?.toString() ?? 'Unnamed Class';
      final description = classData['description']?.toString() ?? '';
      final sectionCode = classData['sectionCode']?.toString() ?? '';
      final classCodeValue = classData['classCode']?.toString() ?? '';
      final teacherId = classData['teacherId']?.toString() ?? '';
      final teacherEmail = classData['teacherEmail']?.toString() ?? '';
      final schoolYear = classData['schoolYear']?.toString() ?? '';

      debugPrint('👤 User joining class: $userName');
      debugPrint('👤 User role: $userRole');
      debugPrint('📚 Class: $className');

      // ✅ STEP 1: Add user to class's students subcollection
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'name': userName,
            'email': userEmail,
            'role': userRole,
            'joinedAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      debugPrint('✅ Added user to class subcollection with role: $userRole');

      // ✅ STEP 2: Update enrolledStudentIds array in class document
      await classDoc.reference.update({
        'enrolledStudentIds': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Updated enrolledStudentIds array');

      // ✅ STEP 3: Store ALL class data in user's subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .doc(classId)
          .set({
            'classId': classId,
            'className': className,
            'description': description,
            'sectionCode': sectionCode,
            'classCode': classCodeValue,
            'teacherId': teacherId,
            'teacherName': teacherName,
            'teacherEmail': teacherEmail,
            'schoolYear': schoolYear,
            'joinedAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      debugPrint('✅ Added class to user\'s subcollection');

      // ✅ STEP 4: Update the user's main document with class info
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'currentClassId': classId,
            'currentClassName': className,
            'currentTeacherName': teacherName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      debugPrint('✅ Updated user main document');

      // ✅ STEP 5: Also update students collection if it exists
      final studentDocCheck = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (studentDocCheck.exists) {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .update({
              'currentClassId': classId,
              'currentClassName': className,
              'currentTeacherName': teacherName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        debugPrint('✅ Updated students collection');
      }

      if (!mounted) return;

      // Show success message
      final roleEmoji = userRole == 'trainer' ? '👑' : '🎓';
      final roleLabel = userRole == 'trainer' ? 'Trainer' : 'Student';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✅ Successfully joined class as $roleLabel!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Class: $className', style: const TextStyle(fontSize: 13)),
              Text(
                'Teacher: $teacherName',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '$roleEmoji Role: $roleLabel',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint("❌ Error joining class: $error");
      _showMessage("Failed to join class: $error");
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
        title: const Text("Join Class"),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      "Join a Class",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B2B4A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter the class code provided by your teacher",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Info Box
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
                              "Enter the 7-character class code. Students can only join one class, while trainers can join multiple.",
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Class Code Input
                    TextFormField(
                      controller: _classCodeController,
                      decoration: InputDecoration(
                        labelText: "Class Code",
                        hintText: "Enter 7-character code (e.g., ABC1234)",
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          onPressed: _openScanner,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          tooltip: 'Scan QR code',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF0B2B4A),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        counterText: '', // Hide character counter
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 7,
                      onChanged: (value) {
                        if (value != value.toUpperCase()) {
                          _classCodeController.value = TextEditingValue(
                            text: value.toUpperCase(),
                            selection: TextSelection.collapsed(
                              offset: value.length,
                            ),
                          );
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_classCodeController.text.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Text(
                                'Join Code QR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              QrImageView(
                                data: _classCodeController.text
                                    .trim()
                                    .toUpperCase(),
                                version: QrVersions.auto,
                                size: 180,
                                backgroundColor: Colors.white,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _classCodeController.text.trim().toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Join Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _joinClass,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2B4A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            : const Text(
                                "Join Class",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
