import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Logo Boulfrik (carré rouge arrondi).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF43F5E), AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: size * 0.4, offset: Offset(0, size * 0.12))],
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.shopping_basket_rounded, color: Colors.white.withValues(alpha: 0.18), size: size * 0.9),
        Text('B', style: TextStyle(color: Colors.white, fontSize: size * 0.52, fontWeight: FontWeight.w900, height: 1)),
      ]),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _server = TextEditingController(text: SessionScope.read(context).api.baseUrl);
  bool _busy = false;
  bool _obscure = true;
  bool _showServer = false;
  int _logoTaps = 0;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = SessionScope.read(context);
    try {
      if (_server.text.trim().isNotEmpty && _server.text.trim() != session.api.baseUrl) {
        await session.setServer(_server.text);
        _server.text = session.api.baseUrl;
      }
      await session.login(_email.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = switch (e.status) {
            422 => e.field('email') ?? e.field('password') ?? 'E-mail ou mot de passe incorrect.',
            403 => e.message.isNotEmpty ? e.message : 'Ce compte est désactivé.',
            _ => e.message,
          });
    } catch (_) {
      setState(() => _error = 'Connexion impossible.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Stack(children: [
          // Halo décoratif.
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.18)),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(children: [
                    // 7 appuis sur le logo affichent le réglage du serveur (tests uniquement).
                    GestureDetector(
                      onTap: () {
                        if (++_logoTaps >= 7) setState(() => _showServer = true);
                      },
                      child: const BrandLogo(),
                    ),
                    const SizedBox(height: 18),
                    const Text('Boulfrik',
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 28),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _form,
                          child: AutofillGroup(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.mail_outline)),
                                validator: (v) => (v == null || !v.contains('@')) ? 'Saisissez votre adresse e-mail.' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Saisissez votre mot de passe.' : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                    : const Text('Se connecter'),
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 200),
                                crossFadeState: _showServer ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                firstChild: const SizedBox(width: double.infinity),
                                secondChild: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _server,
                                    keyboardType: TextInputType.url,
                                    autocorrect: false,
                                    decoration: InputDecoration(
                                      labelText: 'Adresse du serveur',
                                      hintText: defaultServer,
                                      isDense: true,
                                      suffixIcon: IconButton(
                                        tooltip: 'Par défaut',
                                        icon: const Icon(Icons.restart_alt),
                                        onPressed: () => setState(() => _server.text = defaultServer),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'À modifier uniquement pour un serveur de test (ex. http://10.0.2.2:8000).',
                                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
