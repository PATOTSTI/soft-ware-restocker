// ignore_for_file: use_build_context_synchronously, avoid_types_as_parameter_names, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReStckr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Wrong password provided.');
      } else {
        throw Exception(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      throw Exception('An unknown error occurred');
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Check if user is already signed in
      final GoogleSignInAccount? currentUser =
          await googleSignIn.signInSilently();
      if (currentUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await currentUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
        return true;
      }

      // If not signed in, start the sign-in flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase authentication failed: ${e.message}');
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<bool> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status == LoginStatus.success) {
        final OAuthCredential facebookAuthCredential =
            FacebookAuthProvider.credential(result.accessToken!.token);
        await _auth.signInWithCredential(facebookAuthCredential);
        return true;
      } else {
        throw Exception('Facebook sign-in cancelled');
      }
    } catch (e) {
      throw Exception('Failed to sign in with Facebook: ${e.toString()}');
    }
  }

  Future<bool> resetPassword(String email) async {
    if (!EmailValidator.validate(email)) {
      throw Exception('Invalid email format');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      throw Exception('Failed to send password reset email');
    }
  }

  Future<bool> signUp(String email, String password, String fullName) async {
    if (!EmailValidator.validate(email)) {
      throw Exception('Invalid email format');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    if (fullName.trim().isEmpty) {
      throw Exception('Full name is required');
    }

    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Optionally update user display name
      await userCredential.user?.updateDisplayName(fullName);
      await userCredential.user?.reload();

      return true;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during sign up');
    } catch (e) {
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final success = await _authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        if (success && mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await _authService.signInWithGoogle();
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFacebookSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await _authService.signInWithFacebook();
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(76, 175, 80, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.08,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Logo
                    Image.asset(
                      'lib/assets/logo.png',
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shopping_bag_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // App Name
                    const Text(
                      'ReStckr',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your companion in everyday shopping.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    // Login Form
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Log in to access your grocery lists\nand more.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            onTap: () {
                              _emailController
                                  .selection = TextSelection.fromPosition(
                                TextPosition(
                                  offset: _emailController.text.length,
                                ),
                              );
                            },
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!EmailValidator.validate(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onTap: () {
                              _passwordController
                                  .selection = TextSelection.fromPosition(
                                TextPosition(
                                  offset: _passwordController.text.length,
                                ),
                              );
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          // Login Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text('LOGIN'),
                          ),
                          const SizedBox(height: 16),
                          // Forgot Password
                          Center(
                            child: TextButton(
                              onPressed:
                                  () => Navigator.pushNamed(
                                    context,
                                    '/forgot-password',
                                  ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ),
                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?"),
                              TextButton(
                                onPressed: () => navigateWithFade(context, const SignUpPage()),
                                child: const Text(
                                  'Sign up',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Social Login Divider
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Sign in with'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Social Login Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed:
                                    _isLoading ? null : _handleFacebookSignIn,
                                icon: const FaIcon(
                                  FontAwesomeIcons.facebook,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed:
                                    _isLoading ? null : _handleGoogleSignIn,
                                icon: const FaIcon(
                                  FontAwesomeIcons.google,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final success = await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _fullNameController.text.trim(),
        );
        if (!mounted) return;
        if (success) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Colors.orange; // Use your app's accent color
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.08,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 2),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 60,
                        color: Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sign Up Text
                    const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your account',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    // Full Name Field
                    TextFormField(
                      controller: _fullNameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!EmailValidator.validate(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: accentColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm your password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: accentColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'SIGN UP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final success = await _authService.resetPassword(
          _emailController.text.trim(),
        );

        if (!mounted) return;
        if (success) {
          setState(() => _emailSent = true);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(76, 175, 80, 1),
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Enter your email address and we\'ll send you instructions to reset your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                    if (_emailSent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Check Your Email',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Password reset instructions have been sent to your email.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Back to Login'),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!EmailValidator.validate(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _handleResetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Text('SEND RESET LINK'),
                            ),
                          ],
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<PurchaseHistory> _purchaseHistory = [];
  final Map<String, List<CartItem>> _cartItems = {};
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadPurchaseHistory();
    _loadStockDataToCartItems();
    _loadCartFromFirestore();
  }

  Future<void> _saveCartToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc('cart_data');
      // Save as a flat list of items
      final List<Map<String, dynamic>> cartList = [];
      _cartItems.forEach((section, items) {
        for (var item in items) {
          cartList.add({
            'section': section,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
          });
        }
      });
      await docRef.set({'cart': cartList});
    } catch (e) {
      // Optionally show error
    }
  }

  Future<void> _loadCartFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc('cart_data');
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final cartList = data['cart'] as List<dynamic>?;
        if (cartList != null) {
          setState(() {
            _cartItems.clear();
            for (var entry in cartList) {
              final section = entry['section'] as String;
              if (!_cartItems.containsKey(section)) {
                _cartItems[section] = [];
              }
              _cartItems[section]!.add(
                CartItem(
                  name: entry['name'],
                  quantity: entry['quantity'],
                  price: (entry['price'] as num).toDouble(),
                  section: section,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      // Optionally show error
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void addToCart(String section, String itemName, double price) {
    setState(() {
      if (!_cartItems.containsKey(section)) {
        _cartItems[section] = [];
      }

      var existingItem = _cartItems[section]!.firstWhere(
        (item) => item.name == itemName,
        orElse:
            () => CartItem(
              name: itemName,
              quantity: 0,
              price: price,
              section: section,
            ),
      );

      if (existingItem.quantity == 0) {
        // New item
        existingItem = CartItem(
          name: itemName,
          quantity: 1,
          price: price,
          section: section,
        );
        _cartItems[section]!.add(existingItem);
      } else {
        // Existing item
        existingItem.quantity++;
      }

      _saveCartToFirestore(); // Save cart after change

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $itemName to cart'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  void _handleQuantityChange(
    String section,
    String itemName,
    int newQuantity,
    double price,
  ) {
    setState(() {
      // Find or create the section
      if (!_cartItems.containsKey(section)) {
        _cartItems[section] = [];
      }

      // Find the item in cart items
      final cartSection = _cartItems[section]!;
      final existingItemIndex = cartSection.indexWhere(
        (item) => item.name == itemName,
      );

      if (existingItemIndex != -1) {
        // Update existing item
        final item = cartSection[existingItemIndex];
        item.quantity = newQuantity;
        item.price = price;

        // If quantity is 0, remove from cart
        if (newQuantity == 0) {
          cartSection.removeAt(existingItemIndex);
          if (cartSection.isEmpty) {
            _cartItems.remove(section);
          }
        }
      } else if (newQuantity > 0) {
        // Add new item
        cartSection.add(
          CartItem(
            name: itemName,
            quantity: newQuantity,
            price: price,
            section: section,
          ),
        );
      }
      _saveCartToFirestore(); // Save cart after change
    });
  }

  void _confirmPurchase() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create a map of all items and their quantities
    Map<String, int> purchasedItems = {};
    for (var section in _cartItems.entries) {
      for (var item in section.value) {
        purchasedItems[item.name] = item.quantity;
      }
    }

    // Add to purchase history
    final purchase = PurchaseHistory(
      date: DateTime.now(),
      amount: _calculateTotal(),
      items: purchasedItems,
    );

    setState(() {
      _purchaseHistory.add(purchase);
      // Do NOT clear cart here
    });

    _savePurchaseHistory(); // Save to Firestore
    // Do NOT clear cart in Firestore here

    // Show confirmation dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Purchase Confirmed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount: Php ${purchase.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Items purchased:'),
                const SizedBox(height: 4),
                ...purchasedItems.entries.map(
                  (entry) => Text('• ${entry.key} (${entry.value}x)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _handleLogout() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.blue),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Edit Profile functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile tapped')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6, color: Colors.amber),
              title: const Text('Change Theme'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Theme Toggle
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Change Theme tapped')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.deepPurple),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Notifications Toggle
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications tapped')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.green),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show Privacy Policy
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy Policy tapped')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show About Dialog
                showAboutDialog(
                  context: context,
                  applicationName: 'ReStckr',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Developed by Your Name',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.teal),
              title: const Text('Contact Support'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Contact Support (e.g., open email)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact Support tapped')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Implement Delete Account
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deletion not implemented.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
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

  double _calculateTotal() {
    double total = 0;
    for (var section in _cartItems.entries) {
      for (var item in section.value) {
        total += item.price * item.quantity;
      }
    }
    return total;
  }

  String get _title {
    switch (_selectedIndex) {
      case 0:
        return 'Stocks';
      case 1:
        return 'Cart';
      case 2:
        return 'Activity';
      case 3:
        return 'Events';
      default:
        return '';
    }
  }

  IconData get _titleIcon {
    switch (_selectedIndex) {
      case 0:
        return Icons.inventory_2_outlined;
      case 1:
        return Icons.shopping_bag_outlined;
      case 2:
        return Icons.history;
      case 3:
        return Icons.calendar_today;
      default:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [Icon(_titleIcon), const SizedBox(width: 8), Text(_title)],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: null),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          StocksPage(
            cartItems: _cartItems,
            onAddToCart: addToCart,
            onQuantityChange: _handleQuantityChange,
            onStockUpdate: _updateCartFromStock,
          ),
          CartPage(
            cartItems: _cartItems,
            onConfirmPurchase: _confirmPurchase,
            onClearCart: _clearCart, // Pass the clear cart callback
          ),
          ActivityPage(
            purchaseHistory: _purchaseHistory,
            cartItems: _cartItems,
          ),
          const EventsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stocks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Activity'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Events',
          ),
        ],
      ),
    );
  }

  Future<void> _loadPurchaseHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity')
          .doc('purchase_history');
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> historyList = data['history'] ?? [];
        setState(() {
          _purchaseHistory.clear();
          for (var entry in historyList) {
            _purchaseHistory.add(
              PurchaseHistory(
                date: DateTime.parse(entry['date']),
                amount: (entry['amount'] as num).toDouble(),
                items: Map<String, int>.from(entry['items'] ?? {}),
              ),
            );
          }
        });
      }
    } catch (e) {
      // Optionally show error
    }
  }

  Future<void> _savePurchaseHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity')
          .doc('purchase_history');
      final historyList =
          _purchaseHistory
              .map(
                (purchase) => {
                  'date': purchase.date.toIso8601String(),
                  'amount': purchase.amount,
                  'items': purchase.items,
                },
              )
              .toList();
      await docRef.set({'history': historyList});
    } catch (e) {
      // Optionally show error
    }
  }

  // Add this method to update activity when stock changes

  Future<void> _loadStockDataToCartItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data');
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _cartItems.clear();
          data.forEach((section, items) {
            _cartItems[section] =
                List<Map<String, dynamic>>.from(items)
                    .map(
                      (item) => CartItem(
                        name: item['name'],
                        quantity: item['quantity'],
                        price: (item['price'] as num).toDouble(),
                        section: section,
                      ),
                    )
                    .toList();
          });
        });
      }
    } catch (e) {
      // Optionally show error
    }
  }

  // Add this method to update cart and persist it when stock changes
  void _updateCartFromStock(Map<String, List<CartItem>> updatedStock) {
    setState(() {
      _cartItems.clear();
      _cartItems.addAll(updatedStock);
    });
    _saveCartToFirestore(); // Save the updated cart to Firestore
  }

  // In HomePage, add the clear cart method
  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
    _saveCartToFirestore();
  }
}

class StocksPage extends StatefulWidget {
  final Map<String, List<CartItem>> cartItems;
  final Function(String section, String itemName, double price) onAddToCart;
  final Function(
    String section,
    String itemName,
    int newQuantity,
    double price,
  )?
  onQuantityChange;
  final Function(Map<String, List<CartItem>>)?
  onStockUpdate; // Add this callback

  const StocksPage({
    super.key,
    required this.cartItems,
    required this.onAddToCart,
    this.onQuantityChange,
    this.onStockUpdate,
  });

  @override
  State<StocksPage> createState() => _StocksPageState();
}

class _StocksPageState extends State<StocksPage> {
  final Map<String, List<Map<String, dynamic>>> _sectionItems = {
    'Bakery & Bread': [],
    'Dairy': [],
    'Meat': [],
    'Seafood': [],
    'Frozen Foods': [],
    'Snacks': [],
  };

  final Map<String, bool> _expandedSections = {
    'Bakery & Bread': true,
    'Dairy': true,
    'Meat': false,
    'Seafood': false,
    'Frozen Foods': false,
    'Snacks': false,
  };

  Future<void> _prePopulateStockItems() async {
    final Map<String, List<Map<String, dynamic>>> predefinedItems = {
      'Bakery & Bread': [
        {'name': 'White Bread', 'quantity': 10, 'price': 45.00},
        {'name': 'Whole Wheat Bread', 'quantity': 8, 'price': 55.00},
        {'name': 'Croissant', 'quantity': 15, 'price': 25.00},
        {'name': 'Baguette', 'quantity': 12, 'price': 35.00},
      ],
      'Dairy': [
        {'name': 'Fresh Milk', 'quantity': 20, 'price': 65.00},
        {'name': 'Yogurt', 'quantity': 15, 'price': 35.00},
        {'name': 'Butter', 'quantity': 10, 'price': 85.00},
        {'name': 'Cheese', 'quantity': 12, 'price': 120.00},
      ],
      'Meat': [
        {'name': 'Chicken Breast', 'quantity': 15, 'price': 180.00},
        {'name': 'Ground Beef', 'quantity': 12, 'price': 220.00},
        {'name': 'Pork Chops', 'quantity': 10, 'price': 200.00},
        {'name': 'Bacon', 'quantity': 8, 'price': 150.00},
      ],
      'Seafood': [
        {'name': 'Salmon Fillet', 'quantity': 8, 'price': 350.00},
        {'name': 'Shrimp', 'quantity': 10, 'price': 280.00},
        {'name': 'Tuna', 'quantity': 12, 'price': 150.00},
        {'name': 'Crab', 'quantity': 6, 'price': 400.00},
      ],
      'Frozen Foods': [
        {'name': 'Frozen Pizza', 'quantity': 10, 'price': 250.00},
        {'name': 'Ice Cream', 'quantity': 15, 'price': 180.00},
        {'name': 'Frozen Vegetables', 'quantity': 20, 'price': 85.00},
        {'name': 'Frozen Chicken Nuggets', 'quantity': 12, 'price': 220.00},
      ],
      'Snacks': [
        {'name': 'Potato Chips', 'quantity': 25, 'price': 45.00},
        {'name': 'Cookies', 'quantity': 20, 'price': 35.00},
        {'name': 'Crackers', 'quantity': 15, 'price': 55.00},
        {'name': 'Nuts Mix', 'quantity': 10, 'price': 120.00},
      ],
    };

    setState(() {
      _sectionItems.clear();
      _sectionItems.addAll(predefinedItems);
    });

    // Convert and notify parent immediately
    Map<String, List<CartItem>> updatedStock = {};
    _sectionItems.forEach((section, items) {
      updatedStock[section] =
          items
              .map(
                (item) => CartItem(
                  name: item['name'],
                  quantity: item['quantity'],
                  price: item['price'],
                  section: section,
                ),
              )
              .toList();
    });

    // Notify parent about stock update immediately
    if (widget.onStockUpdate != null) {
      widget.onStockUpdate!(updatedStock);
    }

    // Save to Firebase in the background
    await _saveStockData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock items have been pre-populated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  Future<void> _loadStockData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data');

      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _sectionItems.clear();
          data.forEach((section, items) {
            _sectionItems[section] = List<Map<String, dynamic>>.from(
              (items as List).map((item) => Map<String, dynamic>.from(item)),
            );
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading stock data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveStockData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data');

      await docRef.set({
        for (var entry in _sectionItems.entries) entry.key: entry.value,
      });

      // Convert _sectionItems to CartItems format and notify parent
      Map<String, List<CartItem>> updatedStock = {};
      _sectionItems.forEach((section, items) {
        updatedStock[section] =
            items
                .map(
                  (item) => CartItem(
                    name: item['name'],
                    quantity: item['quantity'],
                    price: item['price'],
                    section: section,
                  ),
                )
                .toList();
      });

      // Notify parent about stock update
      if (widget.onStockUpdate != null) {
        widget.onStockUpdate!(updatedStock);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving stock data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _isEmpty => _sectionItems.values.every((items) => items.isEmpty);

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  // Add this method to handle immediate updates
  void _updateStockImmediately(
    String section,
    Map<String, dynamic> item,
    int newQuantity,
  ) {
    setState(() {
      item['quantity'] = newQuantity;
      if (newQuantity == 0) {
        item['isOutOfStock'] = true;
      } else {
        item['isOutOfStock'] = false;
      }
    });

    // Convert current state to CartItems format and notify parent immediately
    Map<String, List<CartItem>> updatedStock = {};
    _sectionItems.forEach((section, items) {
      updatedStock[section] =
          items
              .map(
                (item) => CartItem(
                  name: item['name'],
                  quantity: item['quantity'],
                  price: item['price'],
                  section: section,
                ),
              )
              .toList();
    });

    // Notify parent about stock update immediately
    if (widget.onStockUpdate != null) {
      widget.onStockUpdate!(updatedStock);
    }

    // Save to Firebase in the background
    _saveStockData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Stock is Empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first item',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _prePopulateStockItems,
                    icon: const Icon(Icons.inventory),
                    label: const Text('Pre-populate Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _sectionItems.length,
          itemBuilder: (context, index) {
            final section = _sectionItems.keys.elementAt(index);
            final color = _getColorForSection(section);
            final items = _sectionItems[section]!;

            // Skip empty sections
            if (items.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(section, color),
                if (_expandedSections[section]!) ...[
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, itemIndex) {
                      final item = items[itemIndex];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item['name']),
                          subtitle: Text(
                            'Php ${item['price'].toStringAsFixed(2)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed:
                                    () => _showQuantityDialog(section, item),
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      item['quantity'] == 0
                                          ? Colors.red.withAlpha(26)
                                          : Colors.blue.withAlpha(26),
                                ),
                                child: Text(
                                  '${item['quantity']}',
                                  style: TextStyle(
                                    color:
                                        item['quantity'] == 0
                                            ? Colors.red
                                            : Colors.blue,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed:
                                    () => _showDeleteDialog(section, item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_item',
            onPressed: _showAddItemDialog,
            backgroundColor: Colors.green,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(_getIconForSection(title), color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            _expandedSections[title]!
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: Colors.grey,
          ),
          onPressed: () => _toggleSection(title),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          color: color,
          onPressed: () {
            // Handle section settings
          },
        ),
      ],
    );
  }

  // Modify _showQuantityDialog to use immediate updates
  void _showQuantityDialog(String section, Map<String, dynamic> item) {
    final TextEditingController quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit ${item['name']} Quantity'),
            content: TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true, // Add autofocus
              textInputAction: TextInputAction.done, // Add text input action
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
                border:
                    OutlineInputBorder(), // Add border for better visibility
              ),
              onChanged: (value) {
                // Update in real-time as user types
                final newQuantity = int.tryParse(value) ?? 0;
                _updateStockImmediately(section, item, newQuantity);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final newQuantity =
                      int.tryParse(quantityController.text) ?? 0;
                  _updateStockImmediately(section, item, newQuantity);
                  if (widget.onQuantityChange != null) {
                    widget.onQuantityChange!(
                      section,
                      item['name'],
                      newQuantity,
                      item['price'],
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  // Modify _showDeleteDialog to use immediate updates
  void _showDeleteDialog(String section, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete ${item['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _sectionItems[section]?.remove(item);
                  });

                  // Convert and notify parent immediately
                  Map<String, List<CartItem>> updatedStock = {};
                  _sectionItems.forEach((section, items) {
                    updatedStock[section] =
                        items
                            .map(
                              (item) => CartItem(
                                name: item['name'],
                                quantity: item['quantity'],
                                price: item['price'],
                                section: section,
                              ),
                            )
                            .toList();
                  });

                  // Notify parent about stock update immediately
                  if (widget.onStockUpdate != null) {
                    widget.onStockUpdate!(updatedStock);
                  }

                  // Save to Firebase in the background
                  await _saveStockData();

                  // Notify parent about item deletion with price
                  if (widget.onQuantityChange != null) {
                    widget.onQuantityChange!(
                      section,
                      item['name'],
                      0,
                      item['price'],
                    );
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item['name']} has been deleted'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Modify _showAddItemDialog to use immediate updates
  void _showAddItemDialog() {
    String selectedSection = _expandedSections.keys.first;
    final TextEditingController itemController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(
      text: '1',
    );
    final TextEditingController priceController = TextEditingController(
      text: '0.0',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Item'),
            content: SingleChildScrollView(
              // Add scrolling for smaller screens
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSection,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(), // Add border
                    ),
                    items:
                        _expandedSections.keys.map((String section) {
                          return DropdownMenuItem<String>(
                            value: section,
                            child: Text(section),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        selectedSection = newValue;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: itemController,
                    autofocus: true, // Add autofocus
                    textInputAction:
                        TextInputAction.next, // Add text input action
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'Enter item name',
                      border: OutlineInputBorder(), // Add border
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    textInputAction:
                        TextInputAction.next, // Add text input action
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(), // Add border
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    textInputAction:
                        TextInputAction.done, // Add text input action
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'Enter price',
                      prefixText: 'Php ',
                      border: OutlineInputBorder(), // Add border
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (itemController.text.isNotEmpty) {
                    final quantity = int.tryParse(quantityController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0.0;

                    setState(() {
                      _sectionItems[selectedSection]!.add({
                        'name': itemController.text,
                        'quantity': quantity,
                        'price': price,
                      });
                    });

                    // Convert and notify parent immediately
                    Map<String, List<CartItem>> updatedStock = {};
                    _sectionItems.forEach((section, items) {
                      updatedStock[section] =
                          items
                              .map(
                                (item) => CartItem(
                                  name: item['name'],
                                  quantity: item['quantity'],
                                  price: item['price'],
                                  section: section,
                                ),
                              )
                              .toList();
                    });

                    // Notify parent about stock update immediately
                    if (widget.onStockUpdate != null) {
                      widget.onStockUpdate!(updatedStock);
                    }

                    // Save to Firebase in the background
                    await _saveStockData();

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${itemController.text} added successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  IconData _getIconForSection(String section) {
    switch (section) {
      case 'Bakery & Bread':
        return Icons.bakery_dining;
      case 'Dairy':
        return Icons.water_drop_outlined;
      case 'Meat':
        return Icons.restaurant;
      case 'Seafood':
        return Icons.set_meal;
      case 'Frozen Foods':
        return Icons.ac_unit;
      case 'Snacks':
        return Icons.cookie_outlined;
      default:
        return Icons.category;
    }
  }

  Color _getColorForSection(String section) {
    switch (section) {
      case 'Bakery & Bread':
        return Colors.orange;
      case 'Dairy':
        return Colors.blue;
      case 'Meat':
        return Colors.red;
      case 'Seafood':
        return Colors.lightBlue;
      case 'Frozen Foods':
        return Colors.cyan;
      case 'Snacks':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}

class CartItem {
  final String name;
  int quantity;
  double price;
  final String section;
  bool isLowStock;

  CartItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.section,
    this.isLowStock = false,
  });
}

class ShoppingList {
  final List<CartItem> items;
  final DateTime generatedDate;

  ShoppingList({required this.items, required this.generatedDate});

  double get total =>
      items.fold(0, (sum, item) => sum + (item.price * item.quantity));
}

class CartPage extends StatefulWidget {
  final Map<String, List<CartItem>> cartItems;
  final Function() onConfirmPurchase;
  final Function() onClearCart; // Add this

  const CartPage({
    super.key,
    required this.cartItems,
    required this.onConfirmPurchase,
    required this.onClearCart,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  ShoppingList? _shoppingList;
  final Map<String, int> _originalStockQuantities = {};

  @override
  void initState() {
    super.initState();
    _updateShoppingList();
    _loadOriginalStockQuantities();
  }

  Future<void> _loadOriginalStockQuantities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data');

      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _originalStockQuantities.clear();
          data.forEach((section, items) {
            for (var item in items as List) {
              _originalStockQuantities['${section}_${item['name']}'] =
                  item['quantity'];
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stock quantities: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter items that have changed quantity (deducted from stock)
    final Map<String, List<CartItem>> changedItems = {};
    widget.cartItems.forEach((section, items) {
      final changedSectionItems =
          items.where((item) {
            final originalQuantity =
                _originalStockQuantities['${section}_${item.name}'] ?? 0;
            final deductedQuantity = originalQuantity - item.quantity;
            return deductedQuantity > 0;
          }).toList();
      if (changedSectionItems.isNotEmpty) {
        changedItems[section] = changedSectionItems;
      }
    });

    // Calculate total using only deducted quantities
    double total = 0;
    changedItems.forEach((section, items) {
      for (var item in items) {
        final originalQuantity =
            _originalStockQuantities['${section}_${item.name}'] ?? 0;
        final deductedQuantity = originalQuantity - item.quantity;
        total += deductedQuantity * item.price;
      }
    });

    if (changedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No items to buy',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showShoppingList,
              icon: const Icon(Icons.shopping_basket),
              label: const Text('View Shopping List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: changedItems.length,
            itemBuilder: (context, index) {
              final section = changedItems.keys.elementAt(index);
              final items = changedItems[section]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      section,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...items.map((item) {
                    final originalQuantity =
                        _originalStockQuantities['${section}_${item.name}'] ??
                        0;
                    final deductedQuantity = originalQuantity - item.quantity;
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Php ${item.price.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${deductedQuantity}x',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Php ${(item.price * deductedQuantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (index < changedItems.length - 1) const Divider(),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated Cost:',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    'Php ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showShoppingList,
                      icon: const Icon(Icons.shopping_basket),
                      label: const Text('Shopping List'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onConfirmPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CONFIRM PURCHASE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: widget.onClearCart,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateShoppingList() {
    List<CartItem> lowStockItems = [];

    // Check all sections for low stock items
    for (var section in widget.cartItems.entries) {
      for (var item in section.value) {
        if (item.quantity <= 5) {
          // Include items with quantity 0-5
          // Check if item is already in shopping list
          final existingItem = lowStockItems.firstWhere(
            (i) => i.name == item.name && i.section == item.section,
            orElse:
                () => CartItem(
                  name: item.name,
                  quantity: 1,
                  price: item.price,
                  section: item.section,
                  isLowStock: true,
                ),
          );

          if (existingItem.quantity == 1) {
            // Only add if it's a new item
            lowStockItems.add(existingItem);
          }
        }
      }
    }

    setState(() {
      _shoppingList = ShoppingList(
        items: lowStockItems,
        generatedDate: DateTime.now(),
      );
    });
  }

  void _showShoppingList() {
    if (_shoppingList == null || _shoppingList!.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items in shopping list'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Shopping List'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated on: ${DateFormat('MMM dd, yyyy').format(_shoppingList!.generatedDate)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ..._shoppingList!.items.map(
                  (item) => ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.section} - Php ${item.price.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              _shoppingList!.items.remove(item);
                            });
                            Navigator.pop(context);
                            _showShoppingList();
                          },
                        ),
                        Text('${item.quantity}x'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() {
                              item.quantity++;
                            });
                            Navigator.pop(context);
                            _showShoppingList();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Total: Php ${_shoppingList!.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Add all items to cart
                  for (var item in _shoppingList!.items) {
                    // Find the section in cart items
                    if (!widget.cartItems.containsKey(item.section)) {
                      widget.cartItems[item.section] = [];
                    }

                    // Add or update item in cart
                    final existingItem = widget.cartItems[item.section]!
                        .firstWhere(
                          (i) => i.name == item.name,
                          orElse:
                              () => CartItem(
                                name: item.name,
                                quantity: 0,
                                price: item.price,
                                section: item.section,
                              ),
                        );

                    if (existingItem.quantity == 0) {
                      existingItem.quantity = item.quantity;
                      widget.cartItems[item.section]!.add(existingItem);
                    } else {
                      existingItem.quantity += item.quantity;
                    }
                  }

                  setState(() {
                    _shoppingList = null;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Items added to cart'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add All to Cart'),
              ),
            ],
          ),
    );
  }
}

class PurchaseHistory {
  final DateTime date;
  final double amount;
  final Map<String, int> items;

  PurchaseHistory({
    required this.date,
    required this.amount,
    required this.items,
  });
}

class ActivityPage extends StatefulWidget {
  final List<PurchaseHistory> purchaseHistory;
  final Map<String, List<CartItem>> cartItems;

  const ActivityPage({
    super.key,
    required this.purchaseHistory,
    required this.cartItems,
  });

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  // Basic Stats
  int get _totalItemsInStock {
    int total = 0;
    for (var section in widget.cartItems.values) {
      for (var item in section) {
        total += item.quantity;
      }
    }
    return total;
  }

  int get _lowStockItems {
    int count = 0;
    for (var section in widget.cartItems.values) {
      for (var item in section) {
        if (item.quantity <= 5 && item.quantity > 0) {
          count++;
        }
      }
    }
    return count;
  }

  int get _outOfStockItems {
    int count = 0;
    for (var section in widget.cartItems.values) {
      for (var item in section) {
        if (item.quantity == 0) {
          count++;
        }
      }
    }
    return count;
  }

  // Usage Trends Data
  List<double> _calculateMonthlyUsage() {
    Map<int, int> monthlyUsage = {};
    final now = DateTime.now();

    // Initialize last 6 months with 0
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyUsage[month.month] = 0;
    }

    // Calculate usage for each month
    for (var purchase in widget.purchaseHistory) {
      if (purchase.date.isAfter(DateTime(now.year, now.month - 6))) {
        monthlyUsage[purchase.date.month] =
            (monthlyUsage[purchase.date.month] ?? 0) +
            purchase.items.values.fold(0, (sum, quantity) => sum + quantity);
      }
    }

    // Convert to list of last 6 months
    List<double> usage = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      usage.add(monthlyUsage[month.month]?.toDouble() ?? 0);
    }

    return usage;
  }

  // Restocking Patterns Data
  List<double> _calculateRestockingPatterns() {
    Map<int, int> monthlyRestocks = {};
    final now = DateTime.now();

    // Initialize last 6 months with 0
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyRestocks[month.month] = 0;
    }

    // Calculate restocks for each month
    for (var purchase in widget.purchaseHistory) {
      if (purchase.date.isAfter(DateTime(now.year, now.month - 6))) {
        monthlyRestocks[purchase.date.month] =
            (monthlyRestocks[purchase.date.month] ?? 0) + 1;
      }
    }

    // Convert to list of last 6 months
    List<double> restocks = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      restocks.add(monthlyRestocks[month.month]?.toDouble() ?? 0);
    }

    return restocks;
  }

  @override
  Widget build(BuildContext context) {
    final monthlyUsage = _calculateMonthlyUsage();
    final monthlyRestocks = _calculateRestockingPatterns();
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Stats Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Basic Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  'Total Items in Stock',
                  _totalItemsInStock.toString(),
                  Icons.inventory_2_outlined,
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildStatCard(
                  'Items Running Low',
                  _lowStockItems.toString(),
                  Icons.warning_amber_outlined,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildStatCard(
                  'Out of Stock Items',
                  _outOfStockItems.toString(),
                  Icons.remove_shopping_cart_outlined,
                  Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Usage Trends Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usage Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final month = DateTime(
                                now.year,
                                now.month - 5 + value.toInt(),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM').format(month),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots:
                              monthlyUsage.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value,
                                );
                              }).toList(),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Restocking Patterns Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restocking Patterns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          monthlyRestocks.reduce((a, b) => a > b ? a : b) * 1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final month = DateTime(
                                now.year,
                                now.month - 5 + value.toInt(),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM').format(month),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups:
                          monthlyRestocks.asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value,
                                  color:
                                      entry.key == monthlyRestocks.length - 1
                                          ? Colors.green
                                          : Colors.grey.withAlpha(51),
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  DateTime? _selectedDate;
  final Map<DateTime, bool> _shoppingDates = {};
  final TextEditingController _noteController = TextEditingController();

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _showDateConfirmationDialog(date);
  }

  void _showDateConfirmationDialog(DateTime date) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Set Shopping Date'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Date: ${DateFormat('MMMM dd, yyyy').format(date)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Add a note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _noteController.clear();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _shoppingDates[date] = true;
                  });
                  Navigator.pop(context);
                  _showConfirmationSnackBar(date);
                  _noteController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Set Date'),
              ),
            ],
          ),
    );
  }

  void _showConfirmationSnackBar(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shopping reminder set for ${DateFormat('MMMM dd, yyyy').format(date)}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _checkUpcomingDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      _showShoppingReminderDialog(date);
    }
  }

  void _showShoppingReminderDialog(DateTime date) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Shopping Reminder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart, size: 48, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'Your set date is coming up, would you like the system to set the next date automatically?',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('NO'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Set next month's date
                  final nextMonth = date.add(const Duration(days: 30));
                  setState(() {
                    _shoppingDates[nextMonth] = true;
                  });
                  Navigator.pop(context);
                  _showConfirmationSnackBar(nextMonth);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('YES'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check for today's shopping date
    _shoppingDates.forEach((date, isSet) {
      if (isSet) _checkUpcomingDate(date);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText:
                  _selectedDate == null
                      ? 'Select a date'
                      : DateFormat('MM/dd/yyyy').format(_selectedDate!),
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                _selectDate(picked);
              }
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _shoppingDates.length,
            itemBuilder: (context, index) {
              final date = _shoppingDates.keys.elementAt(index);
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.green),
                  title: Text(
                    'Shopping Day',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: TextStyle(
                      color:
                          date.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.green,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _shoppingDates.remove(date);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shopping date removed'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}

// Helper function for fade transition
void navigateWithFade(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
}
