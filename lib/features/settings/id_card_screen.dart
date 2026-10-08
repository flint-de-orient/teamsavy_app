import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../widgets/ts.dart';
import 'id_card_canvas.dart';
import 'settings_widgets.dart';

/// app/(app)/settings/id-card/page.tsx + id-card-designer.tsx.
///
/// The phone version keeps the whole designer: AI design, Design /
/// Orientation / Front-Back toolbar, "+ Add to card...", AI field
/// suggestions, the PDF preview, the card-to-scale canvas and the full
/// style inspector. The canvas is scaled to the screen width; elements are
/// selected by tap (or from the chip list under the card, since small
/// elements are hard to hit with a finger), the selected element drags to
/// move and its corner handle drags to resize, and X/Y/Width/Height can be
/// typed or stepped in the inspector.
class IdCardSettingsScreen extends StatelessWidget {
  const IdCardSettingsScreen({super.key});

  static const _header = PageHeader(
    title: 'ID Card Designer',
    description:
        "Drag, resize, and style every field on the front and back of the employee ID card. Employee Code and Name can't be removed.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/id-card',
      header: _header,
      builder: (context, data, reload) => [_header, _IdCardDesigner(data: data)],
    );
  }
}

Json _copy(Json value) {
  final copy = asJson(jsonDecode(jsonEncode(value)));
  copy['elements'] ??= <dynamic>[];
  return copy;
}

List<dynamic> _elementsOf(Json layout) => layout['elements'] as List<dynamic>;

/// Merges [patch] into [target]; a null value unsets the key.
void _apply(Map<String, dynamic> target, Map<String, Object?> patch) {
  patch.forEach((key, value) {
    if (value == null) {
      target.remove(key);
    } else {
      target[key] = value;
    }
  });
}

Uint8List? _decodeDataUri(String? uri) {
  if (uri == null) return null;
  try {
    return UriData.parse(uri).contentAsBytes();
  } catch (_) {
    return null;
  }
}

class _IdCardDesigner extends StatefulWidget {
  const _IdCardDesigner({required this.data});
  final Json data;

  @override
  State<_IdCardDesigner> createState() => _IdCardDesignerState();
}

class _IdCardDesignerState extends State<_IdCardDesigner> {
  // The designer works on local state from the first load; later reloads
  // (after Save) don't overwrite in-progress edits, as on the web.
  late final bool _canWrite = widget.data.b('canWrite');
  late final Json _presets = widget.data.m('presets');
  late String _templateKey = widget.data.s('templateKey', 'MODERN_BLUE');
  late String _orientation = widget.data.s('orientation', 'LANDSCAPE');
  late Json _front = _copy(widget.data.m('frontLayout'));
  late Json _back = _copy(widget.data.m('backLayout'));
  late Uint8List? _frontBackground = _decodeDataUri(widget.data.sn('frontBackgroundImageDataUri'));

  String _face = 'front';
  String? _selectedId;

  final _aiPrompt = TextEditingController();
  bool _aiGenerating = false;
  String? _aiError;
  bool _suggesting = false;
  String? _suggestError;
  bool _previewLoading = false;
  String? _previewError;
  bool _saving = false;
  String? _saveError;
  bool _saveSuccess = false;

  @override
  void dispose() {
    _aiPrompt.dispose();
    super.dispose();
  }

  Json get _active => _face == 'front' ? _front : _back;

  Json? get _selected {
    for (final el in _elementsOf(_active)) {
      if (el is Map && el['id'] == _selectedId) return el.cast<String, dynamic>();
    }
    return null;
  }

  void _loadPreset() {
    final preset = _presets.m('$_templateKey.$_orientation');
    _front = _copy(preset.m('front'));
    _back = _copy(preset.m('back'));
    _frontBackground = null;
    _selectedId = null;
  }

