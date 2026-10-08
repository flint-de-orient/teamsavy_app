import '../../widgets/ts.dart';
import 'widgets.dart';

const _accept = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'];

/// app/(app)/my-documents/page.tsx - self-service uploads, each document
/// independently replaceable.
class MyDocumentsScreen extends StatelessWidget {
  const MyDocumentsScreen({super.key});

  static const _header = PageHeader(
    title: 'My Documents',
    description:
        "Upload or replace any of your documents anytime. Each one is independent - you don't need to redo the others to update just one.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/my-documents',
      header: _header,
      gap: 24,
      builder: (context, data, reload) {
        final employee = data.mN('employee');
        if (employee == null) {
          return const [
            PageHeader(title: 'My Documents'),
            TsCard(child: Muted('This page is only available for employee accounts.')),
          ];
        }
        return [
          _header,
          if (data.b('showCompletionCertificate'))
            TsCard(
              title: 'Internship Completion Certificate',
              icon: LucideIcons.graduationCap,
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Muted('Your internship has ended - download your certificate below.'),
                  TsButton.secondary(
                    label: 'Download Certificate',
                    icon: LucideIcons.download,
                    onPressed: () => openWebFile(
                      context,
                      '/api/employees/${employee.s('id')}/internship-certificate?download=1',
                    ),
                  ),
                ],
              ),
            ),
          DocumentsForm(
            onboarding: false,
            employeeId: employee.s('id'),
            expectedName: employee.s('name'),
            defaults: data.m('defaults'),
          ),
        ];
      },
    );
  }
}

/// app/onboarding/documents/page.tsx - the mandatory first-login upload
/// step for employees hired through an appointment letter.
class OnboardingDocumentsScreen extends StatelessWidget {
  const OnboardingDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome aboard - upload your documents',
            style: tx(20, weight: FontWeight.w600, color: p.foreground, tracking: kTight)),
        const SizedBox(height: 4),
        const Muted(
          'Before you continue into the portal, upload these four documents. Uploading each one reads its details '
          'automatically - please check them over before saving, since AI can misread a document.',
        ),
      ],
    );
    return ApiScreen(
      path: '/onboarding/documents',
      header: heading,
      gap: 24,
      builder: (context, data, reload) {
        if (data.sn('redirect') != null) {
          // Nothing to upload for this account (already submitted / not
          // hired via an appointment): carry on into the app.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await session.refreshMe().catchError((_) {});
            if (context.mounted) context.go(session.me?.homePath ?? data.s('redirect'));
          });
          return const [LoadingBlock(count: 1)];
        }
        return [
          heading,
          DocumentsForm(onboarding: true, expectedName: data.s('candidateName'), defaults: const {}),
        ];
      },
    );
  }
}

/// The four-document form shared by both pages (my-documents-form.tsx and
/// onboarding-documents-form.tsx): same blocks and field names; onboarding
/// requires every file and only reveals the fields once a file is chosen.
class DocumentsForm extends StatefulWidget {
  const DocumentsForm({
    super.key,
    required this.onboarding,
    required this.expectedName,
    required this.defaults,
    this.employeeId,
  });
  final bool onboarding;
  final String expectedName;
  final Json defaults;
  final String? employeeId;

  @override
  State<DocumentsForm> createState() => _DocumentsFormState();
}

class _DocumentsFormState extends State<DocumentsForm> {
  static const _textFields = [
    'qualificationDegree',
    'qualificationInstitution',
    'qualificationYear',
    'panNumber',
    'aadharNumber',
    'bankAccountNumber',
    'bankIfsc',
    'bankName',
    'bankAccountHolderName',
  ];

  late final Map<String, TextEditingController> _c = {
    for (final k in _textFields) k: TextEditingController(text: widget.defaults.s(k)),
  };
  final _files = <String, UploadFile?>{
    'qualificationCertFile': null,
    'panCardFile': null,
    'aadharCardFile': null,
    'bankStatementFile': null,
  };

