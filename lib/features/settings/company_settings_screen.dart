import '../../widgets/ts.dart';
import 'settings_widgets.dart';

const _notAuthorized = 'You are not authorized to update company settings.';
const _imageTypes = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'svg'];

/// app/(app)/settings/company/page.tsx: the company details form, Email
/// Sender Details and SMTP Configuration, each its own form. HR_ADMIN can
/// open the page but only TENANT_ADMIN can save, so for HR the forms are
/// shown read-only.
class CompanySettingsScreen extends StatelessWidget {
  const CompanySettingsScreen({super.key});

  static const _header = PageHeader(
    title: 'Company Settings',
    description: 'Branding and legal details used on every appointment letter.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/company',
      header: _header,
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        final company = data.mN('company');
        return [
          _header,
          if (!canWrite) const ReadOnlyNote(_notAuthorized),
          TsCard(child: _CompanyDetailsForm(company: company, canWrite: canWrite)),
          const SectionTitle(
            'Email Sender Details',
            description: 'Drives the "From" display and signature block on offer/invite emails.',
          ),
          TsCard(child: _EmailSenderForm(company: company, canWrite: canWrite)),
          const SectionTitle(
            'SMTP Configuration',
            description:
                'Mail server credentials used to send offer and portal-invite emails. Editable here so they can be changed without a code deploy.',
          ),
          TsCard(child: _SmtpForm(company: company, canWrite: canWrite)),
        ];
      },
    );
  }
}

class _CompanyDetailsForm extends StatefulWidget {
  const _CompanyDetailsForm({required this.company, required this.canWrite});
  final Json? company;
  final bool canWrite;

  @override
  State<_CompanyDetailsForm> createState() => _CompanyDetailsFormState();
}

class _CompanyDetailsFormState extends State<_CompanyDetailsForm> {
  late final FieldControllers _f = FieldControllers({
    'legalName': widget.company?.sn('legalName'),
    'abbreviation': widget.company?.sn('abbreviation') ?? 'FDO',
    'jurisdictionCity': widget.company?.sn('jurisdictionCity'),
    'registeredAddress': widget.company?.sn('registeredAddress'),
    'cin': widget.company?.sn('cin'),
    'gstin': widget.company?.sn('gstin'),
    'pfEstablishmentCode': widget.company?.sn('pfEstablishmentCode'),
    'esiEstablishmentCode': widget.company?.sn('esiEstablishmentCode'),
    'tanNumber': widget.company?.sn('tanNumber'),
    'companyPan': widget.company?.sn('companyPan'),
    'email': widget.company?.sn('email'),
    'contactNumber': widget.company?.sn('contactNumber'),
    'website': widget.company?.sn('website'),
    'signatoryName': widget.company?.sn('signatoryName'),
    'signatoryDesignation': widget.company?.sn('signatoryDesignation'),
  });