  void _updateElement(String id, Map<String, Object?> patch) {
    final (cardW, cardH) = cardDimensionsIn(_orientation);
    setState(() {
      for (final raw in _elementsOf(_active)) {
        if (raw is! Map<String, dynamic> || raw['id'] != id) continue;
        _apply(raw, patch);
        // Typed X/Y/W/H values are clamped too, so nothing can be pushed
        // off the card invisibly.
        if (patch.keys.any((k) => k == 'x' || k == 'y' || k == 'width' || k == 'height')) {
          raw.addAll(clampElement(raw, cardW, cardH));
        }
      }
    });
  }

  void _updateLayout(Map<String, Object?> patch) {
    setState(() => _apply(_active, patch));
  }

  void _deleteSelected() {
    final el = _selected;
    if (el == null || isUndeletable(el)) return;
    setState(() {
      _elementsOf(_active).removeWhere((e) => e is Map && e['id'] == _selectedId);
      _selectedId = null;
    });
  }

  void _add(String value) {
    final index = _elementsOf(_active).length;
    final Json el = switch (value) {
      'PHOTO_ELEMENT' => makeMediaElement('photo', index),
      'LOGO_ELEMENT' => makeMediaElement('logo', index),
      'QR_ELEMENT' => makeMediaElement('qr', index),
      'TEXT_ELEMENT' => makeTextElement(index),
      _ => makeFieldElement(value, index),
    };
    setState(() {
      _elementsOf(_active).add(el);
      _selectedId = el.s('id');
    });
  }

  Future<void> _changeTemplate(String? key) async {
    if (key == null || key == _templateKey) return;
    final ok = await confirmDialog(
      context,
      message: "Switching designs replaces your current layout with that design's starting point. Continue?",
    );
    if (!ok || !mounted) return;
    setState(() {
      _templateKey = key;
      _loadPreset();
    });
  }

  Future<void> _changeOrientation(String? value) async {
    if (value == null || value == _orientation) return;
    final ok = await confirmDialog(
      context,
      message: "Changing orientation resets the layout to that orientation's starting point. Continue?",
    );
    if (!ok || !mounted) return;
    setState(() {
      _orientation = value;
      _loadPreset();
    });
  }

  Future<void> _resetToPreset() async {
    final ok = await confirmDialog(
      context,
      message:
          "Reset the whole card (front and back) to this design's starting point? Unsaved changes will be lost.",
      confirmLabel: 'Reset',
    );
    if (!ok || !mounted) return;
    setState(_loadPreset);
  }

  Future<void> _suggest() async {
    setState(() {
      _suggesting = true;
      _suggestError = null;
    });
    final r = await api.action('settings.suggestIdCardFields');
    if (!mounted) return;
    setState(() {
      _suggesting = false;
      if (!r.ok) {
        _suggestError = r.error;
        return;
      }
      _addSuggestedFields(_front, r.data?.list<String>('front') ?? const []);
      _addSuggestedFields(_back, r.data?.list<String>('back') ?? const []);
    });
  }

  void _addSuggestedFields(Json layout, List<String> keys) {
    final elements = _elementsOf(layout);
    final existing = {
      for (final e in elements)
        if (e is Map && e['kind'] == 'field') e['fieldKey'],
    };
    final start = elements.length;
    final additions = keys.where((k) => !existing.contains(k)).toList();
    for (var i = 0; i < additions.length; i++) {
      elements.add(makeFieldElement(additions[i], start + i));
    }
  }

