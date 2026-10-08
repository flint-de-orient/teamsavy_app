import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../widgets/ts.dart';

/// lib/payroll/format-inr.ts: `"₹" + Math.round(n).toLocaleString("en-IN")`.
String inr(Object? n) {
  final v = n is num ? n : num.tryParse('${n ?? ''}');
  if (v == null) return '—';
  return rupee(v.round());
}

/// `inr()` or "—" for a nullable run total.
String inrOrDash(Object? n) => n == null ? '—' : inr(n);

/// A JS number as `${n}` prints it: 4 -> "4", 8.33 -> "8.33".
String numText(Object? n) {
  if (n == null) return '';
  final v = n is num ? n : num.tryParse('$n');
  if (v == null) return '$n';
  return v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

/// Payroll run STATUS_TONE (label is the raw enum).
const runStatusTone = {'DRAFT': BadgeTone.slate, 'PROCESSED': BadgeTone.blue, 'LOCKED': BadgeTone.green};

/// PAYOUT_STATUS_TONE (label is the raw enum).
const payoutStatusTone = {
  'NOT_INITIATED': BadgeTone.slate,
  'PROCESSING': BadgeTone.blue,
  'SUCCESS': BadgeTone.green,
  'FAILED': BadgeTone.red,
};

TsBadge runStatusBadge(String status) => TsBadge(status, tone: runStatusTone[status] ?? BadgeTone.slate);

/// The payslip / tax preview `line()`: muted label left, medium value right,
/// divider between rows. [strong] marks a total row.
class LineRow extends StatelessWidget {
  const LineRow(this.label, this.value, {super.key, this.strong = false, this.last = false});
  final String label;
  final String value;
  final bool strong;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: tx(14, color: strong ? p.foreground : p.muted, weight: strong ? FontWeight.w600 : FontWeight.w400)),
          ),
          const SizedBox(width: 12),
          Text(value,
              textAlign: TextAlign.right,
              style: tx(strong ? 15 : 14, weight: strong ? FontWeight.w700 : FontWeight.w500, color: p.foreground)),
        ],
      ),
    );
  }
}

/// A `<section>` of [LineRow]s with its `<h2>` heading - the payslip's
/// Earnings / Deductions blocks. [tone] tints it (the primary Net Pay box).
class LineSection extends StatelessWidget {
  const LineSection({super.key, required this.title, required this.rows, this.footer, this.icon, this.highlight = false});
  final String title;
  final List<LineRow> rows;
  final String? footer;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          LineRow(rows[i].label, rows[i].value, strong: rows[i].strong, last: i == rows.length - 1),
        if (footer != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(footer!, style: tx(12, color: p.muted, height: 1.5))),
      ],
    );
    if (highlight) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color.alphaBlend(p.primary.withValues(alpha: 0.05), p.surface),
          borderRadius: BorderRadius.circular(Ts.r3xl),
          border: Border.all(color: p.primary.withValues(alpha: 0.4)),
          boxShadow: p.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: tx(14, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
            const SizedBox(height: 8),
            body,
          ],
        ),
      );
    }
    return TsCard(title: title, icon: icon, child: body);
  }
}

/// The amber/red bordered notice boxes (`rounded-xl border bg-warning-light`)
/// with an optional bold heading and bullet list.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, this.title, this.text, this.bullets = const [], this.kind = StatusKind.warning, this.child});
  final String? title;
  final String? text;
  final List<String> bullets;
  final StatusKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final (bg, fg) = switch (kind) {
      StatusKind.error => (p.dangerLight, p.danger),
      StatusKind.success => (p.successLight, p.success),
      StatusKind.info => (p.infoLight, p.info),
      _ => (p.warningLight, p.warning),
    };
    final textColor = p.dark ? fg : p.foreground;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ts.r2xl),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.only(bottom: (text != null || bullets.isNotEmpty || child != null) ? 6 : 0),
              child: Text(title!, style: tx(14, weight: FontWeight.w700, color: fg)),
            ),
          if (text != null) Text(text!, style: tx(14, color: textColor, height: 1.5)),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                  ),
                  Expanded(child: Text(b, style: tx(14, color: textColor, height: 1.5))),
                ],
              ),
            ),
          if (child != null) ...[if (title != null || text != null) const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}

