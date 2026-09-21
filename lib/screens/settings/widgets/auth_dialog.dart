import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';

Future<void> showAuthDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _AuthDialog(),
  );
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog();

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context, {required bool isSignUp}) async {
    final auth = context.read<AuthProvider>();
    final ok = isSignUp
        ? await auth.signUp(email: _emailController.text.trim(), password: _passwordController.text)
        : await auth.signIn(email: _emailController.text.trim(), password: _passwordController.text);
    if (ok && context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSignUp
                ? 'Conta criada. Verifique seu email para confirmar, se necessário.'
                : 'Login feito. Sincronizando progresso...',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AlertDialog(
      title: const Text('Entrar / Criar conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sincronize seu progresso de leitura entre aparelhos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha'),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              auth.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: auth.busy ? null : () => _submit(context, isSignUp: true),
          child: const Text('Criar conta'),
        ),
        FilledButton(
          onPressed: auth.busy ? null : () => _submit(context, isSignUp: false),
          child: auth.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Entrar'),
        ),
      ],
    );
  }
}