  Future<void> _generateAiDesign() async {
    if (_elementsOf(_front).isNotEmpty || _elementsOf(_back).isNotEmpty) {
      final ok = await confirmDialog(
        context,
        message: 'Generating a new AI design replaces your current front and back layout. Continue?',
      );
      if (!ok || !mounted) return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _aiGenerating = true;
      _aiError = null;
    });
    final r = await api.action('settings.generateIdCardDesignByAi', fields: {
      'orientation': _orientation,
      'prompt': _aiPrompt.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _aiGenerating = false;
      final data = r.data;
      if (!r.ok || data == null) {
        _aiError = r.error;
        return;
      }
      _front = _copy(data.m('front'));
      _back = _copy(data.m('back'));
      _frontBackground = _decodeDataUri(data.sn('frontBackgroundImageDataUri'));
      _selectedId = null;
    });
  }

  /// POSTs the in-progress (possibly unsaved) layout to the web's
  /// /api/id-card/preview, which renders it with sample data, and opens
  /// the PDF.
  Future<void> _previewPdf() async {
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    const fallback = "Couldn't generate a preview.";
    String? error;
    try {
      final client = dio.Dio(dio.BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 120),
        validateStatus: (_) => true,
        responseType: dio.ResponseType.bytes,
      ));
      final res = await client.post<List<int>>(
        '${api.host}/api/id-card/preview',
        data: jsonEncode({'orientation': _orientation, 'frontLayout': _front, 'backLayout': _back}),
        options: dio.Options(headers: {...api.authHeaders, 'Content-Type': 'application/json'}),
      );
      final bytes = res.data ?? const <int>[];
      if ((res.statusCode ?? 0) >= 400) {
        error = _errorFrom(bytes) ?? fallback;
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}${Platform.pathSeparator}IDCard_Preview.pdf');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      }
    } catch (_) {
      error = fallback;
    }
    if (!mounted) return;
    setState(() {
      _previewLoading = false;
      _previewError = error;
    });
  }

  static String? _errorFrom(List<int> bytes) {
    try {
      final body = jsonDecode(utf8.decode(bytes));
      return body is Map ? body['error']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = false;
    });
    final r = await runAction(
      context,
      () => api.action('settings.saveIdCardLayout', fields: {
        'templateKey': _templateKey,
        'orientation': _orientation,
        'frontLayout': jsonEncode(_front),
        'backLayout': jsonEncode(_back),
      }),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = r.error;
      _saveSuccess = r.ok;
    });
  }

  Future<void> _openAddSheet() async {
    final available = idCardTogglableFieldKeys
        .where((key) => !_elementsOf(_active).any((e) => e is Map && e['kind'] == 'field' && e['fieldKey'] == key))
        .toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _AddToCardSheet(availableFieldKeys: available),
    );
    if (picked != null && mounted) _add(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final layout = _active;
    final selected = _selected;
    final hasBackground = _face == 'front' && _frontBackground != null;
    return Gap(
      children: [
        if (_canWrite) _aiPanel(p),
        TsCard(
          padding: const EdgeInsets.all(16),
          child: Gap(
            gap: 12,
            children: [
              TsSelect<String>(
                label: 'Design',
                value: _templateKey,
                enabled: _canWrite,
                options: [for (final e in idCardTemplateLabels.entries) SelectOption(e.key, e.value)],
                onChanged: _changeTemplate,
              ),
              TsSelect<String>(
                label: 'Orientation',
                value: _orientation,
                enabled: _canWrite,
                options: [for (final e in idCardOrientationLabels.entries) SelectOption(e.key, e.value)],
                onChanged: _changeOrientation,
              ),
              TsSegmented<String>(
                value: _face,
                options: const [SelectOption('front', 'Front'), SelectOption('back', 'Back')],
                onChanged: (v) => setState(() {
                  _face = v;
                  _selectedId = null;
                }),
              ),
              if (_canWrite)
                TsButton.secondary(label: 'Reset to Preset', icon: LucideIcons.rotateCcw, onPressed: _resetToPreset),
            ],
          ),
        ),
        if (_canWrite)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TsButton.secondary(label: '+ Add to card...', compact: true, onPressed: _openAddSheet),
              TsButton.secondary(
                label: 'Suggest Fields (AI)',
                pendingLabel: 'Thinking...',
                pending: _suggesting,
                compact: true,
                onPressed: _suggest,
              ),
              TsButton.secondary(
                label: 'Preview PDF',
                pendingLabel: 'Rendering...',
                pending: _previewLoading,
                compact: true,
                onPressed: _previewPdf,
              ),
            ],
          ),
        if (_suggestError != null) StatusMessage.error(_suggestError),
        if (_previewError != null) StatusMessage.error(_previewError),
        IdCardCanvas(
          layout: layout,
          orientation: _orientation,
          selectedId: _selectedId,
          editable: _canWrite,
          backgroundImage: _face == 'front' ? _frontBackground : null,
          onSelect: (id) => setState(() => _selectedId = id),
          onChange: _updateElement,
        ),
        _ElementChips(
          elements: _elementsOf(layout).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
          selectedId: _selectedId,
          onSelect: (id) => setState(() => _selectedId = id),
        ),
        if (selected != null)
          _ElementInspector(
            key: ValueKey('$_face/${selected.s('id')}'),
            element: selected,
            canWrite: _canWrite,
            onChange: (patch) => _updateElement(selected.s('id'), patch),
            onDelete: _deleteSelected,
          )
        else
          _CardPanel(
            layout: layout,
            canWrite: _canWrite,
            hasBackgroundImage: hasBackground,
            onChange: _updateLayout,
            onRemoveBackgroundImage: _face == 'front'
                ? () => setState(() {
                      _front.remove('backgroundImagePath');
                      _frontBackground = null;
                    })
                : null,
          ),
        if (_canWrite) ...[
          if (_saveError != null) StatusMessage.error(_saveError),
          if (!_saving && _saveSuccess) StatusMessage.success('Saved.'),
          TsButton(label: 'Save', pendingLabel: 'Saving...', pending: _saving, expand: true, onPressed: _save),
        ] else if (_saveError != null)
          StatusMessage.error(_saveError),
      ],
    );
  }

  Widget _aiPanel(TsPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(p.primary.withValues(alpha: 0.05), p.surface),
        borderRadius: BorderRadius.circular(Ts.r2xl),
        border: Border.all(color: p.primary.withValues(alpha: 0.3)),
      ),
      child: Gap(
        gap: 12,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16, color: p.purple),
              const SizedBox(width: 8),
              Text('Design ID by AI', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
            ],
          ),
          const Muted(
            'Generate a complete front-and-back design, including a decorative background image for the front, in one click. Your company logo is automatically included if you have one on file. You can still drag, resize, and restyle anything it produces below.',
            size: 12,
          ),
          TsTextarea(
            controller: _aiPrompt,
            rows: 2,
            enabled: !_aiGenerating,
            placeholder:
                'Optional - describe a style, e.g. "modern and minimal, use our brand blue". Leave blank for an automatic design.',
          ),
          SubmitButton(
            label: 'Design ID by AI',
            pendingLabel: 'Designing...',
            pending: _aiGenerating,
            onPressed: _generateAiDesign,
          ),
          if (_aiError != null) StatusMessage.error(_aiError),
        ],
      ),
    );
  }
}

