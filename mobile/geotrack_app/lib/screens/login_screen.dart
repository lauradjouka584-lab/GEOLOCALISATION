// Page de connexion
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/auth_layout.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();           // sert à vérifier tout le formulaire
  final _emailController = TextEditingController();  // garde ce qui est tapé
  final _passwordController = TextEditingController();
  bool _hidePassword = true;                         // true = mot de passe caché
  bool _loading = false;                             // true = demande en cours
  String? _error;                                    // message d'erreur à afficher (ou rien)

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Appelée quand on appuie sur "Se connecter"
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;   // erreur dans le formulaire : on s'arrête

    setState(() {
      _loading = true;    // on affiche le petit cercle qui tourne
      _error = null;      // on efface l'ancienne erreur
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      await ApiService.instance.login(email, _passwordController.text);   // appel à l'API
      if (!mounted) return;
      // Succès : on ouvre la page d'accueil et on efface les pages précédentes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(email: email)),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);   // on affiche l'erreur
    } finally {
      if (mounted) setState(() => _loading = false);     // on arrête le cercle
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Connexion',

      // ----- Le formulaire -----
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthLabel('Adresse courriel'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: authFieldStyle(hint: 'nom@exemple.com', icon: Icons.mail_outline),
              validator: (value) {
                final v = (value ?? '').trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                  return 'Email invalide';
                }
                return null;   // null = tout est bon
              },
            ),
            const SizedBox(height: 16),

            const AuthLabel('Mot de passe'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              decoration: authFieldStyle(
                hint: '••••••••••••',
                icon: Icons.lock_outline,
                suffix: IconButton(   // l'œil pour montrer / cacher
                  icon: Icon(
                    _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Entrez votre mot de passe';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Message d'erreur du serveur (affiché seulement s'il y en a un)
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              const SizedBox(height: 12),
            ],

            FilledButton(
              // onPressed = null désactive le bouton pendant le chargement
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Se connecter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ],
        ),
      ),

      // ----- Lien vers la page d'inscription -----
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            "Vous n'avez pas de compte ? ",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Inscrivez-vous', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}