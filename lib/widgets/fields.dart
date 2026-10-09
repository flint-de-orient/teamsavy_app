import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/tokens.dart';

/// components/ui/Input.tsx's FieldWrapper: a 14px semibold label, the
/// field, then a 12px muted hint or a 12px danger error.
class FieldWrapper extends StatelessWidget {
  const FieldWrapper({super.key, this.label, this.hint, this.error, required this.child, this.required = false});
  final String? label;
  final String? hint;
  final String? error;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label!, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
          ),
        child,
        if (hint != null && error == null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(hint!, style: tx(12, color: p.muted))),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: tx(12, color: p.danger))),
      ],
    );
  }
}

/// The `fieldClass` box: `rounded-2xl border bg-surface px-4 py-2.5`,
/// `shadow-xs`, border turns primary with a 4px glow ring while focused.
class FieldBox extends StatelessWidget {
  const FieldBox({
    super.key,
    required this.child,
    this.focused = false,
    this.onTap,
    this.minHeight = 44,
    this.disabled = false,
  });
  final Widget child;
  final bool focused;
  final VoidCallback? onTap;
  final double minHeight;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: disabled ? p.surfaceHover : p.surface,
        borderRadius: BorderRadius.circular(Ts.r2xl),
        border: Border.all(color: focused ? p.primary : p.border),
        boxShadow: [...p.shadowXs, if (focused) BoxShadow(color: p.glow, spreadRadius: 4)],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: disabled ? null : onTap, child: box);
  }
}

class TsInput extends StatefulWidget {
  const TsInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.error,
    this.placeholder,
    this.keyboardType,
    this.obscure = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.prefix,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? error;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscure;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final Widget? prefix;
  final Widget? suffix;
  final TextCapitalization textCapitalization;

  /// Numeric keyboard + digits-only filter (inputMode="numeric").
  static List<TextInputFormatter> digitsOnly = [FilteringTextInputFormatter.digitsOnly];

  @override
  State<TsInput> createState() => _TsInputState();
}

class _TsInputState extends State<TsInput> {
  final _focus = FocusNode();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final multiline = (widget.maxLines ?? 2) > 1;
    return FieldWrapper(
      label: widget.label,
      hint: widget.hint,
      error: widget.error,
      child: FieldBox(
        focused: _focus.hasFocus,
        disabled: !widget.enabled,
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (widget.prefix != null) ...[widget.prefix!, const SizedBox(width: 8)],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                obscureText: widget.obscure && _obscured,
                keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
                maxLength: widget.maxLength,
                maxLines: widget.obscure ? 1 : widget.maxLines,
                minLines: widget.minLines,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                autofillHints: widget.autofillHints,
                textCapitalization: widget.textCapitalization,
                cursorColor: p.primary,
                style: tx(14, color: p.foreground),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: multiline ? 12 : 12),
                  hintText: widget.placeholder,
                  hintStyle: tx(14, color: p.muted.withValues(alpha: 0.7)),
                ),
              ),
            ),
            if (widget.obscure)
              GestureDetector(
                onTap: () => setState(() => _obscured = !_obscured),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: p.muted),
                ),
              ),
            if (widget.suffix != null) ...[const SizedBox(width: 8), widget.suffix!],
          ],
        ),
      ),
    );
  }
}

/// components/ui/Textarea.tsx - the same field box, multi-line.
class TsTextarea extends StatelessWidget {
  const TsTextarea({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.error,
    this.placeholder,
    this.rows = 3,
    this.maxLength,
    this.onChanged,
    this.enabled = true,
  });
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? error;
  final String? placeholder;
  final int rows;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TsInput(
    controller: controller,
    label: label,
    hint: hint,
    error: error,
    placeholder: placeholder,
    maxLines: rows + 4,
    minLines: rows,
    maxLength: maxLength,
    onChanged: onChanged,
    enabled: enabled,
    textCapitalization: TextCapitalization.sentences,
  );
}

/// One `<option>`.
class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.disabled = false});
  final T value;
  final String label;
  final bool disabled;
}

/// components/ui/Select.tsx - the field box with the themed chevron. Opens
/// a bottom sheet of options (the phone-native equivalent of a <select>).
class TsSelect<T> extends StatelessWidget {
  const TsSelect({
    super.key,
    this.label,
    this.hint,
    this.error,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Choose...',
    this.enabled = true,
  });