/// The "+ Add to card..." select, as a sheet with its two option groups.
class _AddToCardSheet extends StatelessWidget {
  const _AddToCardSheet({required this.availableFieldKeys});
  final List<String> availableFieldKeys;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    Widget group(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(title, style: tx(12, weight: FontWeight.w700, color: p.muted, tracking: 0.04)),
        );
    Widget option(String value, String label, IconData icon) => ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r2xl)),
          leading: Icon(icon, size: 18, color: p.primary),
          title: Text(label, style: tx(14, weight: FontWeight.w500, color: p.foreground)),
          onTap: () => Navigator.of(context).pop(value),
        );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('+ Add to card...', style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
          ),
          if (availableFieldKeys.isNotEmpty) ...[
            group('FIELDS'),
            for (final key in availableFieldKeys) option(key, idCardFieldLabels[key] ?? key, LucideIcons.textCursorInput),
          ],
          group('OTHER'),
          option('PHOTO_ELEMENT', 'Photo', LucideIcons.user),
          option('LOGO_ELEMENT', 'Company Logo', LucideIcons.image),
          option('QR_ELEMENT', 'QR Code', LucideIcons.qrCode),
          option('TEXT_ELEMENT', 'Custom Text', LucideIcons.type),
        ],
      ),
    );
  }
}