  UploadFile? _logo;
  UploadFile? _signature;
  int _imageVersion = 0;
  bool _pending = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _success = false;
    });
    final r = await runAction(
      context,
      () => api.action(
        'settings.updateCompanySettings',
        fields: _f.values,
        files: {'logo': _logo, 'signature': _signature},
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
      if (r.ok) {
        // The web form resets after a successful save, clearing the file
        // inputs; the previews then show the newly stored images.
        _logo = null;
        _signature = null;
        _imageVersion++;
      }
    });
  }

  Widget _input(String name, String label, {TextInputType? keyboard, int? maxLines}) => TsInput(
        controller: _f[name],
        label: label,
        enabled: widget.canWrite,
        keyboardType: keyboard,
        maxLines: maxLines ?? 1,
      );

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.canWrite;
    final hasLogo = widget.company?.b('hasLogo') ?? false;
    final hasSignature = widget.company?.b('hasSignature') ?? false;
    return Gap(
      children: [
        _input('legalName', 'Legal Name'),
        _input('abbreviation', 'Abbreviation (used in Memo No.)'),
        _input('jurisdictionCity', 'Jurisdiction City'),
        // Wraps for long addresses but stays a single-line value like the
        // web input (the text keyboard's action key never inserts a newline).
        _input('registeredAddress', 'Registered Office Address', keyboard: TextInputType.text, maxLines: 3),
        _input('cin', 'CIN'),
        _input('gstin', 'GSTIN'),
        TsPanel(
          color: Ts.of(context).surfaceHover.withValues(alpha: 0.5),
          child: Gap(
            gap: 12,
            children: [
              Text('Payroll Statutory Registrations',
                  style: tx(14, weight: FontWeight.w500, color: Ts.of(context).foreground)),
              const Muted(
                "Optional — only needed if the Payroll module is in use. TAN is legally required before any TDS can be deducted from an employee's pay.",
                size: 12,
              ),
              _input('pfEstablishmentCode', 'PF Establishment Code'),
              _input('esiEstablishmentCode', 'ESI Establishment Code'),
              _input('tanNumber', 'TAN'),
              _input('companyPan', 'Company PAN'),
            ],
          ),
        ),
        _input('email', 'Email', keyboard: TextInputType.emailAddress),
        _input('contactNumber', 'Contact Number', keyboard: TextInputType.phone),
        _input('website', 'Website', keyboard: TextInputType.url),
        _input('signatoryName', 'Default Signatory Name'),
        _input('signatoryDesignation', 'Default Signatory Designation'),
        _ImageField(
          label: 'Logo',
          path: '/api/files/logo',
          hasImage: hasLogo,
          version: _imageVersion,
          canWrite: canWrite,
          file: _logo,
          onChanged: (f) => setState(() => _logo = f),
        ),
        _ImageField(
          label: "Authorised Signatory's Signature",
          path: '/api/files/signature',
          hasImage: hasSignature,
          version: _imageVersion,
          canWrite: canWrite,
          file: _signature,
          onChanged: (f) => setState(() => _signature = f),
          hint:
              "A scanned or photographed signature on a plain/white background works best. It will appear above the signatory's name on every issued letter.",
        ),
        if (canWrite) ...[
          FormStatus(error: _error, success: _success ? 'Company settings saved.' : null),
          SubmitButton(label: 'Save Company Settings', pending: _pending, onPressed: _save),
        ],
      ],
    );
  }
}

/// "Logo" / "Authorised Signatory's Signature": the current image (if one
/// is stored) above the file picker.
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.label,
    required this.path,
    required this.hasImage,
    required this.version,
    required this.canWrite,
    required this.file,
    required this.onChanged,
    this.hint,
  });
  final String label;
  final String path;
  final bool hasImage;
  final int version;
  final bool canWrite;
  final UploadFile? file;
  final ValueChanged<UploadFile?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
        const SizedBox(height: 6),
        if (hasImage) ...[
          ProtectedImage(path: path, version: version),
          const SizedBox(height: 8),
        ],
        if (canWrite)
          TsFileField(file: file, onChanged: onChanged, accept: _imageTypes, placeholder: 'Choose an image', hint: hint)
        else if (!hasImage)
          Text('—', style: tx(14, color: p.muted)),
      ],
    );
  }
}

class _EmailSenderForm extends StatefulWidget {
  const _EmailSenderForm({required this.company, required this.canWrite});
  final Json? company;
  final bool canWrite;

  @override
  State<_EmailSenderForm> createState() => _EmailSenderFormState();
}

