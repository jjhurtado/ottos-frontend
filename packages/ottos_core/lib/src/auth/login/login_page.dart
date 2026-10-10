import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/core_texts.dart';
import '../../theme/ottos_colors.dart';
import '../../widgets/ottos_logo.dart';
import '../auth_repository.dart';
import '../bloc/auth_bloc.dart';
import 'login_cubit.dart';

/// Login screen shared by every app. Expects an [AuthRepository], an
/// [AuthBloc] and an [AccessPolicy] above it.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.appName});

  /// Shown under the logo, e.g. "Panel de operaciones".
  final String appName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(
        authRepository: context.read<AuthRepository>(),
        authBloc: context.read<AuthBloc>(),
        accessPolicy: context.read<AccessPolicy>(),
      ),
      child: Scaffold(
        backgroundColor: OttosColors.navy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const OttosLogo(size: 180),
                    Text(appName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: OttosColors.cream)),
                    const SizedBox(height: 24),
                    const _LoginForm(),
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

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginCubit>().submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final sessionExpired = context.select((AuthBloc bloc) => bloc.state.sessionExpired);
    final passwordChanged = context.select((AuthBloc bloc) => bloc.state.passwordChanged);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, state) {
            final error = state.error ?? (sessionExpired ? CoreTexts.sessionExpired : null);
            return Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(CoreTexts.loginTitle, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      enabled: !state.isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: CoreTexts.email,
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return CoreTexts.emailRequired;
                        if (!email.contains('@')) return CoreTexts.emailInvalid;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !state.isSubmitting,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: CoreTexts.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? CoreTexts.showPassword : CoreTexts.hidePassword,
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty ? CoreTexts.passwordRequired : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ] else if (passwordChanged) ...[
                      const SizedBox(height: 16),
                      Text(CoreTexts.passwordChanged, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.isSubmitting ? null : _submit,
                      child: state.isSubmitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(CoreTexts.enter),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