/// Every element on the current face as a tappable chip - a phone-friendly
/// way to pick small or overlapping elements on the scaled-down card.
class _ElementChips extends StatelessWidget {
  const _ElementChips({required this.elements, required this.selectedId, required this.onSelect});
  final List<Json> elements;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (elements.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final el in elements)
          GestureDetector(
            onTap: () => onSelect(el.s('id') == selectedId ? null : el.s('id')),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: el.s('id') == selectedId ? p.infoLight : p.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: el.s('id') == selectedId ? const Color(0xFF2563EB) : p.border),
              ),
              child: Text(
                el.s('kind') == 'static_text' && el.sn('content') != null ? '“${el.s('content')}”' : elementTitle(el),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx(12, weight: FontWeight.w500, color: el.s('id') == selectedId ? p.info : p.muted),
              ),
            ),
          ),
      ],
    );
  }
}

/// The right-hand "Card" panel shown while nothing is selected.
class _CardPanel extends StatelessWidget {
  const _CardPanel({
    required this.layout,
    required this.canWrite,
    required this.hasBackgroundImage,
    required this.onChange,
    this.onRemoveBackgroundImage,
  });
  final Json layout;
  final bool canWrite;
  final bool hasBackgroundImage;
  final ValueChanged<Map<String, Object?>> onChange;
  final VoidCallback? onRemoveBackgroundImage;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsCard(
      padding: const EdgeInsets.all(16),
      child: Gap(
        gap: 12,
        children: [
          Text('Card', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
          const Muted('Click an element to edit its style, or select nothing to edit the card itself.', size: 12),
          if (hasBackgroundImage)
            TsPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: p.background,
              child: Row(
                children: [
                  Expanded(child: Text('AI background image set', style: tx(14, color: p.foreground))),
                  if (canWrite && onRemoveBackgroundImage != null)
                    TsLink('Remove', onTap: onRemoveBackgroundImage, size: 12, color: p.danger, weight: FontWeight.w500),
                ],
              ),
            ),
          ColorField(
            label: 'Background color',
            value: layout.sn('backgroundColor'),
            enabled: canWrite,
            onChanged: (v) => onChange({'backgroundColor': v}),
          ),
          ColorField(
            label: 'Border color',
            value: layout.sn('borderColor'),
            enabled: canWrite,
            onChanged: (v) => onChange({'borderColor': v}),
          ),
          NumberStepField(
            label: 'Border width (pt)',
            value: layout.d('borderWidth'),
            min: 0,
            max: 10,
            step: 0.5,
            enabled: canWrite,
            onChanged: (v) => onChange({'borderWidth': v}),
          ),
        ],
      ),
    );
  }
}

/// The element inspector (right-hand panel with an element selected).
class _ElementInspector extends StatefulWidget {
  const _ElementInspector({
    super.key,
    required this.element,
    required this.canWrite,
    required this.onChange,
    required this.onDelete,
  });
  final Json element;
  final bool canWrite;
  final ValueChanged<Map<String, Object?>> onChange;
  final VoidCallback onDelete;

  @override
  State<_ElementInspector> createState() => _ElementInspectorState();
}

class _ElementInspectorState extends State<_ElementInspector> {
  late final _content = TextEditingController(text: widget.element.s('content'));

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final el = widget.element;
    final w = widget.canWrite;
    final kind = el.s('kind');
    final isText = kind == 'field' || kind == 'static_text';
    final isMedia = kind == 'photo' || kind == 'logo' || kind == 'qr';
    final onChange = widget.onChange;

    Widget geometry(String key, String label) => NumberStepField(
          label: label,
          value: el.d(key),
          step: 0.05,
          min: key == 'width' || key == 'height' ? 0.05 : null,
          enabled: w,
          onChanged: (v) => onChange({key: v}),
        );