class _EmailSenderFormState extends State<_EmailSenderForm> {
  late final FieldControllers _f = FieldControllers({
    'emailSenderName': widget.company?.sn('emailSenderName'),
    'emailSenderDesignation': widget.company?.sn('emailSenderDesignation'),
    'emailSenderContactNo': widget.company?.sn('emailSenderContactNo'),
    'emailSenderEmail': widget.company?.sn('emailSenderEmail'),
    'emailSenderWebsite': widget.company?.sn('emailSenderWebsite'),
  });
  bool _pending = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _success = false;
    });
    final r = await runAction(
      context,
      () => api.action('settings.updateEmailSenderDetails', fields: _f.values),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final canWrite = widget.canWrite;
    final legalName = widget.company?.sn('legalName');
    return Gap(
      children: [
        TsInput(controller: _f['emailSenderName'], label: 'Name of Sender', enabled: canWrite),
        TsInput(controller: _f['emailSenderDesignation'], label: 'Designation', enabled: canWrite),
        FieldWrapper(
          label: 'Company',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.surfaceHover,
              borderRadius: BorderRadius.circular(Ts.r2xl),
              border: Border.all(color: p.border),
            ),
            child: Text('${legalName ?? '— set Legal Name above —'} (auto-fetched)', style: tx(14, color: p.muted)),
          ),
        ),
        TsInput(
          controller: _f['emailSenderContactNo'],
          label: 'Contact No',
          enabled: canWrite,
          keyboardType: TextInputType.phone,
        ),
        TsInput(
          controller: _f['emailSenderEmail'],
          label: 'Email',
          enabled: canWrite,
          keyboardType: TextInputType.emailAddress,
        ),
        TsInput(
          controller: _f['emailSenderWebsite'],
          label: 'Website',
          enabled: canWrite,
          keyboardType: TextInputType.url,
        ),
        if (canWrite) ...[
          FormStatus(error: _error, success: _success ? 'Email sender details saved.' : null),
          SubmitButton(label: 'Save Email Sender Details', pending: _pending, onPressed: _save),
        ],
      ],
    );
  }
}

class _SmtpForm extends StatefulWidget {
  const _SmtpForm({required this.company, required this.canWrite});
  final Json? company;
  final bool canWrite;

  @override
  State<_SmtpForm> createState() => _SmtpFormState();
}

class _SmtpFormState extends State<_SmtpForm> {
  late final FieldControllers _f = FieldControllers({
    'smtpHost': widget.company?.sn('smtpHost'),
    'smtpPort': widget.company?.sn('smtpPort') ?? '465',
    'smtpUser': widget.company?.sn('smtpUser'),
    'smtpPassword': '',
  });

  bool _saving = false;
  String? _saveError;
  bool _saveSuccess = false;
  bool _testing = false;
  String? _testError;
  bool _testSuccess = false;

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = false;
    });
    final r = await runAction(
      context,
      () => api.action('settings.updateSmtpSettings', fields: _f.values),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = r.error;
      _saveSuccess = r.ok;
      // A blank password keeps the saved one, so the field is cleared once
      // it has been stored (the web form resets the same way).
      if (r.ok) _f['smtpPassword'].clear();
    });
  }

  Future<void> _test() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _testError = null;
      _testSuccess = false;
    });
    final r = await api.action('settings.testSmtpConnection', fields: _f.values);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testError = r.error;
      _testSuccess = r.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.canWrite;
    final hasPassword = widget.company?.b('hasSmtpPassword') ?? false;
    return Gap(
      children: [
        TsInput(controller: _f['smtpHost'], label: 'SMTP Host', enabled: canWrite, keyboardType: TextInputType.url),
        TsInput(
          controller: _f['smtpPort'],
          label: 'SMTP Port',
          enabled: canWrite,
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
        ),
        TsInput(
          controller: _f['smtpUser'],
          label: 'Username',
          enabled: canWrite,
          keyboardType: TextInputType.emailAddress,
        ),
        TsInput(
          controller: _f['smtpPassword'],
          label: 'Password',
          enabled: canWrite,
          obscure: true,
          placeholder: hasPassword ? 'Leave blank to keep the current password' : null,
        ),
        if (canWrite) ...[
          if (_saveError != null) StatusMessage.error(_saveError),
          if (_saveSuccess) StatusMessage.success('SMTP settings saved.'),
          if (_testError != null) StatusMessage.error(_testError),
          if (_testSuccess) StatusMessage.success('Connected successfully.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TsButton(label: 'Save SMTP Settings', pendingLabel: 'Saving...', pending: _saving, onPressed: _save),
              TsButton.secondary(label: 'Test Connection', pendingLabel: 'Testing...', pending: _testing, onPressed: _test),
            ],
          ),
        ],
      ],
    );
  }
}
