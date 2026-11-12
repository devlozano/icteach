import '../services/principal_assignments.dart';
import 'staff_assignment_fields.dart';
import 'package:firebase_core/firebase_core.dart';
import '../utils/staff_password.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:icteach/emailjs_service.dart';
import '../widgets/principal_workspace_shell.dart';

class CreateStaffPage extends StatefulWidget {
  final String? selectedRole;

  const CreateStaffPage({super.key, this.selectedRole});

  @override
  State<CreateStaffPage> createState() => _CreateStaffPageState();
}

class _CreateStaffPageState extends State<CreateStaffPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _extensionController = TextEditingController();
  final _emailController = TextEditingController();

  late String _selectedRole;
  bool _isLoading = false;
  StaffAssignmentDraft _assignments = StaffAssignmentDraft();
  String? _createdStaffId, _pendingPassword;
  bool _assignmentsSaved = false;
  int _formRevision = 0;

  String get _accountLabel => _selectedRole == 'trainer'
      ? 'Trainer Account'
      : _selectedRole == 'teacher'
      ? 'Teacher Account'
      : 'User';

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.selectedRole ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _extensionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String getMiddleInitial(String middleName) {
    return middleName.trim().isEmpty
        ? ''
        : '${middleName.trim()[0].toUpperCase()}.';
  }

  String generatePassword() => generateStaffPassword();

  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<UserCredential> createStaffAccount({
    required String email,
    required String password,
  }) async {
    final app = await Firebase.initializeApp(
      name: 'staff-creation-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      return await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } finally {
      try {
        await auth.signOut();
      } finally {
        await app.delete();
      }
    }
  }

  // ✅ NEW: Reset form method
  void _resetForm() {
    _createdStaffId = null;
    _pendingPassword = null;
    _assignmentsSaved = false;
    _assignments = StaffAssignmentDraft();
    _formRevision++;
    _formKey.currentState?.reset();
    _firstNameController.clear();
    _middleNameController.clear();
    _lastNameController.clear();
    _extensionController.clear();
    _emailController.clear();
    setState(() {
      _selectedRole = widget.selectedRole ?? '';
    });
  }

  Future<void> _createStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await PrincipalAssignments().requirePrincipal();
      final tempPassword = _pendingPassword ??= generatePassword();

      if (tempPassword.length < 6) {
        throw Exception("Password too short for Firebase");
      }

      final first = _firstNameController.text.trim();
      final middle = _middleNameController.text.trim();
      final last = _lastNameController.text.trim();
      final ext = _extensionController.text.trim();
      final email = _emailController.text.trim();

      if (email.isEmpty || !email.contains('@')) {
        throw Exception("Invalid email address");
      }

      final middleInitial = getMiddleInitial(middle);

      final displayName = [
        first,
        middleInitial,
        last,
        ext,
      ].where((e) => e.isNotEmpty).join(' ');

      if (_createdStaffId == null) {
        final credential = await createStaffAccount(
          email: email,
          password: tempPassword,
        );
        _createdStaffId = credential.user!.uid;
      }
      final uid = _createdStaffId!;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': first,
        'middleName': middle,
        'middleInitial': middleInitial,
        'lastName': last,
        'extension': ext,
        'name': displayName,
        'email': email,
        'role': _selectedRole,
        'mustChangePassword': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!_assignmentsSaved) {
        await PrincipalAssignments().save(uid, _selectedRole, _assignments);
        _assignmentsSaved = true;
      }

      await EmailJSService.sendStaffCredentials(
        email: email,
        name: displayName,
        role: _selectedRole.toUpperCase(),
        password: tempPassword,
      );

      if (!mounted) return;

      // ✅ FIXED: Show dialog with proper OK button behavior
      await showDialog(
        context: context,
        barrierDismissible: false, // ✅ Prevents closing by tapping outside
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_selectedRole == 'trainer' ? 'Trainer' : 'Teacher'} Created',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account created for ${_selectedRole.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A temporary-password email was sent to $email.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // ✅ Close the dialog
                  Navigator.of(context).pop();
                  // ✅ Reset the form after dialog closes
                  _resetForm();
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2F80ED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          );
        },
      );

      // ✅ Additional reset after dialog (in case of issues)
      if (mounted) _resetForm();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Auth error occurred')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrincipalDetailScaffold(
      title: 'Add user',
      subtitle: 'Create a teacher or trainer account and assign their work.',
      icon: Icons.person_add_alt_1_rounded,
      maxWidth: 860,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFDCE4EC)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Account information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2B4A),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Start by choosing a role. The required assignment fields will appear below.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole.isEmpty ? null : _selectedRole,
                  validator: (v) =>
                      v == null ? 'Choose Teacher or Trainer.' : null,
                  decoration: fieldDecoration(hint: 'Role', icon: Icons.badge),
                  items: const [
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'trainer', child: Text('Trainer')),
                  ],
                  onChanged: _isLoading || _createdStaffId != null
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() {
                              _selectedRole = v;
                              _assignments = StaffAssignmentDraft();
                              _formRevision++;
                            });
                          }
                        },
                ),
                const SizedBox(height: 16),
                if (_selectedRole.isNotEmpty) ...[
                  TextFormField(
                    enabled: !_isLoading && _createdStaffId == null,
                    controller: _firstNameController,
                    decoration: fieldDecoration(
                      hint: 'First Name',
                      icon: Icons.person,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    enabled: !_isLoading && _createdStaffId == null,
                    controller: _middleNameController,
                    decoration: fieldDecoration(
                      hint: 'Middle Name',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    enabled: !_isLoading && _createdStaffId == null,
                    controller: _lastNameController,
                    decoration: fieldDecoration(
                      hint: 'Last Name',
                      icon: Icons.person_outline,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    enabled: !_isLoading && _createdStaffId == null,
                    controller: _extensionController,
                    decoration: fieldDecoration(
                      hint: 'Extension (Jr., Sr., III)',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    enabled: !_isLoading && _createdStaffId == null,
                    controller: _emailController,
                    decoration: fieldDecoration(
                      hint: 'Email Address',
                      icon: Icons.email,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 20),
                  if (_selectedRole.isNotEmpty)
                    StaffAssignmentFields(
                      key: ValueKey('$_selectedRole-$_formRevision'),
                      role: _selectedRole,
                      draft: _assignments,
                      enabled: !_isLoading && !_assignmentsSaved,
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createStaff,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2B4A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Create $_accountLabel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