    return TsCard(
      padding: const EdgeInsets.all(16),
      child: Gap(
        gap: 12,
        children: [
          Row(
            children: [
              Expanded(child: Text(elementTitle(el), style: tx(14, weight: FontWeight.w600, color: p.foreground))),
              if (w && !isUndeletable(el))
                TsLink('Remove', onTap: widget.onDelete, size: 12, color: p.danger, weight: FontWeight.w500),
            ],
          ),
          if (kind == 'static_text')
            TsInput(
              controller: _content,
              label: 'Text',
              maxLength: 200,
              enabled: w,
              onChanged: (v) => onChange({'content': v}),
            ),
          if (kind == 'field')
            SettingsCheckbox(
              label: 'Show label (e.g. “Designation: ...”)',
              value: el.at('showLabel') != false,
              enabled: w,
              onChanged: (v) => onChange({'showLabel': v}),
            ),
          Row(
            children: [
              Expanded(child: geometry('x', 'X (in)')),
              const SizedBox(width: 8),
              Expanded(child: geometry('y', 'Y (in)')),
            ],
          ),
          Row(
            children: [
              Expanded(child: geometry('width', 'Width (in)')),
              const SizedBox(width: 8),
              Expanded(child: geometry('height', 'Height (in)')),
            ],
          ),
          if (isText) ...[
            TsSelect<String>(
              label: 'Font',
              value: el.s('fontFamily', 'Arial'),
              enabled: w,
              options: [for (final f in idCardFontFamilies) SelectOption(f, f)],
              onChanged: (v) => onChange({'fontFamily': v}),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberStepField(
                    label: 'Size (pt)',
                    value: el.dN('fontSize') ?? 7,
                    min: 3,
                    max: 72,
                    step: 0.5,
                    enabled: w,
                    onChanged: (v) => onChange({'fontSize': v}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TsSelect<int>(
                    label: 'Weight',
                    value: el.i('fontWeight', 400) >= 700 ? 700 : 400,
                    enabled: w,
                    options: const [SelectOption(400, 'Normal'), SelectOption(700, 'Bold')],
                    onChanged: (v) => onChange({'fontWeight': v}),
                  ),
                ),
              ],
            ),
            IgnorePointer(
              ignoring: !w,
              child: TsSegmented<String>(
                value: el.s('textAlign', 'left'),
                options: const [
                  SelectOption('left', 'Left'),
                  SelectOption('center', 'Center'),
                  SelectOption('right', 'Right'),
                ],
                onChanged: (v) => onChange({'textAlign': v}),
              ),
            ),
            ColorField(
              label: 'Text color',
              value: el.sn('color') ?? '#0f172a',
              enabled: w,
              onChanged: (v) => onChange({'color': v}),
            ),
          ],
          ColorField(
            label: 'Background',
            value: el.sn('backgroundColor'),
            enabled: w,
            onChanged: (v) => onChange({'backgroundColor': v}),
          ),
          ColorField(
            label: 'Border color',
            value: el.sn('borderColor'),
            enabled: w,
            onChanged: (v) => onChange({'borderColor': v}),
          ),
          NumberStepField(
            label: 'Border width (pt)',
            value: el.d('borderWidth'),
            min: 0,
            max: 10,
            step: 0.5,
            enabled: w,
            onChanged: (v) => onChange({'borderWidth': v}),
          ),
          if (isMedia)
            SettingsCheckbox(
              label: 'Circular',
              value: el.b('circular'),
              enabled: w,
              onChanged: (v) => onChange({'circular': v}),
            ),
        ],
      ),
    );
  }
}

String _fmtNumber(double v) {
  final rounded = (v * 100).round() / 100;
  return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
}

/// A number input (`<input type="number" step=...>`) with - / + steppers,
/// which are much easier than typing decimals on a phone. Shows the value
/// rounded to 2 decimals, and follows outside changes (e.g. a drag on the
/// canvas) without fighting the user's typing.
class NumberStepField extends StatefulWidget {
  const NumberStepField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.step,
    this.min,
    this.max,
    this.enabled = true,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double? min;
  final double? max;
  final bool enabled;

