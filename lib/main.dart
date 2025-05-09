// ignore_for_file: use_build_context_synchronously, avoid_types_as_parameter_names, deprecated_member_use, unnecessary_cast

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
import 'package:url_launcher/url_launcher.dart';
import 'package:restockr/wrapper.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 70,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic), //Restckr
          displayMedium: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
          titleLarge:
              TextStyle(fontSize: 26), //Cart,Stock,Event,Activity, Sign-up
          bodyLarge: TextStyle(
            fontSize: 22,
          ),
          bodyMedium: TextStyle(fontSize: 20),
          bodySmall: TextStyle(fontSize: 18),
          labelLarge: TextStyle(fontSize: 16),
        ),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(76, 175, 80, 1)),
        useMaterial3: true,
      ),
      home: const Wrapper(),
      routes: {
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<bool> updateProfile(String fullName, String? photoURL) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      await user.updateDisplayName(fullName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
      return true;
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user's cart data
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc('cart_data')
          .delete();

      // Delete user's stock data
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data')
          .delete();

      // Delete user's activity data
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity')
          .doc('purchase_history')
          .delete();

      // Delete the user account
      await user.delete();

      return true;
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
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
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.05;
    return Scaffold(
      backgroundColor: const Color.fromRGBO(76, 175, 80, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                    const SizedBox(height: 0),
                    // Logo
                    Image.asset(
                      'lib/assets/logo.png',
                      width: screenWidth * 0.23,
                      height: screenWidth * 0.23,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shopping_bag_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 0),
                    // App Name
                    Text(
                      'ReStckr',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Your companion in everyday shopping.',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
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
                          Text(
                            'Log in to access your grocery lists and more.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w300,
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
                              _emailController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                  offset: _emailController.text.length,
                                ),
                              );
                            },
                            style: Theme.of(context).textTheme.labelLarge,
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
                          const SizedBox(height: 18),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onTap: () {
                              _passwordController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                  offset: _passwordController.text.length,
                                ),
                              );
                            },
                            style: Theme.of(context).textTheme.labelLarge,
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
                          const SizedBox(height: 18),
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle:
                                      Theme.of(context).textTheme.bodyMedium),
                              child: _isLoading
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
                          ),
                          const SizedBox(height: 18),
                          // Forgot Password
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/forgot-password',
                              ),
                              child: Text(
                                'Forgot password?',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.orange,
                                    ),
                              ),
                            ),
                          ),
                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account?",
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                              TextButton(
                                  onPressed: () => navigateWithFade(
                                        context,
                                        const SignUpPage(),
                                      ),
                                  child: Text(
                                    'Sign up',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.orange,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.orange),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Social Login Divider
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Sign in with',
                                    style: TextStyle(
                                        fontFamily: "Poppins", fontSize: 16)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                                iconSize: 40,
                              ),
                              const SizedBox(width: 14),
                              IconButton(
                                onPressed:
                                    _isLoading ? null : _handleGoogleSignIn,
                                icon: const FaIcon(FontAwesomeIcons.google,
                                    color: Colors.red),
                                iconSize: 40,
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
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
    const accentColor = Colors.orange; // Use your app's accent color
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
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
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color.fromRGBO(76, 175, 80, 1),
                            width: 4),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 100,
                        color: Color.fromRGBO(76, 175, 80, 1),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Sign Up Text
                    Text(
                      'Sign Up',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 32),
                    // Full Name Field
                    TextFormField(
                      controller: _fullNameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        labelStyle: TextStyle(
                            fontFamily: "Poppins",
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(
                            fontFamily: "Poppins",
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: const UnderlineInputBorder(
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
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: accentColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: accentColor),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
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
                          textStyle: Theme.of(context).textTheme.bodyMedium,
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
                        Text('Already have an account?',
                            style: Theme.of(context).textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                                fontFamily: "Poppins",
                                fontSize: 16,
                                color: accentColor,
                                decoration: TextDecoration.underline,
                                decorationColor: accentColor),
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
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
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
                      'Change Password',
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
                              child: _isLoading
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

  @override
  void initState() {
    super.initState();
    _loadPurchaseHistory();
    _loadStockAndRebuildCart();
  }

  Future<void> _loadStockAndRebuildCart() async {
    await _rebuildCartFromStock();
  }

  Future<void> _rebuildCartFromStock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final stockDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('stocks')
        .doc('stock_data');
    final originalDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('stocks')
        .doc('original_stock_data');
    final stockDoc = await stockDocRef.get();
    final originalDoc = await originalDocRef.get();
    if (stockDoc.exists && originalDoc.exists) {
      final stockData = stockDoc.data() as Map<String, dynamic>;
      final originalData = originalDoc.data() as Map<String, dynamic>;
      setState(() {
        _cartItems.clear();
        stockData.forEach((section, items) {
          final List<Map<String, dynamic>> currentItems =
              List<Map<String, dynamic>>.from(items);
          final List<Map<String, dynamic>> originalItems =
              List<Map<String, dynamic>>.from(originalData[section] ?? []);

          // Only add to cart if there's a new deduction
          for (var orig in originalItems) {
            final current = currentItems.firstWhere(
              (item) => item['name'] == orig['name'],
              orElse: () => {},
            );
            if (current.isNotEmpty) {
              final origQty = orig['quantity'] as int;
              final currQty = current['quantity'] as int;
              final deductedQty = origQty - currQty;

              // Only add to cart if there's a new deduction and the item isn't already in cart
              if (deductedQty > 0) {
                if (!_cartItems.containsKey(section)) {
                  _cartItems[section] = [];
                }

                // Check if item already exists in cart
                final existingItemIndex = _cartItems[section]!
                    .indexWhere((item) => item.name == current['name']);

                if (existingItemIndex == -1) {
                  // Only add if it's not already in cart
                  _cartItems[section]!.add(
                    CartItem(
                      name: current['name'],
                      quantity: deductedQty,
                      price: (current['price'] as num).toDouble(),
                      section: section,
                    ),
                  );
                }
              }
            }
          }
        });
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showNotificationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationPage()),
    );
  }

  void _showSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('lib/assets/logo.png', width: 40, height: 40),
            const SizedBox(width: 3),
            Text(_title,
                style: const TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 30,
                    fontWeight: FontWeight.w400))
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications), 
            onPressed: _showNotificationDialog, 
            iconSize: 25),
          IconButton(
            icon: const Icon(Icons.settings),
            iconSize: 25,
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          StocksPage(
            cartItems: _cartItems,
            onStockUpdate: _updateCartFromStock,
          ),
          CartPage(
            cartItems: _cartItems,
            onConfirmPurchase: _confirmPurchase,
            onClearCart: _clearCart,
          ),
          const ActivityPage(),
          const EventsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory, size: 30), label: 'Stocks'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart, size: 30), label: 'Cart'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history, size: 30), label: 'Activity'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 30), label: 'Events'),
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
      final historyList = _purchaseHistory
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

  // Add this method to update cart and persist it when stock changes
  void _updateCartFromStock(Map<String, List<CartItem>> updatedStock) {
    setState(() {
      _cartItems.clear();
      _cartItems.addAll(updatedStock);
    });
    _rebuildCartFromStock(); // Always rebuild cart after stock changes
  }

  // In HomePage, add the clear cart method
  void _clearCart() async {
    setState(() {
      _cartItems.clear();
    });

    // Update stock data in Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final stockDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stocks')
            .doc('stock_data');

        // Get current stock data
        final stockDoc = await stockDocRef.get();
        if (stockDoc.exists) {
          // Update each section to match original quantities, but only for existing items
          final originalDocRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('stocks')
              .doc('original_stock_data');
          final originalDoc = await originalDocRef.get();

          if (originalDoc.exists) {
            final originalData = originalDoc.data() as Map<String, dynamic>;
            final currentData = stockDoc.data() as Map<String, dynamic>;

            Map<String, dynamic> updatedStockData = {};
            currentData.forEach((section, items) {
              final List<Map<String, dynamic>> currentItems =
                  List<Map<String, dynamic>>.from(items);
              final List<Map<String, dynamic>> originalItems =
                  List<Map<String, dynamic>>.from(originalData[section] ?? []);
              List<Map<String, dynamic>> updatedItems = [];
              for (var curr in currentItems) {
                final orig = originalItems.firstWhere(
                  (item) => item['name'] == curr['name'],
                  orElse: () => {},
                );
                if (orig.isNotEmpty) {
                  // Reset quantity to original
                  updatedItems.add({
                    'name': curr['name'],
                    'quantity': orig['quantity'],
                    'price': curr['price'],
                  });
                } else {
                  // Keep deleted items deleted (do not re-add)
                  // Optionally, you could keep them with quantity 0 if you want
                }
              }
              updatedStockData[section] = updatedItems;
            });

            // Save updated stock data
            await stockDocRef.set(updatedStockData);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmPurchase() async {
    try {
      // Create purchase history entry
      final purchase = PurchaseHistory(
        date: DateTime.now(),
        amount: _calculateTotal(),
        items: _getCartItemsMap(),
      );

      // Add to purchase history
      setState(() {
        _purchaseHistory.add(purchase);
      });

      // Save to Firestore
      await _savePurchaseHistory();

      // After confirming purchase, update original_stock_data to match current stock_data
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final stockDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stocks')
            .doc('stock_data');
        final originalDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stocks')
            .doc('original_stock_data');

        final stockDoc = await stockDocRef.get();
        if (stockDoc.exists) {
          final stockData = stockDoc.data() as Map<String, dynamic>;
          await originalDocRef.set(stockData);
        }
      }

      // Clear the cart
      setState(() {
        _cartItems.clear();
      });

      // Navigate to events page
      setState(() {
        _selectedIndex = 3; // Switch to Events tab
      });

      // Show date selection dialog
      if (mounted) {
        _showShoppingDateDialog(purchase);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming purchase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, int> _getCartItemsMap() {
    Map<String, int> items = {};
    _cartItems.forEach((section, itemsList) {
      for (var item in itemsList) {
        items[item.name] = item.quantity;
      }
    });
    return items;
  }

  void _showShoppingDateDialog(PurchaseHistory purchase) {
    showDialog(
      context: context,
      barrierDismissible: false, // <-- Add this line
      builder: (context) => AlertDialog(
        title: const Text('Set Shopping Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'When would you like to do your shopping?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  Navigator.pop(context); // Close the AlertDialog only
                  await _storeShoppingEvent(picked, purchase);
                  // Do NOT pop again in _storeShoppingEvent for the date picker or AlertDialog
                }
              },
              child: const Text('Select Date'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _storeShoppingEvent(
      DateTime date, PurchaseHistory purchase) async {
    bool loadingDialogOpen = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      // Only pop if the dialog is open
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close date selection dialog
      }

      // Show loading indicator
      if (!mounted) return;
      loadingDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final eventsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc('shopping_events');

      // Get existing events
      final eventsDoc = await eventsRef.get();
      List<Map<String, dynamic>> events = [];
      if (eventsDoc.exists) {
        events =
            List<Map<String, dynamic>>.from(eventsDoc.data()?['events'] ?? []);
      }

      // Try to find an event with the same date (ignoring time)
      final String newEventDate = DateFormat('yyyy-MM-dd').format(date);
      final existingIndex = events.indexWhere((event) {
        final eventDate = DateTime.parse(event['date']);
        return DateFormat('yyyy-MM-dd').format(eventDate) == newEventDate;
      });

      if (existingIndex != -1) {
        // Merge with existing event
        final existingEvent = events[existingIndex];
        final existingPurchase = existingEvent['purchase'] as Map<String, dynamic>;

        // Merge items
        final Map<String, int> existingItems = Map<String, int>.from(existingPurchase['items']);
        final Map<String, int> newItems = purchase.items;
        newItems.forEach((key, value) {
          existingItems[key] = (existingItems[key] ?? 0) + value;
        });

        // Update amount
        final double newAmount = (existingPurchase['amount'] as num).toDouble() + purchase.amount;

        // Update purchase details
        existingEvent['purchase'] = {
          'date': existingPurchase['date'], // Keep the original creation date
          'amount': newAmount,
          'items': existingItems,
        };

        existingEvent['completed'] = existingEvent['completed'] ?? false;
        events[existingIndex] = existingEvent;
      } else {
        // Add new event
        final newEvent = {
          'date': date.toIso8601String(),
          'purchase': {
            'date': purchase.date.toIso8601String(),
            'amount': purchase.amount,
            'items': purchase.items,
          },
          'completed': false, // <-- Add this
        };
        events.add(newEvent);
      }

      // Save updated events
      await eventsRef.set({'events': events});

      // DO NOT reset stock to original quantities here
      // The stock should reflect actual usage

      // Close loading indicator
      if (loadingDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogOpen = false;
      }

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Shopping date set for ${DateFormat('MMMM dd, yyyy').format(date)}'),
          backgroundColor: Colors.green,
        ),
      );

      // Switch to events page
      setState(() {
        _selectedIndex = 3; // Switch to Events tab
      });
    } catch (e) {
      // Close loading indicator if it's showing
      if (loadingDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogOpen = false;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shopping event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class StocksPage extends StatefulWidget {
  final Map<String, List<CartItem>> cartItems;
  final Function(Map<String, List<CartItem>>)?
      onStockUpdate; // Add this callback

  const StocksPage({
    super.key,
    required this.cartItems,
    this.onStockUpdate,
  });

  @override
  State<StocksPage> createState() => _StocksPageState();
}

class _StocksPageState extends State<StocksPage> {
  // Fixed section order
  static const List<String> sectionOrder = [
    'Bakery & Bread',
    'Dairy',
    'Meat',
    'Seafood',
    'Frozen Foods',
    'Snacks',
  ];

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

  StreamSubscription<DocumentSnapshot>? _stockSubscription;
  StreamSubscription<DocumentSnapshot>? _originalStockSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealTimeListeners();
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    _originalStockSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to stock_data changes
    _stockSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('stocks')
        .doc('stock_data')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _sectionItems.clear();
          data.forEach((section, items) {
            _sectionItems[section] = List<Map<String, dynamic>>.from(
              (items as List).map((item) => Map<String, dynamic>.from(item)),
            );
          });
        });

        // Notify parent about stock update
        if (widget.onStockUpdate != null) {
          Map<String, List<CartItem>> updatedStock = {};
          _sectionItems.forEach((section, items) {
            updatedStock[section] = items
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
          widget.onStockUpdate!(updatedStock);
        }
      }
    });

    // Listen to original_stock_data changes
    _originalStockSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('stocks')
        .doc('original_stock_data')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        // If original stock data doesn't exist, create it from current stock
        _createOriginalStockData();
      }
    });
  }

  Future<void> _createOriginalStockData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final originalDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('original_stock_data');

      // Create a copy of current stock data
      Map<String, dynamic> originalData = {};
      _sectionItems.forEach((section, items) {
        originalData[section] =
            items.map((item) => Map<String, dynamic>.from(item)).toList();
      });

      await originalDocRef.set(originalData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating original stock data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Modify _updateStockImmediately to use transactions for atomic updates
  void _updateStockImmediately(
    String section,
    Map<String, dynamic> item,
    int newQuantity,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentQuantity = item['quantity'] as int;
    final quantityDifference = currentQuantity - newQuantity;

    // Only show confirmation for larger deductions
    if (quantityDifference > 5) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Large Stock Deduction'),
          content: Text(
            'You are deducting $quantityDifference ${item['name']} from stock.\n'
            'This will add the items to your cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() {
          item['quantity'] = currentQuantity;
        });
        return;
      }
    }

    // Update UI immediately for better UX
    setState(() {
      item['quantity'] = newQuantity;
      if (newQuantity == 0) {
        item['isOutOfStock'] = true;
      } else {
        item['isOutOfStock'] = false;
      }
    });

    // Use transaction for atomic update
    try {
      final stockDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(stockDocRef);
        if (!snapshot.exists) {
          // Instead of throwing, create the document with the section and item
          transaction.set(
              stockDocRef,
              {
                section: [item],
              },
              SetOptions(merge: true));
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final sectionItems =
            List<Map<String, dynamic>>.from(data[section] ?? []);
        // Find and update the item
        final itemIndex =
            sectionItems.indexWhere((i) => i['name'] == item['name']);
        if (itemIndex != -1) {
          sectionItems[itemIndex] = Map<String, dynamic>.from(item);
        } else {
          sectionItems.add(Map<String, dynamic>.from(item));
        }
        data[section] = sectionItems;
        transaction.set(stockDocRef, data);
      });

      // --- FIX: Update original_stock_data if newQuantity > originalQuantity ---
      final originalDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('original_stock_data');
      final originalDoc = await originalDocRef.get();
      if (originalDoc.exists) {
        final originalData = originalDoc.data() as Map<String, dynamic>;
        final originalSectionItems =
            List<Map<String, dynamic>>.from(originalData[section] ?? []);
        final originalItemIndex =
            originalSectionItems.indexWhere((i) => i['name'] == item['name']);
        int originalQuantity = 0;
        if (originalItemIndex != -1) {
          originalQuantity =
              originalSectionItems[originalItemIndex]['quantity'] as int;
        }
        // If newQuantity > originalQuantity, update original_stock_data for this item
        if (newQuantity > originalQuantity) {
          if (originalItemIndex != -1) {
            originalSectionItems[originalItemIndex]['quantity'] = newQuantity;
          } else {
            originalSectionItems.add({
              'name': item['name'],
              'quantity': newQuantity,
              'price': item['price'],
            });
          }
          await originalDocRef.update({section: originalSectionItems});
        }
      }
      // --- END FIX ---

      // Handle cart update after successful stock update
      if (quantityDifference != 0 && widget.onStockUpdate != null) {
        // Get the original stock data to calculate the correct deduction
        final originalDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stocks')
            .doc('original_stock_data');
        final originalDoc = await originalDocRef.get();

        if (originalDoc.exists) {
          final originalData = originalDoc.data() as Map<String, dynamic>;
          final originalSectionItems =
              List<Map<String, dynamic>>.from(originalData[section] ?? []);
          final originalItem = originalSectionItems.firstWhere(
            (i) => i['name'] == item['name'],
            orElse: () => {'quantity': 0},
          );

          final originalQuantity = originalItem['quantity'] as int;
          final actualDeduction = originalQuantity - newQuantity;

          final cartItem = CartItem(
            name: item['name'] as String,
            quantity: actualDeduction.abs(),
            price: (item['price'] as num).toDouble(),
            section: section,
          );

          final Map<String, List<CartItem>> cartUpdate = {};
          cartUpdate[section] = [cartItem];
          widget.onStockUpdate!(cartUpdate);

          if (mounted) {
            String message;
            Color color;
            SnackBarAction? action;
            if (quantityDifference > 0) {
              // Deducted from stock, added to cart
              message =
                  'Added ${quantityDifference.abs()} ${item['name']} to cart';
              color = Colors.green;
              action = quantityDifference > 5
                  ? SnackBarAction(
                      label: 'View Cart',
                      textColor: Colors.white,
                      onPressed: () {
                        if (mounted) {
                          final homePage =
                              context.findAncestorStateOfType<_HomePageState>();
                          if (homePage != null) {
                            homePage.setState(() {
                              homePage._selectedIndex = 1;
                            });
                          }
                        }
                      },
                    )
                  : null;
            } else if (quantityDifference < 0) {
              // Only show 'Removed from cart' if there was something in the cart to remove
              // That is, only if originalQuantity > newQuantity (i.e., cart had positive quantity)
              if (actualDeduction < 0 &&
                  (originalQuantity - newQuantity) < 0 &&
                  (originalQuantity > newQuantity)) {
                message =
                    'Removed ${quantityDifference.abs()} ${item['name']} from cart';
                color = Colors.orange;
                action = null;
              } else {
                message = '';
                color = Colors.grey;
                action = null;
              }
            } else {
              message = '';
              color = Colors.grey;
              action = null;
            }
            if (message.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: color,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  action: action,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        item['quantity'] = currentQuantity;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _updateStockImmediately(section, item, newQuantity);
              },
            ),
          ),
        );
      }
    }
  }

  void _clearSection(String section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear $section'),
        content:
            Text('Are you sure you want to remove all items from $section?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _sectionItems[section]?.clear();
      });

      // Update Firestore
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('stocks')
              .doc('stock_data');
          try {
            await docRef.update({
              section: [],
            });
          } catch (e) {
            await docRef.set({
              section: [],
            }, SetOptions(merge: true));
          }
        }
        // Notify parent about stock update immediately
        if (widget.onStockUpdate != null) {
          Map<String, List<CartItem>> updatedStock = {};
          _sectionItems.forEach((section, items) {
            updatedStock[section] = items
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
          widget.onStockUpdate!(updatedStock);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('All items in $section have been cleared.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing $section: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

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

    // Save to Firestore
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

      // Also save original stock data
      final originalDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('original_stock_data');

      await originalDocRef.set({
        for (var entry in _sectionItems.entries) entry.key: entry.value,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock items have been pre-populated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving stock data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sectionItems.values.every((items) => items.isEmpty)) {
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
                fontFamily: "Poppins",
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first item',
              style: TextStyle(
                  fontFamily: "Poppins", fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _showAddItemBottomSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      minimumSize: const Size(0, 40),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _prePopulateStockItems,
                    icon: const Icon(Icons.inventory),
                    label: const Text('Pre-populate '),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      minimumSize: const Size(0, 40),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
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
          itemCount: sectionOrder.length,
          itemBuilder: (context, index) {
            final section = sectionOrder[index];
            final color = _getColorForSection(section);
            final items = _sectionItems[section] ?? [];

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
                          title: Text(item['name'],
                              style: Theme.of(context).textTheme.labelLarge),
                          subtitle: Text(
                              'Php ${item['price'].toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                                onPressed: () {
                                  final newQuantity =
                                      (item['quantity'] as int) - 1;
                                  if (newQuantity >= 0) {
                                    // Only allow quantities >= 0
                                    _updateStockImmediately(
                                        section, item, newQuantity);
                                  }
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (item['quantity'] as int) == 0
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item['quantity']}',
                                  style: TextStyle(
                                    color: (item['quantity'] as int) == 0
                                        ? Colors.red
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.green,
                                onPressed: () {
                                  final newQuantity =
                                      (item['quantity'] as int) + 1;
                                  _updateStockImmediately(
                                      section, item, newQuantity);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                onPressed: () =>
                                    _showDeleteDialog(section, item),
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
            onPressed: _showAddItemBottomSheet,
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
        Icon(_getIconForSection(title), color: color, size: 25),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            size: 25,
            color: Colors.grey,
          ),
          onPressed: () => _toggleSection(title),
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, size: 25),
          color: color,
          onPressed: () {
            _clearSection(title);
          },
        ),
      ],
    );
  }

  // Modify _showQuantityDialog to use immediate updates

  // Modify _showDeleteDialog to use immediate updates
  void _showDeleteDialog(String section, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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
              final Map<String, List<CartItem>> updatedStock = {};
              _sectionItems.forEach((section, items) {
                updatedStock[section] = items
                    .map(
                      (item) => CartItem(
                        name: item['name'] as String,
                        quantity: item['quantity'] as int,
                        price: (item['price'] as num).toDouble(),
                        section: section,
                      ),
                    )
                    .toList();
              });

              // Notify parent about stock update immediately
              if (widget.onStockUpdate != null) {
                widget.onStockUpdate!(updatedStock);
              }

              // Update Firestore
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final docRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('stocks')
                      .doc('stock_data');
                  try {
                    await docRef.update({
                      section: _sectionItems[section],
                    });
                  } catch (e) {
                    await docRef.set({
                      section: _sectionItems[section],
                    }, SetOptions(merge: true));
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating stock: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              // Notify parent about item deletion with price
              if (widget.onStockUpdate != null) {
                widget.onStockUpdate!(updatedStock);
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
  void _showAddItemBottomSheet() {
    String selectedSection = _expandedSections.keys.first;
    final TextEditingController itemController = TextEditingController();
    final TextEditingController quantityController =
        TextEditingController(text: '1');
    final TextEditingController priceController =
        TextEditingController(text: '0.0');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add New Item',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: _expandedSections.keys.map((String section) {
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
              TextFormField(
                controller: itemController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'Enter item name',
                  prefixIcon: Icon(Icons.edit),
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter quantity';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty < 1) {
                          return 'Enter a valid quantity';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixIcon: Icon(Icons.php),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final quantity =
                          int.tryParse(quantityController.text) ?? 0;
                      final price =
                          double.tryParse(priceController.text) ?? 0.0;

                      setState(() {
                        _sectionItems[selectedSection]!.add({
                          'name': itemController.text.trim(),
                          'quantity': quantity,
                          'price': price,
                        });
                      });

                      // Convert and notify parent immediately
                      final Map<String, List<CartItem>> updatedStock = {};
                      _sectionItems.forEach((section, items) {
                        updatedStock[section] = items
                            .map(
                              (item) => CartItem(
                                name: item['name'] as String,
                                quantity: item['quantity'] as int,
                                price: (item['price'] as num).toDouble(),
                                section: section,
                              ),
                            )
                            .toList();
                      });

                      // Notify parent about stock update immediately
                      if (widget.onStockUpdate != null) {
                        widget.onStockUpdate!(updatedStock);
                      }

                      // Update Firestore
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          final docRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('stocks')
                              .doc('stock_data');
                          try {
                            await docRef.update({
                              selectedSection: _sectionItems[selectedSection],
                            });
                          } catch (e) {
                            await docRef.set({
                              selectedSection: _sectionItems[selectedSection],
                            }, SetOptions(merge: true));
                          }
                          // Also update original_stock_data if this is a new item
                          final originalDocRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('stocks')
                              .doc('original_stock_data');
                          final originalDoc = await originalDocRef.get();
                          if (originalDoc.exists) {
                            final originalData =
                                originalDoc.data() as Map<String, dynamic>;
                            final List<dynamic> originalSection =
                                List.from(originalData[selectedSection] ?? []);
                            final exists = originalSection.any((item) =>
                                item['name'] == itemController.text.trim());
                            if (!exists) {
                              originalSection.add({
                                'name': itemController.text.trim(),
                                'quantity': quantity,
                                'price': price,
                              });
                              try {
                                await originalDocRef.update({
                                  selectedSection: originalSection,
                                });
                              } catch (e) {
                                await originalDocRef.set({
                                  selectedSection: originalSection,
                                }, SetOptions(merge: true));
                              }
                            }
                          } else {
                            // If original_stock_data doesn't exist, create it
                            await originalDocRef.set({
                              selectedSection: [
                                {
                                  'name': itemController.text.trim(),
                                  'quantity': quantity,
                                  'price': price,
                                }
                              ],
                            }, SetOptions(merge: true));
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating stock: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${itemController.text.trim()} added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
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
  final Function()? onConfirmPurchase;
  final Function()? onClearCart;

  const CartPage({
    super.key,
    required this.cartItems,
    this.onConfirmPurchase,
    this.onClearCart,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.cartItems.isEmpty ||
        widget.cartItems.values.every((items) => items.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add items from your stock to get started',
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    double total = 0;
    widget.cartItems.forEach((section, items) {
      for (var item in items) {
        total += item.price * item.quantity;
      }
    });

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.cartItems.length,
            itemBuilder: (context, index) {
              final section = widget.cartItems.keys.elementAt(index);
              final items = widget.cartItems[section]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getSectionIcon(section),
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          section,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Php ${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Php ${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (index < widget.cartItems.length - 1)
                    const SizedBox(height: 16),
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
                color: Colors.black.withOpacity(0.1),
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
                    'Total Amount:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Php ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onClearCart,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
            ],
          ),
        ),
      ],
    );
  }

  IconData _getSectionIcon(String section) {
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
  // Remove the props for purchaseHistory and cartItems, as we will fetch them in real-time
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  // Helper to calculate stats from cartItems
  int _totalItemsInStock(Map<String, List<CartItem>> cartItems) {
    int total = 0;
    for (var section in cartItems.values) {
      for (var item in section) {
        total += item.quantity;
      }
    }
    return total;
  }

  int _lowStockItems(Map<String, List<CartItem>> cartItems) {
    int count = 0;
    for (var section in cartItems.values) {
      for (var item in section) {
        if (item.quantity <= 5 && item.quantity > 0) {
          count++;
        }
      }
    }
    return count;
  }

  int _outOfStockItems(Map<String, List<CartItem>> cartItems) {
    int count = 0;
    for (var section in cartItems.values) {
      for (var item in section) {
        if (item.quantity == 0) {
          count++;
        }
      }
    }
    return count;
  }

  // Helper to calculate monthly usage and restocking patterns from purchaseHistory
  List<double> _calculateMonthlyUsage(List<PurchaseHistory> purchaseHistory) {
    Map<int, int> monthlyUsage = {};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyUsage[month.month] = 0;
    }
    for (var purchase in purchaseHistory) {
      if (purchase.date.isAfter(DateTime(now.year, now.month - 6))) {
        monthlyUsage[purchase.date.month] =
            (monthlyUsage[purchase.date.month] ?? 0) +
                purchase.items.values
                    .fold(0, (sum, quantity) => sum + quantity);
      }
    }
    List<double> usage = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      usage.add(monthlyUsage[month.month]?.toDouble() ?? 0);
    }
    return usage;
  }

  List<double> _calculateRestockingPatterns(
      List<PurchaseHistory> purchaseHistory) {
    Map<int, int> monthlyRestocks = {};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyRestocks[month.month] = 0;
    }
    for (var purchase in purchaseHistory) {
      if (purchase.date.isAfter(DateTime(now.year, now.month - 6))) {
        monthlyRestocks[purchase.date.month] =
            (monthlyRestocks[purchase.date.month] ?? 0) + 1;
      }
    }
    List<double> restocks = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      restocks.add(monthlyRestocks[month.month]?.toDouble() ?? 0);
    }
    return restocks;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view activity'));
    }

    // Listen to both stock_data and purchase_history in parallel
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data')
          .snapshots(),
      builder: (context, stockSnapshot) {
        if (stockSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!stockSnapshot.hasData || !stockSnapshot.data!.exists) {
          return const Center(child: Text('No stock data available.'));
        }
        final stockData = stockSnapshot.data!.data() as Map<String, dynamic>;
        Map<String, List<CartItem>> realTimeCartItems = {};
        stockData.forEach((section, items) {
          realTimeCartItems[section] = (items as List)
              .map((item) => CartItem(
                    name: item['name'],
                    quantity: item['quantity'],
                    price: (item['price'] as num).toDouble(),
                    section: section,
                  ))
              .toList();
        });

        // Now listen to purchase_history
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('activity')
              .doc('purchase_history')
              .snapshots(),
          builder: (context, purchaseSnapshot) {
            if (purchaseSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            List<PurchaseHistory> realTimePurchaseHistory = [];
            if (purchaseSnapshot.hasData && purchaseSnapshot.data!.exists) {
              final data =
                  purchaseSnapshot.data!.data() as Map<String, dynamic>;
              final List<dynamic> historyList = data['history'] ?? [];
              for (var entry in historyList) {
                realTimePurchaseHistory.add(
                  PurchaseHistory(
                    date: DateTime.parse(entry['date']),
                    amount: (entry['amount'] as num).toDouble(),
                    items: Map<String, int>.from(entry['items'] ?? {}),
                  ),
                );
              }
            }

            // Now use realTimeCartItems and realTimePurchaseHistory for stats and charts
            final monthlyUsage =
                _calculateMonthlyUsage(realTimePurchaseHistory);
            final monthlyRestocks =
                _calculateRestockingPatterns(realTimePurchaseHistory);
            final now = DateTime.now();

            // The rest of the UI is the same, just use realTimeCartItems and realTimePurchaseHistory
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
                          _totalItemsInStock(realTimeCartItems).toString(),
                          Icons.inventory_2_outlined,
                          Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          'Items Running Low',
                          _lowStockItems(realTimeCartItems).toString(),
                          Icons.warning_amber_outlined,
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          'Out of Stock Items',
                          _outOfStockItems(realTimeCartItems).toString(),
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
                              gridData: const FlGridData(show: false),
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
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
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
                                  dotData: const FlDotData(show: true),
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
                              maxY: monthlyRestocks.isNotEmpty
                                  ? monthlyRestocks
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.2
                                  : 1,
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
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups:
                                  monthlyRestocks.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value,
                                      color: entry.key ==
                                              monthlyRestocks.length - 1
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
          },
        );
      },
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

class _EventsPageState extends State<EventsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Debug log

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Debug log
      return const Center(
        child: Text('Please log in to view events'),
      );
    }

    // Debug log

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc('shopping_events')
          .snapshots(),
      builder: (context, snapshot) {
        // Debug log

        if (snapshot.hasError) {
          // Debug log
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading events: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Force rebuild
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Show loading indicator while waiting for initial data
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Debug log
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Handle no data case
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Debug log
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No Shopping Events',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your shopping events will appear here',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        try {
          // Debug log
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final events = List<Map<String, dynamic>>.from(data['events'] ?? []);
          // Debug log

          if (events.isEmpty) {
            // Debug log
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Shopping Events',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your shopping events will appear here',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Debug log
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final date = DateTime.parse(event['date']);
              final purchase = event['purchase'] as Map<String, dynamic>;
              final purchaseDate = DateTime.parse(purchase['date']);
              final amount = (purchase['amount'] as num).toDouble();
              final items = Map<String, int>.from(purchase['items']);

              // In the _EventsPageState class, add this method to handle event deletion
              Future<void> deleteEvent(
                  int index, List<Map<String, dynamic>> events) async {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: const Text(
                          'Are you sure you want to delete this shopping event?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    // Remove the event from the list immediately for better UX
                    events.removeAt(index);

                    // Update Firestore in the background
                    final eventsRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('events')
                        .doc('shopping_events');

                    // Use set with merge option for better performance
                    await eventsRef
                        .set({'events': events}, SetOptions(merge: true));

                    // Show success message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting event: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.green),
                  title: Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: const TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Created on ${DateFormat('MMM dd, yyyy').format(purchaseDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => deleteEvent(index, events),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Purchase Details:',
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Amount: Php ${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: "Poppins",
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Items:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...items.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key,
                                      style: const TextStyle(
                                        fontFamily: "Poppins",
                                        fontSize: 16,
                                      )),
                                  Text(
                                    '${entry.value}x',
                                    style: const TextStyle(
                                      fontFamily: "Poppins",
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    if (!(event['completed'] ?? false) && !date.isAfter(DateTime.now())) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirm Shopping Done'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => _confirmShoppingDone(event, index, events),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        } catch (e) {
          // Debug log
          // Debug log
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error processing events: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Force rebuild
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _confirmShoppingDone(Map<String, dynamic> event, int index, List<Map<String, dynamic>> events) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final items = Map<String, int>.from(event['purchase']['items']);
      final stockRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('stock_data');
      final stockDoc = await stockRef.get();
      Map<String, dynamic> stockData = {};
      if (stockDoc.exists) {
        stockData = stockDoc.data() as Map<String, dynamic>;
      }
      // Update stock quantities
      items.forEach((itemName, qtyToAdd) {
        for (var section in stockData.keys) {
          final sectionItems = List<Map<String, dynamic>>.from(stockData[section]);
          for (var item in sectionItems) {
            if (item['name'] == itemName) {
              item['quantity'] += qtyToAdd;
            }
          }
          stockData[section] = sectionItems;
        }
      });
      await stockRef.set(stockData);
      // Remove event from the list
      events.removeAt(index);
      final eventsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc('shopping_events');
      await eventsRef.set({'events': events});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated and event removed!'), backgroundColor: Colors.green),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error confirming shopping: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Helper function for fade transition
void navigateWithFade(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _photoURL;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedImage = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _photoURL;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      await storageRef.putData(
        await _selectedImage!.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await storageRef.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _fullNameController.text = user.displayName ?? '';
        _photoURL = user.photoURL;
      });
    }
  }

  Future<void> _handleUpdateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String? newPhotoURL = await _uploadImage();
        final success = await _authService.updateProfile(
          _fullNameController.text.trim(),
          newPhotoURL ?? _photoURL,
        );

        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
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
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Profile Picture with Edit Button
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path))
                        : (_photoURL != null ? NetworkImage(_photoURL!) : null)
                            as ImageProvider?,
                    child: _selectedImage == null && _photoURL == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _showImageSourceDialog,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showImageSourceDialog,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Change Profile Picture'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              // Full Name Field
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Update Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }
}

class NotificationPage extends StatelessWidget {
  NotificationPage({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _parseDate(dynamic dateField) {
    if (dateField is Timestamp) {
      return dateField.toDate();
    } else if (dateField is String) {
      return DateTime.parse(dateField);
    } else {
      throw const FormatException("Unsupported date format");
    }
  }

  Stream<Map<String, List<Map<String, dynamic>>>> _fetchCategorizedEvents() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield {};
      return;
    }

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .doc('shopping_events');

    yield* docRef.snapshots().map((docSnapshot) {
      final data = docSnapshot.data();
      if (data == null || !data.containsKey('events')) return {};

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final List events = data['events'];
      final categorized = {
        'Yesterday': <Map<String, dynamic>>[],
        'Today': <Map<String, dynamic>>[],
        'Upcoming': <Map<String, dynamic>>[],
      };

      for (var event in events) {
        try {
          final date = _parseDate(event['date']);
          final eventDay = DateTime(date.year, date.month, date.day);

          if (eventDay == yesterday) {
            categorized['Yesterday']!.add(event);
          } else if (eventDay == today) {
            categorized['Today']!.add(event);
          } else if (eventDay.isAfter(today)) {
            categorized['Upcoming']!.add(event);
          }
        } catch (e) {
          continue;
        }
      }

      return categorized;
    });
  }

  Future<void> _removeMissedEvent(BuildContext context, Map<String, dynamic> event) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final eventsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc('shopping_events');
      final eventsDoc = await eventsRef.get();
      List<Map<String, dynamic>> events = [];
      if (eventsDoc.exists) {
        events = List<Map<String, dynamic>>.from(eventsDoc.data()?['events'] ?? []);
      }
      // Remove the event by matching date and items
      events.removeWhere((e) => e['date'] == event['date'] && e['purchase']['items'].toString() == event['purchase']['items'].toString());
      await eventsRef.set({'events': events});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missed event removed!'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing event: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color.fromRGBO(76, 175, 80, 1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
        stream: _fetchCategorizedEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final categorizedEvents = snapshot.data ?? {};
          if (categorizedEvents.values.every((list) => list.isEmpty)) {
            return const Center(child: Text('No notification to show.'));
          }

          return ListView(
            children: categorizedEvents.entries.expand((entry) {
              if (entry.value.isEmpty) return <Widget>[];

              return [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...entry.value.map((shoppingEvent) {
                  final date = _parseDate(shoppingEvent['date']);
                  final formatted = DateFormat('MMMM dd, yyyy').format(date);
                  final amount = shoppingEvent['purchase']?['amount'] ?? 'N/A';
                  final items = shoppingEvent['purchase']?['items'] as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shopping_bag, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatted,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: date.isBefore(DateTime.now())
                                        ? Colors.red
                                        : Colors.green[900],
                                  ),
                                ),
                              ),
                              Text(
                                "Php $amount",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Items:",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          ...items.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 2, bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontSize: 15)),
                                Text('${entry.value}x', style: const TextStyle(color: Colors.blueGrey)),
                              ],
                            ),
                          )),
                          if (date.isBefore(DateTime.now()))
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.cancel),
                                label: const Text('Missed/Remove'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _removeMissedEvent(context, shoppingEvent),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ];
            }).toList(),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final AuthService _authService = AuthService();

  SettingsPage({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@restckr.com',
      queryParameters: {
        'subject': 'ReStckr Support Request',
        'body': 'Hello ReStckr Support Team,\n\nI need assistance with:',
      },
    );

    try {
      final String emailUrl = emailLaunchUri.toString();
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch email client'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleLogout(BuildContext context) async {
    try {
      await _authService.signOut();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await _authService.deleteAccount();

        if (!context.mounted) return;

        // Close loading dialog
        Navigator.pop(context);

        // Show success message and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (!context.mounted) return;

      // Close loading dialog if it's open
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.blue),
            title: const Text('Edit Profile',
                style: TextStyle(fontFamily: "Poppins", fontSize: 22)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditProfilePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.green),
            title: const Text('Privacy Policy',
                style: TextStyle(fontFamily: "Poppins", fontSize: 22)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
            title: const Text('About',
                style: TextStyle(fontFamily: "Poppins", fontSize: 22)),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'ReStckr',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 50,
                  color: Colors.green,
                ),
                applicationLegalese: '© 2024 ReStckr. All rights reserved.',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Developed by:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Vincent Sanchez\n'
                    '• Jhone Mayo\n'
                    '• Lei Suarez',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ReStckr is a comprehensive inventory management system designed to help businesses and individuals track their stock levels, manage purchases, and maintain an organized inventory.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Features:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Real-time stock tracking\n'
                    '• Purchase history\n'
                    '• Shopping cart management\n'
                    '• Activity monitoring\n'
                    '• Event scheduling',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.teal),
            title: const Text('Contact Support',
                style: TextStyle(fontFamily: "Poppins", fontSize: 22)),
            onTap: () => _launchEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(fontFamily: "Poppins", fontSize: 22)),
            onTap: () => _handleDeleteAccount(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout',
                style: TextStyle(fontFamily: "Poppins", fontSize: 22)),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: March 2024',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Information We Collect',
              'We collect information that you provide directly to us, including:\n\n'
                  '• Account information (name, email address)\n'
                  '• Shopping lists and preferences\n'
                  '• Purchase history\n'
                  '• Device information',
            ),
            _buildSection(
              'How We Use Your Information',
              'We use the information we collect to:\n\n'
                  '• Provide and maintain our services\n'
                  '• Process your transactions\n'
                  '• Send you notifications about your shopping lists\n'
                  '• Improve our services\n'
                  '• Communicate with you about updates and changes',
            ),
            _buildSection(
              'Data Security',
              'We implement appropriate security measures to protect your personal information. However, no method of transmission over the Internet is 100% secure.',
            ),
            _buildSection(
              'Your Rights',
              'You have the right to:\n\n'
                  '• Access your personal information\n'
                  '• Correct inaccurate data\n'
                  '• Request deletion of your data\n'
                  '• Opt-out of communications',
            ),
            _buildSection(
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                  'Email: support@restckr.com',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
