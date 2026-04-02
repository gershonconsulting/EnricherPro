import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _companyCtrl,
      _titleCtrl, _emailCtrl, _passwordCtrl, _confirmCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    if (!v.contains(RegExp(r'[a-zA-Z]'))) return 'Must contain a letter';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Welcome, ${auth.user?.firstName ?? ''}! Account created.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Registration failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading
              ? null
              : () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.person_add,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('Create New Account',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Fill in your details to get started',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey[700])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name row
                  Row(
                    children: [
                      Expanded(child: _field(_firstNameCtrl, 'First Name *',
                          Icons.person_outline,
                          validator: (v) => _required(v, 'First Name'),
                          capitalize: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_lastNameCtrl, 'Last Name *',
                          Icons.person_outline,
                          validator: (v) => _required(v, 'Last Name'),
                          capitalize: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(_companyCtrl, 'Company *', Icons.business,
                      validator: (v) => _required(v, 'Company'), capitalize: true),
                  const SizedBox(height: 16),
                  _field(_titleCtrl, 'Job Title *', Icons.work_outline,
                      validator: (v) => _required(v, 'Job Title'), capitalize: true),
                  const SizedBox(height: 16),
                  _field(_emailCtrl, 'Email Address *', Icons.email_outlined,
                      validator: _validateEmail,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Min. 8 chars, 1 letter, 1 number',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm your password';
                      if (v != _passwordCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Create Account',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context)
                                .pushReplacementNamed('/login'),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    bool capitalize = false,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: !_loading,
      keyboardType: keyboard,
      textCapitalization:
          capitalize ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }
}