  @override
  State<NumberStepField> createState() => _NumberStepFieldState();
}

class _NumberStepFieldState extends State<NumberStepField> {
  late final _controller = TextEditingController(text: _fmtNumber(widget.value));

  @override
  void didUpdateWidget(covariant NumberStepField old) {
    super.didUpdateWidget(old);
    final typed = double.tryParse(_controller.text);
    if (old.value != widget.value && (typed == null || _fmtNumber(typed) != _fmtNumber(widget.value))) {
      _controller.text = _fmtNumber(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int direction) {
    var next = ((widget.value + direction * widget.step) * 1000).round() / 1000;
    if (widget.min != null && next < widget.min!) next = widget.min!;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    _controller.text = _fmtNumber(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    Widget stepper(IconData icon, int direction) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _step(direction) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Icon(icon, size: 16, color: widget.enabled ? p.primary : p.muted),
          ),
        );
    return TsInput(
      controller: _controller,
      label: widget.label,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefix: stepper(LucideIcons.minus, -1),
      suffix: stepper(LucideIcons.plus, 1),
      onChanged: (text) {
        final v = double.tryParse(text.trim());
        if (v != null) widget.onChanged(v);
      },
    );
  }
}

const _swatches = [
  '#ffffff', '#f8fafc', '#e2e8f0', '#94a3b8', '#64748b', '#334155', '#0f172a', '#000000', //
  '#dbeafe', '#93c5fd', '#3b82f6', '#2563eb', '#1d4ed8', '#1e3a8a', '#06b6d4', '#0e7490', //
  '#d1fae5', '#6ee7b7', '#10b981', '#059669', '#065f46', '#fef3c7', '#fbbf24', '#ca8a04', //
  '#fee2e2', '#f87171', '#dc2626', '#991b1b', '#fed7aa', '#f97316', '#ede9fe', '#a78bfa', //
  '#7c3aed', '#5b21b6', '#fce7f3', '#ec4899', '#be185d', '#78350f', '#a16207', '#b45309', //
];

/// `<input type="color">`: a swatch next to the label that opens a palette
/// with a hex field. An unset colour shows as white, like the web input.
class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.label, required this.value, required this.onChanged, this.enabled = true});
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final color = hexColor(value) ?? Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () async {
              FocusScope.of(context).unfocus();
              final picked = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (ctx) => _ColorSheet(title: label, initial: value ?? '#ffffff'),
              );
              if (picked != null) onChanged(picked);
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Row(
          children: [
            Expanded(child: Text(label, style: tx(14, color: p.foreground))),
            Text((value ?? '#ffffff').toLowerCase(), style: tx(12, color: p.muted)),
            const SizedBox(width: 10),
            Container(
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border),
                boxShadow: p.shadowXs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSheet extends StatefulWidget {
  const _ColorSheet({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late final _hex = TextEditingController(text: widget.initial.toLowerCase());
  String? _error;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _done() {
    var hex = _hex.text.trim().toLowerCase();
    if (!hex.startsWith('#')) hex = '#$hex';
    if (!RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').hasMatch(hex)) {
      setState(() => _error = 'Enter a hex colour like #1d4ed8.');
      return;
    }
    // Normalise #abc to #aabbcc, the form a colour input always reports.
    if (hex.length == 4) hex = '#${hex.substring(1).split('').map((c) => '$c$c').join()}';
    Navigator.of(context).pop(hex);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final current = _hex.text.trim().toLowerCase();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in _swatches)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(s),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: hexColor(s),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: s == current ? p.accentViolet : p.border,
                        width: s == current ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TsInput(
            controller: _hex,
            label: 'Hex',
            placeholder: '#1d4ed8',
            error: _error,
            prefix: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: hexColor(current) ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _done(),
          ),
          const SizedBox(height: 16),
          TsButton(label: 'Done', expand: true, onPressed: _done),
        ],
      ),
    );
  }
}
