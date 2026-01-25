// login_screen.dart
import 'package:flutter/material.dart';

import 'backend_service.dart';
import 'models.dart';
import 'view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await BackendService.loginOrRegister(name);

      if (user != null) {
        // Store user session
        UserSession.instance.setUser(user);

        // Navigate to home page (Socket.IO connects there)
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeAccountsPage(userId: user.id),
            ),
          );
        }
      } else {
        setState(() => _error = 'Could not connect to server');
      }
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);

    return Scaffold(
      body: PageEntrance(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.surface,
                colors.surfaceMuted,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Logo/Title
                  Icon(
                    Icons.account_balance,
                    size: 80,
                    color: colors.text,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Chameleon's Eye",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adventure Banking',
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Name input
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'Enter your explorer name',
                        prefixIcon: Icon(Icons.person_outline, color: colors.textMuted),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.text, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  if (_error != null)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Login button
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.text,
                        foregroundColor: colors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.surface,
                              ),
                            )
                          : const Text(
                              'Begin Adventure',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer hint
                  Text(
                    'Your treasure awaits...',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textMuted,
                      fontStyle: FontStyle.italic,
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

/// Simple session storage for the logged-in user
class UserSession {
  static final UserSession instance = UserSession._();
  UserSession._();

  UserWithAccounts? _user;

  void setUser(UserWithAccounts user) {
    _user = user;
  }

  UserWithAccounts? get user => _user;
  String? get userId => _user?.id;
  String? get userName => _user?.name;

  void clear() {
    _user = null;
    BackendService.disconnect();
  }
}