  bool _pending = false;
  bool _deferring = false;
  bool _attempted = false;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    // hasResult (the "please verify" note) follows these as they're typed.
    for (final k in ['qualificationDegree', 'panNumber', 'aadharNumber', 'bankAccountNumber']) {
      _c[k]!.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _existingUrl(String kind, String flag) {
    final id = widget.employeeId;
    if (widget.onboarding || id == null || !widget.defaults.b(flag)) return null;
    return '/api/files/onboarding-document/$id/$kind';
  }

  Map<String, Object?> get _fields => {for (final k in _textFields) k: _c[k]!.text};

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _attempted = true;
      _error = null;
      _success = false;
    });
    // The web's file inputs are `required` here, so the browser stops an
    // incomplete submit before it reaches the server.
    if (widget.onboarding && _files.values.any((f) => f == null)) {
      setState(() => _error = 'All four documents are required.');
      return;
    }
    setState(() => _pending = true);
    final r = await runAction(
      context,
      () => api.action(
        widget.onboarding ? 'people.submitOnboardingDocuments' : 'people.updateMyDocuments',
        fields: _fields,
        files: _files,
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    if (r.ok && widget.onboarding) {
      await _continueIntoApp();
      return;
    }
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
      if (r.ok) _files.updateAll((key, value) => null);
    });
  }

  Future<void> _doItLater() async {
    setState(() {
      _deferring = true;
      _error = null;
    });
    final r = await api.action('people.deferOnboardingDocuments');
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _deferring = false;
        _error = r.error;
      });
      return;
    }
    await _continueIntoApp();
  }

  /// The onboarding gate is lifted server-side; reload /me so the router
  /// stops sending us back here, then go home.
  Future<void> _continueIntoApp() async {
    try {
      await session.refreshMe();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _pending = false;
          _deferring = false;
          _error = e.message;
        });
      }
      return;
    }
    if (mounted) context.go(session.me!.homePath);
  }

  TsInput _input(String key, String label, {bool upper = false, bool numeric = false}) => TsInput(
        controller: _c[key],
        label: label,
        keyboardType: numeric ? TextInputType.number : null,
        inputFormatters: upper ? [UpperCaseFormatter()] : (numeric ? TsInput.digitsOnly : null),
        textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
      );

  DocumentUploadField _block({
    required String label,
    required String fileField,
    required String endpoint,
    required String hasResultKey,
    required String kind,
    required String existingFlag,
    required void Function(Json fields) onExtracted,
    String? documentNameKey,
    required List<Widget> children,
  }) =>
      DocumentUploadField(
        label: label,
        extractEndpoint: endpoint,
        file: _files[fileField],
        onFileChanged: (f) => setState(() => _files[fileField] = f),
        onExtracted: (fields) => setState(() => onExtracted(fields)),
        hasResult: _c[hasResultKey]!.text.isNotEmpty,
        alwaysShowFields: !widget.onboarding,
        existingFileUrl: _existingUrl(kind, existingFlag),
        expectedName: documentNameKey == null ? null : widget.expectedName,
        documentNameKey: documentNameKey,
        children: children,
      );

  @override
  Widget build(BuildContext context) {
    final showDefer = widget.onboarding && (_attempted || _error != null);
    return Gap(
      gap: 20,
      children: [
        _block(
          label: 'Highest Qualification Certificate',
          fileField: 'qualificationCertFile',
          endpoint: '/api/qualification/extract',
          hasResultKey: 'qualificationDegree',
          kind: 'qualification',
          existingFlag: 'hasQualificationCert',
          onExtracted: (f) {
            _c['qualificationDegree']!.text = f.s('degree');
            _c['qualificationInstitution']!.text = f.s('institution');
            final year = f.iN('yearOfCompletion');
            _c['qualificationYear']!.text = year == null || year == 0 ? '' : '$year';
          },
          children: [
            _input('qualificationDegree', 'Degree'),
            _input('qualificationInstitution', 'Institution'),
            _input('qualificationYear', 'Year of Completion', numeric: true),
          ],
        ),
        _block(
          label: 'PAN Card',
          fileField: 'panCardFile',
          endpoint: '/api/pan/extract',
          hasResultKey: 'panNumber',
          kind: 'pan',
          existingFlag: 'hasPanCard',
          documentNameKey: 'nameOnCard',
          onExtracted: (f) => _c['panNumber']!.text = f.s('panNumber'),
          children: [_input('panNumber', 'PAN Number', upper: true)],
        ),
        _block(
          label: 'Aadhaar Card',
          fileField: 'aadharCardFile',
          endpoint: '/api/aadhaar/extract',
          hasResultKey: 'aadharNumber',
          kind: 'aadhaar',
          existingFlag: 'hasAadharCard',
          documentNameKey: 'candidateName',
          onExtracted: (f) => _c['aadharNumber']!.text = f.s('aadharNoFull'),
          children: [_input('aadharNumber', 'Aadhaar Number')],
        ),
        _block(
          label: 'Bank Statement',
          fileField: 'bankStatementFile',
          endpoint: '/api/bank-statement/extract',
          hasResultKey: 'bankAccountNumber',
          kind: 'bank',
          existingFlag: 'hasBankStatement',
          documentNameKey: 'accountHolderName',
          onExtracted: (f) {
            _c['bankAccountNumber']!.text = f.s('accountNumber');
            _c['bankIfsc']!.text = f.s('ifscCode');
            _c['bankName']!.text = f.s('bankName');
            _c['bankAccountHolderName']!.text = f.s('accountHolderName');
          },
          children: [
            _input('bankAccountNumber', 'Account Number'),
            _input('bankIfsc', 'IFSC', upper: true),
            _input('bankName', 'Bank Name'),
            _input('bankAccountHolderName', 'Account Holder Name'),
          ],
        ),
        if (_error != null) StatusMessage.error(_error),
        if (!_pending && _success) StatusMessage.success('Saved.'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TsButton(
              label: widget.onboarding ? 'Save & Continue' : 'Save',
              icon: widget.onboarding ? LucideIcons.arrowRight : null,
              pendingLabel: 'Saving...',
              pending: _pending,
              onPressed: _deferring ? null : _save,
            ),
            if (showDefer)
              TsButton.secondary(
                label: 'Do it Later',
                pending: _deferring,
                onPressed: _pending ? null : _doItLater,
              ),
          ],
        ),
        if (showDefer)
          Text(
            "You can finish uploading anytime from My Documents in the portal once you're logged in.",
            style: tx(12, color: Ts.of(context).muted),
          ),
      ],
    );
  }
}

