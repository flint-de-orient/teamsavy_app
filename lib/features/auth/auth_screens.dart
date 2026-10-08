import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../shell/logo.dart';
import '../../widgets/ts.dart';
import 'auth_shell.dart';

/// app/login: "Welcome back" with the Password | WhatsApp switch.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _mode = 'password';

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return AuthShell(
      title: 'Welcome back',
      description: 'Sign in to your account to continue.',
      child: Gap(
        children: [
          TsSegmented<String>(
            value: _mode,
            options: const [SelectOption('password', 'Password'), SelectOption('whatsapp', 'WhatsApp')],
            onChanged: (v) => setState(() => _mode = v),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _mode == 'password' ? const _PasswordForm() : const _WhatsAppForm(),
          ),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('New to TeamSavy? ', style: tx(12, color: p.muted)),
                TsLink(
                  'Start a free trial',
                  size: 12,
                  onTap:
                      () => launchUrl(Uri.parse('${AppConfig.baseUrl}/signup'), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _pending = false;
  String? _error;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final res = await api.post('/auth/login', {'email': _email.text.trim(), 'password': _password.text});
      await session.signIn(res.s('token'));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Gap(
        children: [
          TsInput(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TsInput(
                controller: _password,
                label: 'Password',
                obscure: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 6),
              TsLink('Forgot password?', size: 12, onTap: () => context.push('/forgot-password')),
            ],
          ),
          if (_error != null) StatusMessage.error(_error),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TsButton(
              label: 'Sign in',
              pendingLabel: 'Signing in...',
              pending: _pending,
              expand: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppForm extends StatefulWidget {
  const _WhatsAppForm();

  @override
  State<_WhatsAppForm> createState() => _WhatsAppFormState();
}

class _WhatsAppFormState extends State<_WhatsAppForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _pending = false;
  String? _error;

  Future<void> _request() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final res = await api.post('/auth/whatsapp/request', {'phoneNumber': _phone.text.trim()});
      final result = res.m('result');
      if (result.sn('error') != null) {
        setState(() => _error = result.s('error'));
      } else {
        setState(() => _codeSent = true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final res = await api.post('/auth/whatsapp/verify', {
        'phoneNumber': _phone.text.trim(),
        'code': _code.text.trim(),
      });
      await session.signIn(res.s('token'));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (!_codeSent) {
      return Gap(
        children: [
          TsInput(
            controller: _phone,
            label: 'WhatsApp Number',
            placeholder: '9876543210',
            hint: 'The 10-digit number you verified under WhatsApp Login in settings.',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: TsInput.digitsOnly,
            autofocus: true,
          ),
          if (_error != null) StatusMessage.error(_error),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TsButton(
              label: 'Send Code',
              pendingLabel: 'Sending...',
              pending: _pending,
              expand: true,
              onPressed: _request,
            ),
          ),
        ],
      );
    }
    return Gap(
      children: [
        Text.rich(
          TextSpan(
            style: tx(14, color: p.muted),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(text: _phone.text, style: tx(14, weight: FontWeight.w500, color: p.foreground)),
              const TextSpan(text: ' over WhatsApp, if that number is set up for WhatsApp login.'),
            ],
          ),
        ),
        TsInput(
          controller: _code,
          label: 'Verification Code',
          placeholder: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: TsInput.digitsOnly,
          autofocus: true,
          autofillHints: const [AutofillHints.oneTimeCode],
        ),
        if (_error != null) StatusMessage.error(_error),
        TsButton(
          label: 'Verify & Sign In',
          pendingLabel: 'Signing in...',
          pending: _pending,
          expand: true,
          onPressed: _verify,
        ),
        Center(
          child: TsLink(
            'Use a different number',
            color: p.muted,
            weight: FontWeight.w400,
            onTap: () {
              setState(() {
                _codeSent = false;
                _error = null;
                _code.clear();
              });
            },
          ),
        ),
      ],
    );
  }
}

/// app/forgot-password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _pending = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final res = await api.post('/auth/forgot-password', {'email': _email.text.trim()});
      final result = res.m('result');
      if (result.sn('error') != null) {
        setState(() => _error = result.s('error'));
      } else {
        setState(() => _sent = true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return AuthShell(
      title: 'Reset your password',
      description: "Enter your email and we'll send you a link to reset your password.",
      compactHero: true,
      child:
          _sent
              ? Gap(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "If an account exists for that email, we've sent a link to reset your password. It's valid for 1 hour.",
                    style: tx(14, color: p.foreground, height: 1.5),
                  ),
                  TsLink('Back to sign in', onTap: () => context.go('/login')),
                ],
              )
              : Gap(
                children: [
                  TsInput(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  if (_error != null) StatusMessage.error(_error),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TsButton(
                      label: 'Send reset link',
                      pendingLabel: 'Sending...',
                      pending: _pending,
                      expand: true,
                      onPressed: _submit,
                    ),
                  ),
                  Center(child: TsLink('Back to sign in', color: p.muted, onTap: () => context.go('/login'))),
                ],
              ),
    );
  }
}

/// app/change-password - also the forced first-login gate.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await api.action(
      'core.changePassword',
      fields: {'currentPassword': _current.text, 'newPassword': _next.text, 'confirmPassword': _confirm.text},
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
    if (r.ok) {
      await session.refreshMe();
      if (!mounted) return;
      toast(context, 'Password changed.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(session.me?.homePath ?? '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final forced = session.me?.mustChangePassword ?? false;
    return PlainAuthPage(
      showBack: !forced && context.canPop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Change Password', style: tx(18, weight: FontWeight.w600, color: p.foreground)),
          const SizedBox(height: 4),
          Text(
            forced ? 'Set a new password to continue.' : 'Update the password for your account.',
            style: tx(14, color: p.muted),
          ),
          const SizedBox(height: 24),
          Gap(
            children: [
              TsInput(controller: _current, label: 'Current Password', obscure: true),
              TsInput(controller: _next, label: 'New Password', obscure: true),
              TsInput(controller: _confirm, label: 'Confirm New Password', obscure: true),
              if (_error != null) StatusMessage.error(_error),
              TsButton(label: 'Change Password', pendingLabel: 'Saving...', pending: _pending, onPressed: _submit),
              if (forced) Center(child: TsLink('Sign out', color: p.muted, onTap: () => session.signOut())),
            ],
          ),
        ],
      ),
    );
  }
}

/// app/suspended.
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final trial = session.suspendedReason == 'trial';
    return PlainAuthPage(
      child: Column(
        children: [
          Text(
            trial ? 'Trial ended' : 'Access suspended',
            textAlign: TextAlign.center,
            style: tx(20, weight: FontWeight.w600, color: p.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            trial
                ? 'Your trial period has ended. Contact us to continue on a paid plan.'
                : "Your organization's access has been suspended. Contact support to resolve this.",
            textAlign: TextAlign.center,
            style: tx(14, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 32),
          TsButton.secondary(label: 'Sign out', onPressed: () => session.signOut()),
        ],
      ),
    );
  }
}

/// Shown while the stored session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Scaffold(
      backgroundColor: p.brandPanel,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingLogo(),
            const SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: const TeamSavyLogo(height: 34, forceWhite: true),
    );
  }
}
