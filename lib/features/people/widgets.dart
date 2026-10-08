import 'package:dio/dio.dart' as dio;
import 'package:flutter/services.dart';

import '../../widgets/ts.dart';

/// Opens one of the web app's protected file routes (ID card, certificates,
/// onboarding documents, notice PDFs) and toasts the failure, if any.
Future<void> openWebFile(BuildContext context, String path) async {
  try {
    await api.openFile(path);
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
  } catch (e) {
    if (context.mounted) toast(context, "Couldn't open this file.", error: true);
  }
}

/// A row of `<input type="radio">` + label pairs (`accent-primary`).
class RadioRow<T> extends StatelessWidget {
  const RadioRow({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final o in options)
          InkWell(
            borderRadius: BorderRadius.circular(Ts.rXl),
            onTap: () => onChanged(o.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                      border: Border.all(color: o.value == value ? p.primary : p.border, width: o.value == value ? 5 : 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(o.label, style: tx(14, color: p.foreground)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The web's `rounded-xl border border-border bg-surface p-4` boxes with an
/// `h2` heading (notice form sections, document upload slots). [tinted] is
/// the primary-tinted "Draft with AI" variant.
class TitledPanel extends StatelessWidget {
  const TitledPanel({super.key, this.title, this.description, required this.children, this.tinted = false, this.trailing, this.gap = 12});
  final String? title;
  final String? description;
  final List<Widget> children;
  final bool tinted;
  final Widget? trailing;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsPanel(
      color: tinted ? Color.alphaBlend(p.primary.withValues(alpha: 0.05), p.surface) : null,
      borderColor: tinted ? p.primary.withValues(alpha: 0.3) : null,
      child: Gap(
        gap: gap,
        children: [
          if (title != null || trailing != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (title != null)
                      Expanded(child: Text(title!, style: tx(14, weight: FontWeight.w600, color: p.foreground))),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(description!, style: tx(12, color: p.muted, height: 1.5)),
                  ),
              ],
            ),
          ...children,
        ],
      ),
    );
  }
}

/// A plain 14px label (`text-sm font-medium`) above a group of controls.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.help});
  final String text;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
        if (help != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(help!, style: tx(12, color: p.muted, height: 1.5)),
          ),
      ],
    );
  }
}

/// A `useActionState` form button whose error line sits above it, the way
/// the employee page's invite / delete forms render it.
class FormActionButton extends StatefulWidget {
  const FormActionButton({
    super.key,
    required this.label,
    required this.pendingLabel,
    required this.run,
    this.variant = TsButtonVariant.primary,
    this.confirm,
    this.confirmLabel,
  });
  final String label;
  final String pendingLabel;
  final Future<ActionResult> Function() run;
  final TsButtonVariant variant;
  final String? confirm;
  final String? confirmLabel;

  @override
  State<FormActionButton> createState() => _FormActionButtonState();
}

class _FormActionButtonState extends State<FormActionButton> {
  bool _pending = false;
  String? _error;

  Future<void> _go() async {
    if (widget.confirm != null) {
      final ok = await confirmDialog(
        context,
        message: widget.confirm!,
        confirmLabel: widget.confirmLabel ?? widget.label,
        danger: widget.variant == TsButtonVariant.danger,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(context, widget.run);
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[StatusMessage.error(_error), const SizedBox(height: 8)],
        TsButton(
          label: widget.label,
          pendingLabel: widget.pendingLabel,
          pending: _pending,
          variant: widget.variant,
          onPressed: _go,
        ),
      ],
    );
  }
}

/// lib/letter-template.ts#renderParagraphs as widgets: a blank line starts
/// a new paragraph, a block where every line starts with "- " is a
/// bulleted list, and single newlines are line breaks.
class NoticeBody extends StatelessWidget {
  const NoticeBody(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final style = tx(14, color: p.foreground, height: 1.625);
    final blocks = <Widget>[];
    for (final para in text.split(RegExp(r'\n\n+'))) {
      final lines = para.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final isList = lines.isNotEmpty && lines.every((l) => l.startsWith('- '));
      if (isList) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9, right: 10, left: 6),
                      child: Container(width: 5, height: 5, decoration: BoxDecoration(color: p.foreground, shape: BoxShape.circle)),
                    ),
                    Expanded(child: Text(l.substring(2), style: style)),
                  ],
                ),
            ],
          ),
        ));
      } else {
        blocks.add(Text(lines.join('\n'), style: style));
      }
    }
    return Gap(gap: 12, children: blocks);
  }
}

/// `{TypeLabel} · {memoNo} · {issueDate}` - the notice meta line the web
/// builds with plain interpolation (a missing memo/date leaves the gap).
String noticeMetaLine(Json n) {
  final date = n.sn('issueDate') == null ? '' : fmtDate(n.at('issueDate'));
  return '${n.s('typeLabel')} · ${n.s('memoNo', 'null')} · $date';
}

// ---------------------------------------------------------------------------
// lib/name-match.ts, ported as-is: every token of the expected name must be
// close (by edit distance) to some token on the document.

List<String> _nameTokens(String name) => name
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

int _levenshtein(String a, String b) {
  final dp = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] == b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + [dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1]].reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[a.length][b.length];
}

bool _tokensClose(String a, String b) {
  if (a == b) return true;
  final maxDistance = a.length <= 4 || b.length <= 4 ? 1 : (a.length <= 8 || b.length <= 8 ? 2 : 3);
  return _levenshtein(a, b) <= maxDistance;
}

bool namesMatch(String expectedName, String documentName) {
  final expected = _nameTokens(expectedName);
  final document = _nameTokens(documentName);
  if (expected.isEmpty || document.isEmpty) return false;
  return expected.every((et) => document.any((dt) => _tokensClose(et, dt)));
}

/// POSTs the picked file to one of the web's AI extract routes
/// (`/api/pan/extract` etc.) the way DocumentUploadField does and returns
/// its `fields`, or null when it couldn't be read.
Future<Json?> extractDocumentFields(String endpoint, UploadFile file) async {
  try {
    final form = dio.FormData();
    form.files.add(MapEntry(
      'file',
      await dio.MultipartFile.fromFile(
        file.path,
        filename: file.filename,
        contentType: file.contentType == null ? null : dio.DioMediaType.parse(file.contentType!),
      ),
    ));
    final res = await dio.Dio(dio.BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 90),
      validateStatus: (_) => true,
    )).post('${api.host}$endpoint', data: form, options: dio.Options(headers: api.authHeaders));
    if ((res.statusCode ?? 0) >= 400) return null;
    final fields = asJson(res.data)['fields'];
    return fields is Map ? fields.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

/// The web's `onChange={(e) => set(e.target.value.toUpperCase())}` inputs.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
