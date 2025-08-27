// presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../bloc/auth_event.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // ❌ remove UI code here later if you want zero logic
          if (state is AuthError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to Papercraft',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // UI for loading
                  if (state is AuthLoading)
                    const _LoadingIndicator()
                  else
                    _LoginButton(
                      onPressed: () {
                        // Keep just the trigger here
                        context.read<AuthBloc>().add(SignInWithGoogleEvent());
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ✅ Pure UI widgets
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Signing in...'),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.login),
      label: const Text("Sign in with Google"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      onPressed: onPressed,
    );
  }
}