enum _ReadStatus { idle, reading, unavailable, nameMismatch }

/// app/onboarding/documents/document-upload-field.tsx: pick a file, let
/// the web's AI extract route read it, reject it if the name on it doesn't
/// match the one on record, and hand the fields to the parent form.
class DocumentUploadField extends StatefulWidget {
  const DocumentUploadField({
    super.key,
    required this.label,
    required this.extractEndpoint,
    required this.file,
    required this.onFileChanged,
    required this.onExtracted,
    required this.hasResult,
    required this.children,
    this.expectedName,
    this.documentNameKey,
    this.alwaysShowFields = false,
    this.existingFileUrl,
  });

  final String label;
  final String extractEndpoint;
  final UploadFile? file;
  final ValueChanged<UploadFile?> onFileChanged;
  final ValueChanged<Json> onExtracted;
  final bool hasResult;
  final List<Widget> children;
  final String? expectedName;

  /// Which extracted field holds the name printed on the document.
  final String? documentNameKey;
  final bool alwaysShowFields;
  final String? existingFileUrl;

  @override
  State<DocumentUploadField> createState() => _DocumentUploadFieldState();
}

class _DocumentUploadFieldState extends State<DocumentUploadField> {
  _ReadStatus _status = _ReadStatus.idle;

  Future<void> _picked(UploadFile? file) async {
    widget.onFileChanged(file);
    if (file == null) {
      setState(() => _status = _ReadStatus.idle);
      return;
    }
    setState(() => _status = _ReadStatus.reading);
    final fields = await extractDocumentFields(widget.extractEndpoint, file);
    if (!mounted) return;
    if (fields == null) {
      setState(() => _status = _ReadStatus.unavailable);
      return;
    }
    final expected = widget.expectedName;
    final nameKey = widget.documentNameKey;
    if (expected != null && nameKey != null && !namesMatch(expected, fields.s(nameKey))) {
      widget.onFileChanged(null);
      setState(() => _status = _ReadStatus.nameMismatch);
      return;
    }
    widget.onExtracted(fields);
    setState(() => _status = _ReadStatus.idle);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final file = widget.file;
    final existing = widget.existingFileUrl;
    return TsPanel(
      radius: Ts.rXl,
      child: Gap(
        gap: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.label, style: tx(14, weight: FontWeight.w600, color: p.foreground))),
                  if (existing != null && file == null)
                    TsLink('View current file', size: 12, weight: FontWeight.w600,
                        onTap: () => openWebFile(context, existing)),
                ],
              ),
              const SizedBox(height: 6),
              TsFileField(file: file, accept: _accept, onChanged: _picked),
            ],
          ),
          if (_status == _ReadStatus.reading)
            Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted)),
                const SizedBox(width: 8),
                const Muted('Reading document with AI…'),
              ],
            ),
          if (_status == _ReadStatus.unavailable)
            Text("Couldn't read this automatically - fill the details in manually below.",
                style: tx(14, color: p.warning, height: 1.5)),
          if (_status == _ReadStatus.nameMismatch)
            Text(
              "The name on this document doesn't match "
              '${widget.expectedName != null ? '"${widget.expectedName}"' : "the candidate's name"} on record. '
              'Please upload the correct document.',
              style: tx(14, color: p.danger, height: 1.5),
            ),
          if (file != null || widget.alwaysShowFields) ...widget.children,
          if (file != null && widget.hasResult)
            Text('AI-read details are editable - please verify before saving.', style: tx(12, color: p.muted)),
        ],
      ),
    );
  }
}
