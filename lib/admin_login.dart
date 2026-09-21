import 'services/workspace_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_router.dart';
import 'services/network_service.dart';
import 'services/session_service.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _rememberMe = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    SessionService.remembersUser().then((value) {
      if (mounted) setState(() => _rememberMe = value);
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInAdmin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final isConnected = await NetworkService().isConnected();
    if (!isConnected) {
      _showError(
        'You appear to be offline. Please connect to the internet to log in.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SessionService.configure(_rememberMe);
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'No user returned.',
        );
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role']?.toString().toLowerCase() ?? '';
      const webRoles = {'admin', 'teacher', 'trainer'};
      if (!webRoles.contains(role)) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showError(
          role == 'student'
              ? 'Student accounts are available in the ICTeach mobile app only.'
              : 'This account does not have access to an ICTeach web dashboard.',
        );
        return;
      }

      await WorkspaceNavigation.instance.startFreshSession(user.uid);
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signed in as $role.')));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeRouter()),
        (r) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed.');
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'Firebase error.');
    } catch (e) {
      _showError('Could not sign in: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF071B2D),
        body: Stack(
          children: [
            const Positioned.fill(child: _LoginBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = kIsWeb && constraints.maxWidth >= 900;
                  final content = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 48 : 20,
                        vertical: wide ? 28 : 20,
                      ),
                      child: wide
                          ? Row(
                              children: [
                                const Expanded(child: _PortalIntroduction()),
                                const SizedBox(width: 64),
                                SizedBox(width: 440, child: _buildLoginCard()),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _CompactBrand(),
                                const SizedBox(height: 20),
                                _buildLoginCard(),
                                const SizedBox(height: 18),
                                const _Copyright(),
                              ],
                            ),
                    ),
                  );

                  if (wide && constraints.maxHeight >= 690) {
                    return Center(child: content);
                  }

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Center(child: content),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: Color(0xFF1769C2),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'SECURE PORTAL',
                        style: TextStyle(
                          color: Color(0xFF1769C2),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue to your ICTeach workspace.',
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                _fieldLabel('Email address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Email is required.';
                    if (!_isValidEmail(email)) return 'Enter a valid email.';
                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: 'name@school.edu.ph',
                    icon: Icons.alternate_email_rounded,
                  ),
                ),
                const SizedBox(height: 20),
                _fieldLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _isLoading ? null : _signInAdmin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required.';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Remember me'),
                  value: _rememberMe,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _rememberMe = value ?? false),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.groups_2_outlined,
                      size: 17,
                      color: Colors.blueGrey.shade400,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Secure access to your ICTeach dashboard',
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _signInAdmin,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1769C2),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF8BB6E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Sign in to ICTeach',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.blueGrey.shade100)),
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ICTeach Learning Management System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blueGrey.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.blueGrey.shade100)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF334E68),
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF1769C2), size: 21),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF5F8FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF1769C2), width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD64545)),
    ),
  );
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071A2B),
                  Color(0xFF0E3554),
                  Color(0xFF15577A),
                ],
                stops: [0, .55, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: -160,
          top: -190,
          child: _BackgroundGlow(
            size: 520,
            color: const Color(0xFF16C5D7).withValues(alpha: .13),
          ),
        ),
        Positioned(
          right: -130,
          bottom: -210,
          child: _BackgroundGlow(
            size: 560,
            color: const Color(0xFF3988FF).withValues(alpha: .14),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _CircuitBackdropPainter()),
          ),
        ),
      ],
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _CircuitBackdropPainter extends CustomPainter {
  const _CircuitBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final accentPaint = Paint()
      ..color = const Color(0xFF67E8F9).withValues(alpha: .12)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final nodePaint = Paint()
      ..color = const Color(0xFF8BE8F0).withValues(alpha: .20);

    for (double x = 48; x < size.width; x += 96) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 42; y < size.height; y += 84) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final traces = <Path>[
      Path()
        ..moveTo(0, size.height * .24)
        ..lineTo(size.width * .18, size.height * .24)
        ..lineTo(size.width * .24, size.height * .32)
        ..lineTo(size.width * .43, size.height * .32),
      Path()
        ..moveTo(size.width, size.height * .18)
        ..lineTo(size.width * .82, size.height * .18)
        ..lineTo(size.width * .76, size.height * .28)
        ..lineTo(size.width * .66, size.height * .28),
      Path()
        ..moveTo(size.width * .08, size.height)
        ..lineTo(size.width * .08, size.height * .78)
        ..lineTo(size.width * .16, size.height * .68)
        ..lineTo(size.width * .32, size.height * .68),
    ];
    for (final trace in traces) {
      canvas.drawPath(trace, accentPaint);
    }

    for (final point in [
      Offset(size.width * .43, size.height * .32),
      Offset(size.width * .66, size.height * .28),
      Offset(size.width * .32, size.height * .68),
    ]) {
      canvas.drawCircle(point, 3.5, nodePaint);
      canvas.drawCircle(point, 8, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PortalIntroduction extends StatelessWidget {
  const _PortalIntroduction();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!kIsWeb)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'URDANETA CITY UNIVERSITY  •  ICT DEPARTMENT',
                style: TextStyle(
                  color: Color(0xFFBFE9EC),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ),
          const SizedBox.shrink(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 22, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .075),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandLogo(size: 76),
                Container(
                  width: 1,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: Colors.white.withValues(alpha: .18),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ICTeach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'LEARNING MANAGEMENT SYSTEM',
                      style: TextStyle(
                        color: Color(0xFF9AC7EE),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 46),
          const Text(
            'Build skills.\nPractice safely.\nTeach with insight.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.16,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 570,
            child: Text(
              'A structured workspace for competency-based instruction, practical simulations, assessment, and learner progress.',
              style: TextStyle(
                color: Color(0xFFC8DCEB),
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 34),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeaturePill(Icons.memory_rounded, 'Interactive simulations'),
              _FeaturePill(Icons.insights_rounded, 'Progress insights'),
              _FeaturePill(Icons.school_rounded, 'Role-based workspace'),
            ],
          ),
          const SizedBox(height: 54),
          const _Copyright(),
        ],
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandLogo(size: 54),
          SizedBox(width: 13),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ICTeach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'LEARNING MANAGEMENT SYSTEM',
                  style: TextStyle(
                    color: Color(0xFF9AC7EE),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF8FF)],
        ),
        borderRadius: BorderRadius.circular(size * .25),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: .28),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .18),
        child: Image.asset('assets/ict_logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7CC8FF), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Copyright extends StatelessWidget {
  const _Copyright();

  @override
  Widget build(BuildContext context) {
    return Text(
      '\u00A9 2026 ICTeach. All rights reserved.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.52),
        fontSize: 11,
      ),
    );
  }
}
