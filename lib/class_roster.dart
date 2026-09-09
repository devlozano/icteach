import 'widgets/summary_print_button.dart';
import 'services/content_access_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ClassRosterPage extends StatefulWidget {
  final String classId;
  final String className;

  const ClassRosterPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassRosterPage> createState() => _ClassRosterPageState();
}

class _ClassRosterPageState extends State<ClassRosterPage> {
  String _classCode = '';
  String _teacherName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _trainers = [];

  @override
  void initState() {
    super.initState();
    _fetchClassData();
    _loadRoster();
  }

  Future<void> _fetchClassData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _classCode = data['classCode']?.toString() ?? '';
            _teacherName = data['teacherName']?.toString() ?? 'Unknown Teacher';
          });
        }
      }
    } catch (e) {
      print('Error fetching class data: $e');
    }
  }

  // ✅ Helper function to extract email from user data
  String _extractEmail(Map<String, dynamic> userData) {
    // Try common email field names
    final possibleEmailFields = [
      'email',
      'emailAddress',
      'userEmail',
      'mail',
      'email_id',
      'emailId',
    ];

    for (final field in possibleEmailFields) {
      if (userData[field] != null && userData[field].toString().isNotEmpty) {
        return userData[field].toString();
      }
    }

    return '';
  }

  // ✅ Helper function to extract name from user data
  String _extractName(Map<String, dynamic> userData) {
    // Try displayName first
    String name = userData['displayName']?.toString() ?? '';
    if (name.isNotEmpty) return name;

    // Try name field
    name = userData['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;

    // Try fullName field
    name = userData['fullName']?.toString() ?? '';
    if (name.isNotEmpty) return name;

    // Build from firstName + lastName
    final firstName = userData['firstName']?.toString() ?? '';
    final lastName = userData['lastName']?.toString() ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }

    return 'Unknown User';
  }

  // ✅ Helper function to extract role from user data
  String _extractRole(Map<String, dynamic> userData) {
    final role = userData['role']?.toString() ?? '';
    if (role.isNotEmpty) return role.toLowerCase();

    // Check if user is trainer by other fields
    if (userData['isTrainer'] == true || userData['trainer'] == true) {
      return 'trainer';
    }

    return 'student';
  }

  Future<void> _loadRoster() async {
    setState(() => _isLoading = true);
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (!classDoc.exists) {
        print('❌ Class document not found');
        setState(() => _isLoading = false);
        return;
      }

      final data = classDoc.data() ?? {};
      final enrolledIds = List<String>.from(data['enrolledStudentIds'] ?? []);

      print('📊 Total enrolled IDs: ${enrolledIds.length}');
      print('📊 Enrolled IDs: $enrolledIds');

      if (enrolledIds.isEmpty) {
        print('⚠️ No enrolled users found');
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Fetch ALL users from the users collection
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // ✅ Also fetch from students collection as backup
      final allStudentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      // Create a map of userId -> userData for quick lookup
      final Map<String, Map<String, dynamic>> usersMap = {};

      // Add users from users collection
      for (final doc in allUsersSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>? ?? {};
        final uid = userData['uid']?.toString() ?? doc.id;
        usersMap[uid] = userData;
        usersMap[doc.id] = userData;
      }

      // ✅ Add/override with students collection data (as backup)
      for (final doc in allStudentsSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>? ?? {};
        final uid = userData['uid']?.toString() ?? doc.id;
        // Only add if not already in map or if map data is incomplete
        if (!usersMap.containsKey(uid) || usersMap[uid]?['email'] == null) {
          usersMap[uid] = userData;
        }
        usersMap[doc.id] = userData;
      }

      print('📊 Found ${usersMap.length} users in collections');

      // ✅ Also fetch from class students subcollection
      final studentsSubSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .get();

      final Map<String, Map<String, dynamic>> subDataMap = {};
      for (final doc in studentsSubSnapshot.docs) {
        final subData = doc.data() as Map<String, dynamic>? ?? {};
        final uid = subData['uid']?.toString() ?? doc.id;
        subDataMap[uid] = subData;
      }

      // ✅ Separate students and trainers
      final List<Map<String, dynamic>> students = [];
      final List<Map<String, dynamic>> trainers = [];

      for (final userId in enrolledIds) {
        print('🔍 Looking for user: $userId');

        // Try to find the user in the usersMap
        Map<String, dynamic>? userData = usersMap[userId];

        // If not found by ID, try by uid field
        if (userData == null) {
          for (final entry in usersMap.entries) {
            if (entry.value['uid']?.toString() == userId) {
              userData = entry.value;
              print('   ✅ Found user by uid field');
              break;
            }
          }
        }

        // If still not found, check subcollection
        if (userData == null && subDataMap.containsKey(userId)) {
          userData = subDataMap[userId];
          print('   ✅ Found user in class subcollection');
        }

        if (userData != null) {
          // ✅ Extract data using helper functions
          final name = _extractName(userData);
          final email = _extractEmail(userData);
          final role = _extractRole(userData);

          print(
            '   👤 Found: $name, Role: $role, Email: ${email.isNotEmpty ? email : 'No email'}',
          );

          final userInfo = {
            'id': userId,
            'name': name,
            'email': email,
            'role': role,
            'data': userData,
          };

          if (role.toLowerCase() == 'trainer') {
            trainers.add(userInfo);
          } else {
            students.add(userInfo);
          }
        } else {
          // ✅ User not found anywhere - try to get from auth or create placeholder
          print('   ⚠️ User not found in any collection');

          // Try to get from subcollection one more time with full path
          final subDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.classId)
              .collection('students')
              .doc(userId)
              .get();

          String name = 'Student ${userId.substring(0, 6)}';
          String email = '';
          String role = 'student';

          if (subDoc.exists) {
            final subData = subDoc.data() ?? {};
            name = subData['name']?.toString() ?? name;
            email = _extractEmail(subData);
            role = subData['role']?.toString() ?? 'student';
            print('   📋 Found in subcollection: $name');
          }

          students.add({
            'id': userId,
            'name': name,
            'email': email,
            'role': role,
            'data': {},
          });
        }
      }

      // ✅ Sort by name
      students.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
      trainers.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      setState(() {
        _students = students;
        _trainers = trainers;
        _isLoading = false;
      });

      print(
        '📊 Final counts - Students: ${students.length}, Trainers: ${trainers.length}',
      );
      print('📊 Student names: ${students.map((s) => s['name']).join(', ')}');
      print('📊 Student emails: ${students.map((s) => s['email']).join(', ')}');
    } catch (e) {
      print('❌ Error loading roster: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> deleteStudent(BuildContext context, String studentId) async {
    if (studentId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid user ID")));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from class?'),
        content: const Text(
          'The student account and learning records will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (!await ContentAccessService.isClassStaff(widget.classId))
        throw StateError('Class staff access required.');
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.delete(
        db
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(studentId),
      );
      batch.delete(
        db
            .collection('users')
            .doc(studentId)
            .collection('classes')
            .doc(widget.classId),
      );
      batch.update(db.collection('classes').doc(widget.classId), {
        'enrolledStudentIds': FieldValue.arrayRemove([studentId]),
      });
      await batch.commit();
      await _loadRoster();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User removed from class")));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error removing user: $e")));
    }
  }

  void editStudent(
    BuildContext context,
    String studentId,
    Map<String, dynamic> data,
  ) {
    if (studentId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid user ID")));
      return;
    }

    final nameController = TextEditingController(
      text: data['displayName']?.toString() ?? data['name']?.toString() ?? '',
    );

    final emailController = TextEditingController(text: _extractEmail(data));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit User"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newEmail = emailController.text.trim();

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Name cannot be empty")),
                  );
                  return;
                }

                try {
                  // Update in users collection
                  final updateData = {'displayName': newName, 'name': newName};
                  if (newEmail.isNotEmpty) {
                    updateData['email'] = newEmail;
                  }
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(studentId)
                      .update(updateData);

                  // Also update in students collection if exists
                  final studentDoc = await FirebaseFirestore.instance
                      .collection('students')
                      .doc(studentId)
                      .get();
                  if (studentDoc.exists) {
                    final studentUpdateData = {
                      'displayName': newName,
                      'name': newName,
                    };
                    if (newEmail.isNotEmpty) {
                      studentUpdateData['email'] = newEmail;
                    }
                    await FirebaseFirestore.instance
                        .collection('students')
                        .doc(studentId)
                        .update(studentUpdateData);
                  }

                  // Update in students subcollection
                  await FirebaseFirestore.instance
                      .collection('classes')
                      .doc(widget.classId)
                      .collection('students')
                      .doc(studentId)
                      .update({
                        'name': newName,
                        if (newEmail.isNotEmpty) 'email': newEmail,
                      });

                  await _loadRoster();

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("User updated")));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error updating: $e")));
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _copyClassCode(BuildContext context) {
    if (_classCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No class code available")));
      return;
    }

    Clipboard.setData(ClipboardData(text: _classCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Class code "$_classCode" copied!',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareQRCode() async {
    if (_classCode.isEmpty) return;
    // ignore: deprecated_member_use
    await Share.share(
      'Join my ICTeach class using Class Code: $_classCode',
      subject: 'ICTeach Class Code',
    );
  }

  Widget _buildQRCode(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Class QR Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan to join class',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: _classCode,
                version: QrVersions.auto,
                size: 200,
                gapless: false,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Class Code: $_classCode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyClassCode(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Code'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _shareQRCode();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF428DEB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => _buildQRCode(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.className,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_teacherName.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 12,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _teacherName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
          ],
        ),
        backgroundColor: const Color(0xFF428DEB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          SummaryPrintButton(
            title: 'Student roster - ' + widget.className,
            load: () async => [
              SummarySection(
                'Students',
                ['Name', 'Email'],
                [
                  for (final s in _students) [s['name'], s['email']],
                ],
              ),
            ],
          ),
          if (_classCode.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.qr_code_2, color: Colors.white),
              onPressed: () => _showQRCodeDialog(context),
              tooltip: 'Show QR Code',
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'qr') {
                    _showQRCodeDialog(context);
                  } else if (value == 'copy') {
                    _copyClassCode(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'qr',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code, size: 18, color: Color(0xFF428DEB)),
                        SizedBox(width: 8),
                        Text('Show QR Code'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18, color: Color(0xFF428DEB)),
                        SizedBox(width: 8),
                        Text('Copy Class Code'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Class Code',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _classCode.isNotEmpty ? _classCode : 'Loading...',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_classCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Text(
                                'Share with students',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_classCode.isNotEmpty) ...[
                  IconButton(
                    onPressed: () => _showQRCodeDialog(context),
                    icon: const Icon(Icons.qr_code, color: Color(0xFF428DEB)),
                    tooltip: 'QR Code',
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _copyClassCode(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF428DEB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_students.isEmpty && _trainers.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No users joined yet",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Share the class code to invite students and trainers",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_trainers.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Trainers (${_trainers.length})',
                            style: TextStyle(
                              color: Colors.purple.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '👑 Class Trainers',
                          style: TextStyle(
                            color: Colors.purple.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._trainers.map(
                    (trainer) =>
                        _buildUserCard(context, trainer, isTrainer: true),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                ],
                if (_students.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Students (${_students.length})',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '🎓 Enrolled Students',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._students.map(
                    (student) =>
                        _buildUserCard(context, student, isTrainer: false),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    Map<String, dynamic> user, {
    required bool isTrainer,
  }) {
    final userId = user['id'] ?? '';
    final name = user['name'] ?? 'Unknown User';
    final email = user['email'] ?? '';
    final data = user['data'] ?? {};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTrainer
              ? Colors.purple.shade100
              : const Color(0xFF428DEB).withValues(alpha: 0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: isTrainer
                  ? Colors.purple.shade700
                  : const Color(0xFF428DEB),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isTrainer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '👑 Trainer',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          email.isNotEmpty ? email : 'No email',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "edit",
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: Color(0xFF428DEB)),
                  SizedBox(width: 8),
                  Text("Edit"),
                ],
              ),
            ),
            const PopupMenuItem(
              value: "delete",
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Remove"),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == "edit") {
              editStudent(context, userId, data);
            } else if (value == "delete") {
              deleteStudent(context, userId);
            }
          },
        ),
      ),
    );
  }
}
