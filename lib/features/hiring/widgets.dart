import '../../widgets/ts.dart';

/// Badge tones shared by the jobs and candidates pages (raw enum labels).
const jobStatusTone = {'DRAFT': BadgeTone.slate, 'PUBLISHED': BadgeTone.green, 'CLOSED': BadgeTone.red};
const candidateStatusTone = {'SUBMITTED': BadgeTone.green, 'WITHDRAWN': BadgeTone.slate};
const roundResultTone = {
  'PENDING': BadgeTone.slate,
  'PASSED': BadgeTone.green,
  'FAILED': BadgeTone.red,
  'DISQUALIFIED': BadgeTone.purple,
};
const roundTypeLabel = {
  'MCQ_EXAM': 'MCQ Online Exam',
  'INTERVIEW': 'Interview',
  'PHYSICAL_FITNESS': 'Physical Fitness',
  'MEDICAL_FITNESS': 'Medical Fitness',
};

/// Disposes a removed row's controllers once the frame that unmounts its
/// fields has finished, so no field touches a disposed controller.
void disposeAfterFrame(VoidCallback dispose) => WidgetsBinding.instance.addPostFrameCallback((_) => dispose());

String roundProgressLabel(int? currentRoundOrder) =>
    currentRoundOrder == null ? 'Applied' : 'Round ${currentRoundOrder + 1}';

/// Opens one of the web app's protected file routes (letter PDFs, resumes,
/// certificates) and toasts the failure, if any.
Future<void> openHiringFile(BuildContext context, String path) async {
  try {
    await api.openFile(path);
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
  } catch (_) {
    if (context.mounted) toast(context, "Couldn't open this file.", error: true);
  }
}

/// The plain `<h1 className="text-xl font-semibold">` header the
/// appointment pages use instead of PageHeader, with an optional muted
/// subtitle and the action buttons wrapped underneath.
class PlainHeader extends StatelessWidget {
  const PlainHeader(this.title, {super.key, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tx(22, weight: FontWeight.w600, color: p.foreground, tracking: kTight)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: tx(14, color: p.muted)),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
        ],
      ),
    );
  }
}

/// A row of `<input type="radio">` + label pairs.
class RadioGroupRow<T> extends StatelessWidget {
  const RadioGroupRow({super.key, required this.value, required this.options, required this.onChanged, this.label});
  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final row = Wrap(
      spacing: 18,
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
                      border: Border.all(
                        color: o.value == value ? p.accentViolet : p.border,
                        width: o.value == value ? 5 : 1.5,
                      ),
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
    if (label == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
        const SizedBox(height: 4),
        row,
      ],
    );
  }
}

/// `<input type="datetime-local">`: value / onChanged use the form's
/// "YYYY-MM-DDTHH:mm" wall-clock string; picks a date, then a time.
class DateTimeLocalField extends StatelessWidget {
  const DateTimeLocalField({super.key, this.label, this.hint, required this.value, required this.onChanged});
  final String? label;
  final String? hint;
  final String value;
  final ValueChanged<String> onChanged;

  DateTime? get _parsed => value.isEmpty ? null : DateTime.tryParse(value);

  String _display(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'am' : 'pm';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}, '
        '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = _parsed;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      builder: (ctx, child) => _pickerTheme(ctx, child),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null ? const TimeOfDay(hour: 10, minute: 0) : TimeOfDay.fromDateTime(current),
      builder: (ctx, child) => _pickerTheme(ctx, child),
    );
    if (time == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    onChanged('${ymd(date)}T${two(time.hour)}:${two(time.minute)}');
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final parsed = _parsed;
    return FieldWrapper(
      label: label,
      hint: hint,
      child: FieldBox(
        onTap: () => _pick(context),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  parsed == null ? 'dd/mm/yyyy, --:-- --' : _display(parsed),
                  style: tx(14, color: parsed == null ? p.muted.withValues(alpha: 0.7) : p.foreground),
                ),
              ),
            ),
            Icon(LucideIcons.calendar, size: 16, color: p.muted),
          ],
        ),
      ),
    );
  }
}

Widget _pickerTheme(BuildContext context, Widget? child) {
  final p = Ts.of(context);
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: p.dark ? p.accentViolet : const Color(0xFF3B2FA6),
        onPrimary: Colors.white,
        surface: p.surface,
        onSurface: p.foreground,
      ),
    ),
    child: child!,
  );
}

/// A bordered block inside a card (`rounded-lg border border-border p-3`):
/// round summaries, experiences, panel assignments.
class BorderedBlock extends StatelessWidget {
  const BorderedBlock({super.key, required this.children, this.onTap, this.padding = const EdgeInsets.all(14)});
  final List<Widget> children;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return TsPanel(
      padding: padding,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Bold 14px line (`font-medium text-foreground`).
class StrongText extends StatelessWidget {
  const StrongText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: tx(14, weight: FontWeight.w600, color: Ts.of(context).foreground));
}

/// Card-level muted line with a top gap (`mt-1 text-muted`).
class MutedLine extends StatelessWidget {
  const MutedLine(this.text, {super.key, this.size = 14});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: tx(size, color: Ts.of(context).muted, height: 1.45)),
      );
}

/// A filter bar for the list pages: search box, status select, Filter.
class ListFilterBar extends StatelessWidget {
  const ListFilterBar({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.status,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.onFilter,
  });
  final TextEditingController controller;
  final String placeholder;
  final String status;
  final List<SelectOption<String>> statusOptions;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 12,
      children: [
        TsInput(
          controller: controller,
          placeholder: placeholder,
          prefix: Icon(LucideIcons.search, size: 16, color: Ts.of(context).muted),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onFilter(),
        ),
        Row(
          children: [
            Expanded(
              child: TsSelect<String>(
                value: status,
                options: statusOptions,
                onChanged: (v) => onStatusChanged(v ?? ''),
              ),
            ),
            const SizedBox(width: 10),
            TsButton.secondary(label: 'Filter', onPressed: onFilter),
          ],
        ),
      ],
    );
  }
}