/// The `rounded-2xl border bg-surface p-4 shadow-card` blocks the payroll
/// pages wrap each form in, with the optional `<h2>` heading.
class Block extends StatelessWidget {
  const Block({super.key, this.title, required this.child, this.uppercase = false});
  final String? title;
  final Widget child;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                uppercase ? title!.toUpperCase() : title!,
                style: uppercase
                    ? tx(12, weight: FontWeight.w700, color: p.muted, tracking: 0.05)
                    : tx(14, weight: FontWeight.w700, color: p.foreground, tracking: kTight),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// "Processed 3 payslips." / "Sent 2 reminders." plus the Skipped list -
/// the web's ProcessResult / TaxRegimeReminderResult green box.
class SkippedResult extends StatelessWidget {
  const SkippedResult({super.key, required this.headline, required this.skipped});
  final String headline;
  final List<Json> skipped;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.successLight,
        borderRadius: BorderRadius.circular(Ts.rXl),
        border: Border.all(color: p.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: tx(14, color: p.success, weight: FontWeight.w600)),
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Skipped ${skipped.length} employee${skipped.length == 1 ? '' : 's'}:',
                style: tx(14, weight: FontWeight.w600, color: p.warning)),
            for (final s in skipped)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text('•  ${s.s('employeeName')}: ${s.s('reason')}', style: tx(14, color: p.warning, height: 1.45)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Downloads one of the file routes the way the web's DownloadButton does:
/// a JSON `{error}` answer becomes an inline message instead of a file.
/// Returns the error to show, or null once the file has opened.
Future<String?> downloadPayrollFile(String path) async {
  final dio = Dio(BaseOptions(
    validateStatus: (_) => true,
    responseType: ResponseType.bytes,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 120),
  ));
  Response<dynamic> res;
  try {
    res = await dio.get('${api.host}$path', options: Options(headers: api.authHeaders));
  } catch (_) {
    return 'Something went wrong generating this file. Check your connection and try again.';
  }
  if ((res.statusCode ?? 0) >= 400) {
    final contentType = res.headers.value('content-type') ?? '';
    if (contentType.contains('application/json')) {
      try {
        final body = jsonDecode(utf8.decode(res.data as List<int>));
        if (body is Map && body['error'] is String) return body['error'] as String;
      } catch (_) {}
    }
    return 'Something went wrong generating this file.';
  }
  try {
    final disposition = res.headers.value('content-disposition') ?? '';
    final filename = RegExp(r'filename="([^"]+)"').firstMatch(disposition)?.group(1) ?? 'download';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(res.data as List<int>);
    await OpenFilex.open(file.path);
  } catch (_) {
    return 'Something went wrong generating this file.';
  }
  return null;
}

/// payroll/returns/download-button.tsx: "Generating..." while it fetches,
/// the server's error inline underneath. [link] is the text-link variant.
class DownloadButton extends StatefulWidget {
  const DownloadButton({
    super.key,
    required this.label,
    required this.path,
    this.disabled = false,
    this.link = false,
    this.secondary = false,
    this.icon,
  });
  final String label;
  final String path;
  final bool disabled;
  final bool link;
  final bool secondary;
  final IconData? icon;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool _pending = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final error = await downloadPayrollFile(widget.path);
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final enabled = !widget.disabled && !_pending;
    final control = widget.link
        ? Opacity(
            opacity: widget.disabled ? 0.5 : 1,
            child: TsLink(_pending ? 'Generating...' : widget.label, onTap: enabled ? _go : null),
          )
        : TsButton(
            label: widget.label,
            variant: widget.secondary ? TsButtonVariant.secondary : TsButtonVariant.primary,
            pendingLabel: 'Generating...',
            pending: _pending,
            icon: widget.icon ?? LucideIcons.download,
            onPressed: widget.disabled ? null : _go,
          );
    return Column(
      crossAxisAlignment: widget.link ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(_error!, style: tx(12, color: p.danger)),
            ),
          ),
      ],
    );
  }
}

/// Opens a plain file link (`<a href>` on the web) and toasts a failure.
Future<void> openPayrollFile(BuildContext context, String path) async {
  try {
    await api.openFile(path);
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
  }
}

/// A free-standing `<label>` + content (radio groups, checklists).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: tx(14, weight: FontWeight.w600, color: Ts.of(context).foreground));
}

/// Expandable help text (the tax form's `<details>` disclosures).
class InfoDisclosure extends StatefulWidget {
  const InfoDisclosure({super.key, required this.summary, required this.text});
  final String summary;
  final String text;

  @override
  State<InfoDisclosure> createState() => _InfoDisclosureState();
}

class _InfoDisclosureState extends State<InfoDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: p.primary),
                const SizedBox(width: 4),
                Flexible(child: Text(widget.summary, style: tx(12, color: p.primary, weight: FontWeight.w500))),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(left: 18, top: 2),
                  child: Text(widget.text, style: tx(12, color: p.muted, height: 1.5)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A radio option row (`<input type="radio">` + label).
class RadioRow<T> extends StatelessWidget {
  const RadioRow({super.key, required this.label, required this.value, required this.group, required this.onChanged});
  final String label;
  final T value;
  final T group;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final selected = value == group;
    return InkWell(
      borderRadius: BorderRadius.circular(Ts.rXl),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? p.accentViolet : p.border, width: selected ? 6 : 1.5),
                color: p.surface,
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: tx(14, weight: FontWeight.w500, color: p.foreground)),
          ],
        ),
      ),
    );
  }
}

/// Numeric keyboard for amount/percent inputs (`type="number"`).
const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

/// The "← Previous" / "Next →" / back buttons several return pages share.
List<Widget> monthNavButtons(BuildContext context, {required String back, required String prev, required String next}) => [
      TsButton.secondary(label: 'Back to Statutory Returns', onPressed: () => followRedirect(context, back)),
      TsButton.secondary(label: '← Previous', onPressed: () => context.replace(prev)),
      TsButton.secondary(label: 'Next →', onPressed: () => context.replace(next)),
    ];