  final String? label;
  final String? hint;
  final String? error;
  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final selected = options.where((o) => o.value == value).firstOrNull;
    return FieldWrapper(
      label: label,
      hint: hint,
      error: error,
      child: FieldBox(
        disabled: !enabled,
        onTap: () async {
          FocusScope.of(context).unfocus();
          final picked = await showOptionsSheet<T>(context, title: label, options: options, selected: value);
          if (picked != null) onChanged(picked.value);
        },
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  selected?.label ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx(14, color: selected == null ? p.muted.withValues(alpha: 0.7) : p.foreground),
                ),
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 16, color: p.muted),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing options; resolves with the tapped one.
Future<SelectOption<T>?> showOptionsSheet<T>(
  BuildContext context, {
  String? title,
  required List<SelectOption<T>> options,
  T? selected,
}) {
  final p = Ts.of(context);
  return showModalBottomSheet<SelectOption<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options[i];
                  final isSel = o.value == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSel ? p.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(Ts.r2xl),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Ts.r2xl),
                        onTap: o.disabled ? null : () => Navigator.of(ctx).pop(o),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.label,
                                  style: tx(
                                    14,
                                    weight: isSel ? FontWeight.w600 : FontWeight.w500,
                                    color: o.disabled ? p.muted.withValues(alpha: 0.5) : p.foreground,
                                  ),
                                ),
                              ),
                              if (isSel) Icon(LucideIcons.check, size: 16, color: p.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Multi-select (checkbox list) for fields like "Locations".
class TsMultiSelect<T> extends StatelessWidget {
  const TsMultiSelect({
    super.key,
    this.label,
    this.hint,
    this.error,
    required this.values,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Choose...',
  });
  final String? label;
  final String? hint;
  final String? error;
  final Set<T> values;
  final List<SelectOption<T>> options;
  final ValueChanged<Set<T>> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final labels = options.where((o) => values.contains(o.value)).map((o) => o.label).toList();
    return FieldWrapper(
      label: label,
      hint: hint,
      error: error,
      child: FieldBox(
        onTap: () async {
          final result = await showModalBottomSheet<Set<T>>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (ctx) => _MultiSheet<T>(title: label, options: options, initial: values),
          );
          if (result != null) onChanged(result);
        },
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  labels.isEmpty ? placeholder : labels.join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tx(14, color: labels.isEmpty ? p.muted.withValues(alpha: 0.7) : p.foreground),
                ),
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 16, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _MultiSheet<T> extends StatefulWidget {
  const _MultiSheet({required this.title, required this.options, required this.initial});
  final String? title;
  final List<SelectOption<T>> options;
  final Set<T> initial;

  @override
  State<_MultiSheet<T>> createState() => _MultiSheetState<T>();
}

class _MultiSheetState<T> extends State<_MultiSheet<T>> {
  late final Set<T> _values = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(widget.title!, style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final o in widget.options)
                  TsCheckbox(
                    label: o.label,
                    value: _values.contains(o.value),
                    onChanged: (v) => setState(() => v ? _values.add(o.value) : _values.remove(o.value)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _DoneButton(onTap: () => Navigator.of(context).pop(_values)),
          ),
        ],
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: p.gradientPrimary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: p.shadowButton,
        ),
        child: Text('Done', style: tx(14, weight: FontWeight.w600, color: p.primaryForeground, tracking: kTight)),
      ),
    );
  }
}

/// A checkbox row (`<input type="checkbox">` + label).
class TsCheckbox extends StatelessWidget {
  const TsCheckbox({super.key, required this.label, required this.value, required this.onChanged, this.hint});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(Ts.rXl),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                gradient: value ? p.gradientPrimary : null,
                color: value ? null : p.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value ? Colors.transparent : p.border, width: 1.5),
              ),
              child: value ? Icon(LucideIcons.check, size: 14, color: p.primaryForeground) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: tx(14, weight: FontWeight.w500, color: p.foreground)),
                  if (hint != null)
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint!, style: tx(12, color: p.muted))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A switch row for boolean settings.
class TsSwitch extends StatelessWidget {
  const TsSwitch({super.key, required this.label, required this.value, required this.onChanged, this.hint});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
              if (hint != null)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint!, style: tx(12, color: p.muted))),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: p.accentViolet),
      ],
    );
  }
}

