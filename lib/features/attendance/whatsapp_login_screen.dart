import '../../widgets/ts.dart';

/// app/(app)/whatsapp-login/page.tsx + whatsapp-login-form.tsx (every role):
/// link a WhatsApp number by OTP so it can be used to sign in.
class WhatsAppLoginScreen extends StatelessWidget {
  const WhatsAppLoginScreen({super.key});

  static const _header = PageHeader(
    title: 'WhatsApp Login',
    description: 'Verify a WhatsApp number once, then use it to log in with a one-time code instead of your password.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/whatsapp-login',
      header: _header,
      builder: (context, data, reload) {
        final p = Ts.of(context);
        return [
          _header,
          if (data.b('verified'))
            TsPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: p.successLight, borderRadius: BorderRadius.circular(Ts.rXl)),
                    child: Icon(LucideIcons.messageCircle, size: 18, color: p.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.s('maskedNumber'), style: tx(14, weight: FontWeight.w500, color: p.foreground)),
                        const SizedBox(height: 2),
                        Text('Verified - usable for WhatsApp OTP login.', style: tx(12, color: p.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const TsBadge('Linked', tone: BadgeTone.green),
                ],
              ),
            )
          else
            const Muted('No WhatsApp number linked yet.'),
          TsCard(
            title: data.b('hasNumber') ? 'Change number' : 'Link a number',
            child: const _WhatsAppLoginForm(key: ValueKey('whatsapp-login-form')),
          ),
        ];
      },
    );
  }
}

class _WhatsAppLoginForm extends StatefulWidget {
  const _WhatsAppLoginForm({super.key});

  @override
  State<_WhatsAppLoginForm> createState() => _WhatsAppLoginFormState();
}

class _WhatsAppLoginFormState extends State<_WhatsAppLoginForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _pending = false;
  String? _error;
  bool _verified = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await api.action('core.requestWhatsAppVerification', fields: {'phoneNumber': _phone.text});
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok) {
        _codeSent = true;
        _verified = false;
        _code.clear();
      }
    });
  }

  Future<void> _verify() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('core.verifyWhatsAppNumber', fields: {'phoneNumber': _phone.text, 'code': _code.text}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _verified = r.ok;
    });
    // The drawer/profile read whatsappLinked from /me.
    if (r.ok) session.refreshMe().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (!_codeSent) {
      return Gap(
        gap: 16,
        children: [
          TsInput(
            controller: _phone,
            label: 'WhatsApp Number',
            placeholder: '9876543210',
            hint: '10-digit mobile number, no country code needed.',
            keyboardType: TextInputType.phone,
            inputFormatters: TsInput.digitsOnly,
            maxLength: 10,
            autofillHints: const [AutofillHints.telephoneNumberNational],
          ),
          if (_error != null) StatusMessage.error(_error),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(label: 'Send Code', pendingLabel: 'Sending...', pending: _pending, onPressed: _send),
          ),
        ],
      );
    }
    return Gap(
      gap: 16,
      children: [
        Text.rich(
          TextSpan(
            style: tx(14, color: p.muted, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(text: _phone.text, style: tx(14, weight: FontWeight.w500, color: p.foreground)),
              const TextSpan(text: ' over WhatsApp.'),
            ],
          ),
        ),
        TsInput(
          controller: _code,
          label: 'Verification Code',
          placeholder: '000000',
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
        ),
        if (_error != null) StatusMessage.error(_error),
        if (_verified) StatusMessage.success('Verified - you can now log in with WhatsApp OTP.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TsButton(label: 'Verify', pendingLabel: 'Verifying...', pending: _pending, onPressed: _verify),
            TsButton.ghost(
              label: 'Use a different number',
              onPressed: () => setState(() {
                _codeSent = false;
                _error = null;
                _verified = false;
              }),
            ),
          ],
        ),
      ],
    );
  }
}
