import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_router.dart';
import 'services/registration_invitation_service.dart';

class RegisterPage extends StatefulWidget {
  final Future<LrnIdentity> Function(String)? lrnVerifier;
  const RegisterPage({super.key, this.lrnVerifier});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _lrnController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _extensionController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLrnValid = false;
  bool _verifyingLrn = false;
  bool _showAccountDetails = false;
  LrnIdentity? _verifiedIdentity;
  Future<LrnIdentity> _lookupLrn(String lrn) =>
      widget.lrnVerifier?.call(lrn) ??
      RegistrationInvitationService().validateLrn(lrn);
  void _clearIdentity() {
    _isLrnValid = false;
    _showAccountDetails = false;
    _verifiedIdentity = null;
    _firstNameController.clear();
    _middleNameController.clear();
    _lastNameController.clear();
    _extensionController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  // List of values that should be treated as "no extension"
  static const List<String> _noExtensionValues = [
    'none',
    'n/a',
    'na',
    'n.a',
    'n.a.',
    'NONE',
    'None',
    'N/A',
    'null',
    'NULL',
    'Null',
    'no',
    'NO',
    'No',
    '0',
    'zero',
    'ZERO',
    'none.',
    'NONE.',
    'None.',
    'NA',
    'Na',
  ];

  @override
  void dispose() {
    _lrnController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _extensionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ Check if string contains emojis or special symbols
  bool _containsEmoji(String text) {
    // Unicode ranges for emojis and symbols - Fixed regex
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]'
      r'|[\u{1F300}-\u{1F5FF}]'
      r'|[\u{1F680}-\u{1F6FF}]'
      r'|[\u{1F700}-\u{1F77F}]'
      r'|[\u{1F780}-\u{1F7FF}]'
      r'|[\u{1F800}-\u{1F8FF}]'
      r'|[\u{1F900}-\u{1F9FF}]'
      r'|[\u{1FA00}-\u{1FA6F}]'
      r'|[\u{1FA70}-\u{1FAFF}]'
      r'|[\u{2600}-\u{26FF}]'
      r'|[\u{2700}-\u{27BF}]'
      r'|[\u{FE00}-\u{FEFF}]'
      r'|[\u{1F1E6}-\u{1F1FF}]'
      r'|[\u{1F200}-\u{1F2FF}]'
      r'|[\u{1F0A0}-\u{1F0FF}]'
      r'|[\u{1F004}-\u{1F004}]'
      r'|[\u{1F550}-\u{1F567}]'
      r'|[\u{1F5E8}-\u{1F5E8}]'
      r'|[\u{1FA70}-\u{1FAFF}]'
      r'|[\u{1FBC0}-\u{1FBFF}]'
      r'|[\u{1F000}-\u{1F02F}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(text);
  }

  // ✅ Check if string contains special characters (for names)
  bool _containsSpecialCharacters(String text) {
    // Allow letters, spaces, hyphens, apostrophes, and periods
    final regex = RegExp(r"^[a-zA-Z\s\-.']+$");
    return !regex.hasMatch(text);
  }

  // ✅ Check if string contains numbers
  bool _containsNumbers(String text) {
    return RegExp(r'\d').hasMatch(text);
  }

  // ✅ Strong password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter.';
    }

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter.';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number.';
    }

    // Check for at least one special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character (!@#\$%^&*).';
    }

    return null;
  }

  // ✅ Validate name fields
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return '$fieldName must be at least 2 characters.';
    }

    if (trimmed.length > 50) {
      return '$fieldName must be less than 50 characters.';
    }

    if (_containsEmoji(trimmed)) {
      return 'Emojis are not allowed in $fieldName.';
    }

    if (_containsSpecialCharacters(trimmed)) {
      return 'Only letters, spaces, hyphens, apostrophes, and periods are allowed.';
    }

    if (_containsNumbers(trimmed)) {
      return 'Numbers are not allowed in $fieldName.';
    }

    return null;
  }

  // Function to clean extension value
  String _cleanExtension(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return '';

    if (_noExtensionValues.contains(trimmed.toLowerCase())) {
      return '';
    }

    if (RegExp(r'^[^a-zA-Z]+$').hasMatch(trimmed)) {
      return '';
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return '';
    }

    if (trimmed.length == 1 &&
        !['J', 'S', 'R', 'V', 'X', 'Z'].contains(trimmed.toUpperCase())) {
      return '';
    }

    return _capitalizeExtension(trimmed);
  }

  String _capitalizeExtension(String value) {
    final suffixes = {
      'jr': 'Jr.',
      'jr.': 'Jr.',
      'sr': 'Sr.',
      'sr.': 'Sr.',
      'i': 'I',
      'ii': 'II',
      'iii': 'III',
      'iv': 'IV',
      'v': 'V',
      'vi': 'VI',
      'vii': 'VII',
      'viii': 'VIII',
      'ix': 'IX',
      'x': 'X',
    };

    final lower = value.toLowerCase();
    if (suffixes.containsKey(lower)) {
      return suffixes[lower]!;
    }

    if (RegExp(
      r'^(Jr\.|Sr\.|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII)$',
    ).hasMatch(value)) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String? _validateExtension(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final cleaned = _cleanExtension(value);
    if (cleaned.isEmpty) {
      return null;
    }

    if (_containsEmoji(cleaned)) {
      return 'Emojis are not allowed in extension.';
    }

    final validPatterns = [
      r'^(Jr\.|Sr\.|I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV)$',
      r'^[A-Z][a-z]?\.?$',
      r'^[A-Z]{2,3}$',
    ];

    for (final pattern in validPatterns) {
      if (RegExp(pattern).hasMatch(cleaned)) {
        return null;
      }
    }

    return 'Please enter a valid suffix (e.g., Jr., Sr., III) or leave blank.';
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
  }

  Future<void> _validateLRN() async {
    final lrn = _lrnController.text.trim();
    if (!RegExp(r'^[0-9]{12}$').hasMatch(lrn)) {
      _showError('Enter a valid 12-digit LRN.');
      return;
    }
    setState(() {
      _verifyingLrn = true;
      _clearIdentity();
    });
    try {
      final identity = await _lookupLrn(lrn);
      if (!mounted || _lrnController.text.trim() != lrn) return;
      setState(() {
        _verifiedIdentity = identity;
        _isLrnValid = true;
        _showAccountDetails = true;
        _firstNameController.text = identity.firstName;
        _middleNameController.text = identity.middleName;
        _lastNameController.text = identity.lastName;
        _extensionController.text = identity.extension;
      });
      _showSnackBar(
        'LRN verified against the school master list.',
        Colors.green,
      );
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } on FirebaseException catch (e) {
      if (mounted) _showError(_firebaseErrorMessage(e));
    } catch (_) {
      if (mounted)
        _showError(
          'Could not verify your LRN. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _verifyingLrn = false);
    }
  }

  Widget _buildLrnField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _lrnController,
          enabled: !_isLoading && !_verifyingLrn,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: const InputDecoration(
            labelText: 'Learning Reference Number (LRN)',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (!RegExp(r'^[0-9]{12}$').hasMatch(value?.trim() ?? '')) {
              return 'Enter your 12-digit LRN.';
            }
            return _isLrnValid ? null : 'Verify your LRN first.';
          },
          onChanged: (_) => setState(_clearIdentity),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _isLoading || _verifyingLrn ? null : _validateLRN,
          icon: Icon(_isLrnValid ? Icons.verified : Icons.fact_check_outlined),
          label: Text(
            _verifyingLrn
                ? 'Checking school record?'
                : _isLrnValid
                ? 'LRN verified'
                : 'Verify LRN',
          ),
        ),
      ],
    );
  }

  Future<UserCredential> _createVerifiedAccount() async {
    final current = await _lookupLrn(_lrnController.text.trim());
    if (_verifiedIdentity == null ||
        !current.matchesProfile(_verifiedIdentity!.profileFields)) {
      throw const FormatException(
        'The school record changed. Verify your LRN again.',
      );
    }
    final auth = FirebaseAuth.instance;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      try {
        await RegistrationInvitationService().validateLrn(
          _lrnController.text.trim(),
        );
      } catch (_) {
        await credential.user?.delete();
        rethrow;
      }
      return credential;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      // Recover an Auth account left by an interrupted Firestore claim.
      // Never overwrite an existing enrolled profile.
      final credential = await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get(const GetOptions(source: Source.server));
      if (profile.exists) {
        await auth.signOut();
        throw FirebaseAuthException(code: 'email-already-in-use');
      }
      await RegistrationInvitationService().validateLrn(
        _lrnController.text.trim(),
      );
      return credential;
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential =
          // Verify again against the server BEFORE creating the Auth account.
          await _createVerifiedAccount();

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Account was created, but user data was not returned.',
        );
      }

      final lrn = _lrnController.text.trim();
      final firstName = _verifiedIdentity!.firstName;
      final middleName = _verifiedIdentity!.middleName;
      final lastName = _verifiedIdentity!.lastName;
      final extension = _verifiedIdentity!.extension;
      final email = _emailController.text.trim();

      final displayName = _displayName(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        extension: extension,
      );

      await _saveUserProfile(
        uid: user.uid,
        lrn: lrn,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        extension: extension,
        displayName: displayName,
        email: email,
      );
      // A display-name failure must not turn a committed enrollment into failure.
      try {
        await user.updateDisplayName(displayName);
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );
      _openHome();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showError(_authErrorMessage(error));
    } on FormatException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(_firebaseErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      _showError('Could not create account: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email registration is not enabled.';
      case 'configuration-not-found':
        return 'Firebase Auth is not configured. Enable Email/Password sign-in in Firebase Console.';
      case 'weak-password':
        return 'Password is too weak. It must be at least 8 characters with uppercase, lowercase, number, and special character.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'missing-user':
        return error.message ?? 'Account could not be completed.';
      default:
        return '${error.code}: ${error.message ?? 'Please try again.'}';
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'The school verification service denied access. Contact the school to enable LRN verification; no name or enrollment has been accepted.';
      case 'unavailable':
        return 'Firebase is unavailable right now. Please try again.';
      default:
        return '${error.plugin}/${error.code}: ${error.message ?? 'Please try again.'}';
    }
  }

  bool _isValidEmail(String value) {
    // More strict email validation
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(value);
  }

  String _displayName({
    required String firstName,
    required String middleName,
    required String lastName,
    required String extension,
  }) {
    final names = [
      firstName,
      if (middleName.isNotEmpty) middleName,
      lastName,
      if (extension.isNotEmpty) extension,
    ];
    return names.join(' ');
  }

  void _openHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeRouter()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2F80ED);
    const registerGreen = Color(0xFF12A150);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width >= 600 ? 48.0 : 22.0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                _RegisterHeader(availableWidth: width),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            24,
                            horizontalPadding,
                            24,
                          ),
                          child: AbsorbPointer(
                            absorbing: _isLoading,
                            child: _buildForm(registerGreen),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(Color registerGreen) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Account',
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Join ICTeach and start learning',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.56),
              fontSize: 15,
            ),
          ),
          // ✅ Password Requirements Info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password must be 8+ characters with uppercase, lowercase, number, and special character.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildLrnField(),
          if (!_showAccountDetails) ...[
            const SizedBox(height: 12),
            const Text(
              'Verify your LRN to load the official name from the school master list before continuing.',
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'These names come from the school master list and cannot be changed here. If they are incorrect, contact the school before continuing.',
              ),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'First Name',
              controller: _firstNameController,
              readOnly: true,
              hintText: 'Juan',
              icon: Icons.person_outline_rounded,
              validator: (value) => _validateName(value, 'First name'),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'Middle Name',
              controller: _middleNameController,
              readOnly: true,
              hintText: 'Santos',
              icon: Icons.person_outline_rounded,
              isRequired: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return _validateName(value, 'Middle name');
              },
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'Last Name',
              controller: _lastNameController,
              readOnly: true,
              hintText: 'Dela Cruz',
              icon: Icons.person_outline_rounded,
              validator: (value) => _validateName(value, 'Last name'),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'Extension (Optional)',
              controller: _extensionController,
              readOnly: true,
              hintText: 'Jr., Sr., III',
              icon: Icons.person_add_alt_1_outlined,
              validator: _validateExtension,
              isRequired: false,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'Email Address',
              controller: _emailController,
              hintText: 'student@school.edu.ph',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email address is required.';
                if (_containsEmoji(email)) {
                  return 'Emojis are not allowed in email.';
                }
                if (!_isValidEmail(email))
                  return 'Enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildPasswordField(
              label: 'Password',
              controller: _passwordController,
              isObscured: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: _validatePassword,
            ),
            const SizedBox(height: 18),
            _buildPasswordField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              isObscured: _obscureConfirmPassword,
              onToggle: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password.';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _isLoading ? null : _register(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: registerGreen,
                  disabledBackgroundColor: registerGreen.withValues(
                    alpha: 0.55,
                  ),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.6,
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Already have an account? Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isRequired = true,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          readOnly: readOnly,
          validator: readOnly
              ? (_) => _isLrnValid
                    ? null
                    : 'Verify your LRN to load your official name.'
              : validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF4D89FF)),
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC7D3EA), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC7D3EA), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2F80ED), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5484D), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5484D), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isObscured,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isObscured,
          textInputAction: onFieldSubmitted != null
              ? TextInputAction.done
              : TextInputAction.next,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF4D89FF),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isObscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.black.withValues(alpha: 0.7),
              ),
              onPressed: onToggle,
            ),
            hintText: label == 'Password'
                ? 'Create a strong password'
                : 'Re-enter your password',
            hintStyle: const TextStyle(color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC7D3EA), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC7D3EA), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2F80ED), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5484D), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5484D), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _saveUserProfile({
    required String uid,
    required String lrn,
    required String firstName,
    required String middleName,
    required String lastName,
    required String extension,
    required String displayName,
    required String email,
  }) async {
    final data = <String, dynamic>{
      'uid': uid,
      'lrn': lrn,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'extension': extension,
      'displayName': displayName,
      'name': displayName,
      'email': email,
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await RegistrationInvitationService().claim(
      uid: uid,
      lrn: lrn,
      profile: data,
    );
    return true;
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader({required this.availableWidth});

  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final logoSize = (availableWidth * 0.22).clamp(82.0, 126.0);
    final titleSize = (availableWidth * 0.082).clamp(31.0, 42.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Image.asset(
            'assets/logo 2.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: logoSize,
                height: logoSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF2F80ED),
                  size: 50,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'ICTeach',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TVL-ICT Learning Management System',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: availableWidth >= 600 ? 16 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