/// `<input type="date">`. [value] / [onChanged] use "YYYY-MM-DD" like the
/// web form posts; the box shows dd/mm/yyyy like an en-IN browser.
class TsDateField extends StatelessWidget {
  const TsDateField({
    super.key,
    this.label,
    this.hint,
    this.error,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.placeholder = 'dd/mm/yyyy',
    this.clearable = false,
  });
  final String? label;
  final String? hint;
  final String? error;
  final String? value;
  final ValueChanged<String?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String placeholder;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final parsed = value == null || value!.isEmpty ? null : DateTime.tryParse(value!);
    final text =
        parsed == null
            ? placeholder
            : '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    return FieldWrapper(
      label: label,
      hint: hint,
      error: error,
      child: FieldBox(
        onTap: () async {
          FocusScope.of(context).unfocus();
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: parsed ?? now,
            firstDate: firstDate ?? DateTime(now.year - 80),
            lastDate: lastDate ?? DateTime(now.year + 10),
            builder: (ctx, child) => _pickerTheme(ctx, child),
          );
          if (picked != null) onChanged(ymd(picked));
        },
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(text, style: tx(14, color: parsed == null ? p.muted.withValues(alpha: 0.7) : p.foreground)),
              ),
            ),
            if (clearable && parsed != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(LucideIcons.x, size: 16, color: p.muted),
                ),
              ),
            Icon(LucideIcons.calendar, size: 16, color: p.muted),
          ],
        ),
      ),
    );
  }
}

/// `<input type="month">` - value "YYYY-MM".
class TsMonthField extends StatelessWidget {
  const TsMonthField({super.key, this.label, required this.value, required this.onChanged, this.hint});
  final String? label;
  final String? hint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return FieldWrapper(
      label: label,
      hint: hint,
      child: FieldBox(
        onTap: () async {
          final picked = await showMonthPicker(context, value);
          if (picked != null) onChanged(picked);
        },
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(monthLabel(value), style: tx(14, color: p.foreground)),
              ),
            ),
            Icon(LucideIcons.calendarDays, size: 16, color: p.muted),
          ],
        ),
      ),
    );
  }
}

Future<String?> showMonthPicker(BuildContext context, String value) {
  final p = Ts.of(context);
  var year = int.tryParse(value.split('-').first) ?? DateTime.now().year;
  final selectedMonth = int.tryParse(value.split('-').last) ?? 1;
  final selectedYear = int.tryParse(value.split('-').first) ?? year;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setState) => ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: Padding(
                  // Same reasoning as PageScroll (lib/widgets/screen.dart): add the
                  // system bottom inset explicitly, on top of useSafeArea's own
                  // handling, so the grid clears the 3-button nav bar / floating
                  // tab bar instead of being cut off or unscrollable underneath it.
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(ctx).padding.bottom + 66),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => year--),
                            icon: Icon(LucideIcons.chevronLeft, color: p.muted),
                          ),
                          Expanded(
                            child: Text(
                              '$year',
                              textAlign: TextAlign.center,
                              style: tx(16, weight: FontWeight.w700, color: p.foreground),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => year++),
                            icon: Icon(LucideIcons.chevronRight, color: p.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.8,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (var m = 1; m <= 12; m++)
                                GestureDetector(
                                  onTap: () => Navigator.of(ctx).pop('$year-${m.toString().padLeft(2, '0')}'),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient:
                                          (m == selectedMonth && year == selectedYear) ? p.gradientPrimary : null,
                                      color: (m == selectedMonth && year == selectedYear) ? null : p.surfaceHover,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      monthShort(m),
                                      style: tx(
                                        14,
                                        weight: FontWeight.w600,
                                        color:
                                            (m == selectedMonth && year == selectedYear)
                                                ? p.primaryForeground
                                                : p.foreground,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
  );
}

/// `<input type="time">` - value "HH:mm" (24h).
class TsTimeField extends StatelessWidget {
  const TsTimeField({super.key, this.label, required this.value, required this.onChanged, this.hint, this.error});
  final String? label;
  final String? hint;
  final String? error;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    TimeOfDay? t;
    if (value != null && value!.contains(':')) {
      final parts = value!.split(':');
      t = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
    }
    String display() {
      if (t == null) return '--:--';
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
    }

    return FieldWrapper(
      label: label,
      hint: hint,
      error: error,
      child: FieldBox(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: t ?? const TimeOfDay(hour: 9, minute: 30),
            builder: (ctx, child) => _pickerTheme(ctx, child),
          );
          if (picked != null) {
            onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(display(), style: tx(14, color: t == null ? p.muted.withValues(alpha: 0.7) : p.foreground)),
              ),
            ),
            Icon(LucideIcons.clock, size: 16, color: p.muted),
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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r3xl)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r3xl)),
      ),
    ),
    child: child!,
  );
}

