import 'dart:typed_data';

import 'package:flutter_svg/flutter_svg.dart';

import '../../widgets/ts.dart';

/// One TextEditingController per form field, keyed by the field's web
/// `name`, so a form can post `values` exactly as the web form would.
class FieldControllers {
  FieldControllers(Map<String, String?> initial)
      : _controllers = {
          for (final e in initial.entries) e.key: TextEditingController(text: e.value ?? ''),
        };

  final Map<String, TextEditingController> _controllers;

  TextEditingController operator [](String name) => _controllers[name]!;

  Map<String, String> get values => _controllers.map((k, c) => MapEntry(k, c.text));

  void clear() {
    for (final c in _controllers.values) {
      c.clear();
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
  }
}

/// Shown above a settings form the signed-in role can see but not save
/// (HR_ADMIN on Company/Policy settings) - the same text the web's save
/// action answers with, so the form reads as view-only up front instead of
/// failing on submit.
class ReadOnlyNote extends StatelessWidget {
  const ReadOnlyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => StatusMessage(text, kind: StatusKind.info, boxed: true);
}

/// The web's `<h3 className="text-sm font-semibold">` sub-headings.
class SubHeading extends StatelessWidget {
  const SubHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: tx(14, weight: FontWeight.w600, color: Ts.of(context).foreground));
}

/// A labelled checkbox with an optional muted hint, disabled when the
/// form is read-only.
class SettingsCheckbox extends StatelessWidget {
  const SettingsCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final box = TsCheckbox(label: label, value: value, onChanged: onChanged, hint: hint);
    if (enabled) return box;
    return IgnorePointer(child: Opacity(opacity: 0.6, child: box));
  }
}

/// The web forms' `{error && <p className="text-danger">} {success && ...}`
/// pair.
class FormStatus extends StatelessWidget {
  const FormStatus({super.key, this.error, this.success});
  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    if (error != null) return StatusMessage.error(error);
    if (success != null) return StatusMessage.success(success);
    return const SizedBox.shrink();
  }
}

/// A primary submit pill that sizes to its label (`w-fit`) like the web's.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.pending,
    required this.onPressed,
    this.pendingLabel = 'Saving...',
    this.secondary = false,
  });
  final String label;
  final String pendingLabel;
  final bool pending;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final button = secondary
        ? TsButton.secondary(label: label, pendingLabel: pendingLabel, pending: pending, onPressed: onPressed)
        : TsButton(label: label, pendingLabel: pendingLabel, pending: pending, onPressed: onPressed);
    return Align(alignment: Alignment.centerLeft, child: button);
  }
}

/// A logo/signature from one of the authenticated `/api/files/*` routes,
/// shown like the web's `<img className="h-12 w-auto rounded bg-white
/// object-contain p-1">`. Renders nothing if the file is missing. Bump
/// [version] to refetch after an upload.
class ProtectedImage extends StatefulWidget {
  const ProtectedImage({super.key, required this.path, this.version = 0, this.height = 48});
  final String path;
  final int version;
  final double height;

  @override
  State<ProtectedImage> createState() => _ProtectedImageState();
}

class _ProtectedImageState extends State<ProtectedImage> {
  late Future<Uint8List?> _bytes = api.bytes(widget.path);

  @override
  void didUpdateWidget(covariant ProtectedImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.version != widget.version) {
      _bytes = api.bytes(widget.path);
    }
  }

  static bool _isSvg(Uint8List bytes) {
    final head = String.fromCharCodes(bytes.take(256)).trimLeft().toLowerCase();
    return head.startsWith('<svg') || (head.startsWith('<?xml') && head.contains('<svg'));
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
        final inner = widget.height - 8;
        final image = _isSvg(bytes)
            ? SvgPicture.memory(bytes, height: inner, fit: BoxFit.contain)
            : Image.memory(bytes, height: inner, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink());
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: p.border),
            ),
            child: image,
          ),
        );
      },
    );
  }
}
