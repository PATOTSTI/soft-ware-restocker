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
          displayLarge: TextStyle(fontSize: 70, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic), //Restckr
          displayMedium: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 26), //Cart,Stock,Event,Activity, Sign-up
          bodyLarge: TextStyle(fontSize: 22,),
          bodyMedium: TextStyle(fontSize: 20),
          labelLarge: TextStyle(fontSize: 16),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(76, 175, 80, 1)),
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
                    const SizedBox(height: 0),
                    // Logo
                    Image.asset(
                      'lib/assets/logo.png',
                      width: 93,
                      height: 93,
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white70),
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: Theme.of(context).textTheme.bodyMedium
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
                                : const Text('LOGIN'),
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
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                                style: Theme.of(context).textTheme.labelLarge),
                              TextButton(
                                onPressed: () => navigateWithFade(
                                  context,
                                  const SignUpPage(),
                                ),
                                child:  Text(
                                  'Sign up',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.orange
                                ),)
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Social Login Divider
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child:  Text('Sign in with',
                                  style: TextStyle(
                                    fontFamily: "Poppins",
                                    fontSize: 16
                                    )
                                  ),
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
                                icon: const FaIcon(
                                    FontAwesomeIcons.google,
                                    color: Colors.red
                                ),
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
    const accentColor = Colors.orange; // Use your app's accent color
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
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color.fromRGBO(76, 175, 80, 1), width: 4),
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
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
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
                        labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey
                        ),
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
                        labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey
                        ),
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
                            color: accentColor
                          ),
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
                          ),textStyle: Theme.of(context).textTheme.bodyMedium,
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
                              fontSize: 22,
                              color: accentColor,
                              decoration: TextDecoration.underline,
                              decorationColor: accentColor
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
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height -
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
          children: [Image.asset('lib/assets/logo.png', width:40, height:40), const SizedBox(width: 3), Text(_title,
          style: const TextStyle(
            fontFamily: "Poppins",
            fontSize: 30,
            fontWeight: FontWeight.w400))],
        ),
        actions: [
          const IconButton(icon: Icon(Icons.notifications), onPressed: null, iconSize: 25),
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
          ActivityPage(
            purchaseHistory: _purchaseHistory,
            cartItems: _cartItems,
          ),
          const EventsPage(),
        ],
      ),
        bottomNavigationBar: BottomNavigationBar(currentIndex: _selectedIndex,
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
            BottomNavigationBarItem(icon: Icon(Icons.inventory, size: 30), label: 'Stocks'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart, size: 30), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.history, size: 30), label: 'Activity'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today, size: 30), label: 'Events'
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

          // Update each section to match original quantities
          final originalDocRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('stocks')
              .doc('original_stock_data');
          final originalDoc = await originalDocRef.get();

          if (originalDoc.exists) {
            final originalData = originalDoc.data() as Map<String, dynamic>;

            // Update stock data to match original quantities
            Map<String, dynamic> updatedStockData = {};
            originalData.forEach((section, items) {
              updatedStockData[section] = items;
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

      // Reset stock to original quantities
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

        final originalDoc = await originalDocRef.get();
        if (originalDoc.exists) {
          final originalData = originalDoc.data() as Map<String, dynamic>;
          await stockDocRef.set(originalData);
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
                  // Store the shopping date and purchase details
                  await _storeShoppingEvent(picked, purchase);
                  Navigator.pop(context);
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
    try {
      // Debug log
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Debug log
        return;
      }

      // Debug log

      // First, close the date selection dialog
      if (mounted) {
        Navigator.pop(context);
        // Debug log
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final eventsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc('shopping_events');

      // Debug log
      // Get existing events
      final eventsDoc = await eventsRef.get();
      List<Map<String, dynamic>> events = [];
      if (eventsDoc.exists) {
        events =
            List<Map<String, dynamic>>.from(eventsDoc.data()?['events'] ?? []);
        // Debug log
      } else {
        // Debug log
      }

      // Add new event
      final newEvent = {
        'date': date.toIso8601String(),
        'purchase': {
          'date': purchase.date.toIso8601String(),
          'amount': purchase.amount,
          'items': purchase.items,
        },
      };
      events.add(newEvent);
      // Debug log

      // Save updated events
      // Debug log
      await eventsRef.set({'events': events});
      // Debug log

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Shopping date set for ${DateFormat('MMMM dd, yyyy').format(date)}'),
            backgroundColor: Colors.green,
          ),
        );
        // Debug log

        // Switch to events page
        setState(() {
          _selectedIndex = 3; // Switch to Events tab
        });
        // Debug log
      }
    } catch (e) {
      // Debug log
      // Debug log

      // Close loading indicator if it's showing
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
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

      // Also save original stock data if not already present
      final originalDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .doc('original_stock_data');
      final originalDoc = await originalDocRef.get();
      if (!originalDoc.exists) {
        await originalDocRef.set({
          for (var entry in _sectionItems.entries) entry.key: entry.value,
        });
      }

      // Convert and notify parent
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

      // Notify parent about stock update
      if (widget.onStockUpdate != null) {
        widget.onStockUpdate!(updatedStock);
      }

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

        // Convert and notify parent about the loaded stock data
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

        // Notify parent about stock update
        if (widget.onStockUpdate != null) {
          widget.onStockUpdate!(updatedStock);
        }
      } else {
        // If no data exists, pre-populate with default values
        await _prePopulateStockItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stock data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  ) async {
    setState(() {
      item['quantity'] = newQuantity;
      if (newQuantity == 0) {
        item['isOutOfStock'] = true;
      } else {
        item['isOutOfStock'] = false;
      }
    });

    // Convert current state to CartItems format and notify parent immediately
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

    // Update the entire section in Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stocks')
            .doc('stock_data');
        await docRef.update({
          section: _sectionItems[section],
        });
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

    // Save the cart after every deduction
    if (widget.onStockUpdate != null) {
      widget.onStockUpdate!(updatedStock);
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
          await docRef.update({
            section: [],
          });
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
                fontFamily: "Poppins",
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first item',
              style: TextStyle(fontFamily: "Poppins", fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddItemBottomSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                          title: Text(item['name'], style:Theme.of(context).textTheme.labelLarge),
                          subtitle: Text(
                            'Php ${item['price'].toStringAsFixed(2)}',
                            style:Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey
                            )
                          ),
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
          icon: const Icon(Icons.delete_sweep_outlined , size: 25),
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

                  await docRef.update({
                    section: _sectionItems[section],
                  });
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
                        prefixIcon: Icon(Icons.attach_money),
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

                          await docRef.update({
                            selectedSection: _sectionItems[selectedSection],
                          });

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
                              await originalDocRef.update({
                                selectedSection: originalSection,
                              });
                            }
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
                purchase.items.values
                    .fold(0, (sum, quantity) => sum + quantity);
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
                          spots: monthlyUsage.asMap().entries.map((entry) {
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
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: monthlyRestocks.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              color: entry.key == monthlyRestocks.length - 1
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
              Future<void> _deleteEvent(int index, List<Map<String, dynamic>> events) async {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: const Text('Are you sure you want to delete this shopping event?'),
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
                    // Show loading indicator
                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // Remove the event from the list
                    events.removeAt(index);

                    // Update Firestore
                    final eventsRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('events')
                        .doc('shopping_events');

                    await eventsRef.set({'events': events});

                    // Close loading indicator
                    if (mounted) {
                      Navigator.pop(context);
                    }

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
                  // Close loading indicator if it's showing
                  if (mounted) {
                    Navigator.pop(context);
                  }

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
                    onPressed: () => _deleteEvent(index, events),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${entry.key}x',
                                    style: const TextStyle(
                                      fontFamily: "Poppins",
                                      fontSize:16,)),
                                  Text(
                                    '${entry.value}x',
                                    style: const TextStyle(
                                      fontFamily: "Poppins",
                                      fontSize:16,
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
  bool _isLoading = false;
  String? _photoURL;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
        final success = await _authService.updateProfile(
          _fullNameController.text.trim(),
          _photoURL,
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
              // Profile Picture
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    _photoURL != null ? NetworkImage(_photoURL!) : null,
                child: _photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
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
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 22
            )),
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
              style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 22
              )
            ),
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
              style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 22)),
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
            style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 22)
            ),
            onTap: () => _launchEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account',
            style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 22)),
            onTap: () => _handleDeleteAccount(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout',
              style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 22)),
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