/// `<input type="file">` - picks a document/photo and shows its name.
/// [accept] lists extensions (e.g. ['pdf','jpg','png']); [camera] offers
/// the camera as a source as well.
class TsFileField extends StatelessWidget {
  const TsFileField({
    super.key,
    this.label,
    this.hint,
    this.error,
    required this.file,
    required this.onChanged,
    this.accept,
    this.camera = true,
    this.placeholder = 'Choose a file',
  });
  final String? label;
  final String? hint;
  final String? error;
  final UploadFile? file;
  final ValueChanged<UploadFile?> onChanged;
  final List<String>? accept;
  final bool camera;
  final String placeholder;

  Future<void> _pick(BuildContext context) async {
    final p = Ts.of(context);
    String? source = 'files';
    if (camera) {
      source = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder:
            (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SourceTile(
                      icon: LucideIcons.camera,
                      label: 'Take a photo',
                      onTap: () => Navigator.pop(ctx, 'camera'),
                      p: p,
                    ),
                    _SourceTile(
                      icon: LucideIcons.image,
                      label: 'Choose from gallery',
                      onTap: () => Navigator.pop(ctx, 'gallery'),
                      p: p,
                    ),
                    _SourceTile(
                      icon: LucideIcons.fileText,
                      label: 'Choose a file',
                      onTap: () => Navigator.pop(ctx, 'files'),
                      p: p,
                    ),
                  ],
                ),
              ),
            ),
      );
    }
    if (source == null) return;
    if (source == 'camera' || source == 'gallery') {
      final x = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (x != null) onChanged(UploadFile(x.path, filename: x.name, contentType: _mimeFor(x.name)));
      return;
    }
    final result = await FilePicker.pickFiles(
      type: accept == null ? FileType.any : FileType.custom,
      allowedExtensions: accept,
    );
    final f = result?.files.single;
    if (f?.path != null) onChanged(UploadFile(f!.path!, filename: f.name, contentType: _mimeFor(f.name)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return FieldWrapper(
      label: label,
      hint: hint,
      error: error,
      child: FieldBox(
        onTap: () => _pick(context),
        child: Row(
          children: [
            Icon(
              file == null ? LucideIcons.upload : LucideIcons.fileCheck,
              size: 16,
              color: file == null ? p.muted : p.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  file?.filename ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx(14, color: file == null ? p.muted.withValues(alpha: 0.7) : p.foreground),
                ),
              ),
            ),
            if (file != null)
              GestureDetector(onTap: () => onChanged(null), child: Icon(LucideIcons.x, size: 16, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, required this.onTap, required this.p});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final TsPalette p;

  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r2xl)),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: p.primaryLight, borderRadius: BorderRadius.circular(Ts.rXl)),
      child: Icon(icon, size: 16, color: p.primary),
    ),
    title: Text(label, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
    onTap: onTap,
  );
}

String? _mimeFor(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'csv' => 'text/csv',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => null,
  };
}

/// Segmented control (the login screen's "Password | WhatsApp" switch).
class TsSegmented<T> extends StatelessWidget {
  const TsSegmented({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surfaceHover, borderRadius: BorderRadius.circular(Ts.rXl)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: o.value == value ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Ts.rLg),
                    boxShadow: o.value == value ? p.shadowXs : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    o.label,
                    style: tx(14, weight: FontWeight.w500, color: o.value == value ? p.foreground : p.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
