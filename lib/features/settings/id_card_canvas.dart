import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show EagerGestureRecognizer;

import '../../widgets/ts.dart';

// lib/id-card/fields.ts + layout-types.ts, and the designer's sample values.

const idCardFieldLabels = {
  'EMPLOYEE_CODE': 'Employee Code',
  'NAME': 'Name',
  'PHOTO': 'Photo',
  'DESIGNATION': 'Designation',
  'DEPARTMENT': 'Department',
  'BLOOD_GROUP': 'Blood Group',
  'DATE_OF_BIRTH': 'Date of Birth',
  'DATE_OF_JOINING': 'Date of Joining',
  'MOBILE_NUMBER': 'Mobile Number',
  'EMERGENCY_CONTACT': 'Emergency Contact',
  'QR_CODE': 'QR Code',
  'COMPANY_ADDRESS': 'Company Address',
  'COMPANY_NAME': 'Company Name',
};

/// ID_CARD_TOGGLABLE_FIELD_KEYS: everything but the always-on pair and the
/// photo/QR (which are element kinds of their own).
const idCardTogglableFieldKeys = [
  'DESIGNATION',
  'DEPARTMENT',
  'BLOOD_GROUP',
  'DATE_OF_BIRTH',
  'DATE_OF_JOINING',
  'MOBILE_NUMBER',
  'EMERGENCY_CONTACT',
  'COMPANY_ADDRESS',
  'COMPANY_NAME',
];

const idCardUndeletableFieldKeys = ['EMPLOYEE_CODE', 'NAME'];

const idCardTemplateLabels = {
  'MODERN_BLUE': 'Modern Blue',
  'CLASSIC_CORPORATE': 'Classic Corporate',
  'MINIMAL_MONO': 'Minimal Mono',
};

const idCardOrientationLabels = {'LANDSCAPE': 'Landscape', 'PORTRAIT': 'Portrait'};

const idCardFontFamilies = ['Arial', 'Georgia', 'Verdana', 'Trebuchet MS', 'Courier New'];

const _printLabels = {
  'EMPLOYEE_CODE': 'Emp. Code',
  'NAME': 'Name',
  'PHOTO': 'Photo',
  'DESIGNATION': 'Designation',
  'DEPARTMENT': 'Department',
  'BLOOD_GROUP': 'Blood Group',
  'DATE_OF_BIRTH': 'DOB',
  'DATE_OF_JOINING': 'Date of Joining',
  'MOBILE_NUMBER': 'Mobile',
  'EMERGENCY_CONTACT': 'Emergency Contact',
  'QR_CODE': 'QR Code',
  'COMPANY_ADDRESS': 'Address',
  'COMPANY_NAME': 'Company',
};

// Default seed for the designer's editable "Preview Data" fields
// (id_card_screen.dart's `_sampleValues` state) - mirrors the web
// designer's SAMPLE_VALUES and the preview route's SAMPLE_DATA key-for-key.
// `ElementPreview` below takes the live (possibly-edited) map as a
// parameter; this is only ever the starting point, never mutated here.
const Map<String, String> idCardSampleValueDefaults = {
  'EMPLOYEE_CODE': '2001010001',
  'NAME': 'Jane Doe',
  'PHOTO': '',
  'DESIGNATION': 'Software Engineer',
  'DEPARTMENT': 'Engineering',
  'BLOOD_GROUP': 'O+',
  'DATE_OF_BIRTH': '01/01/2001',
  'DATE_OF_JOINING': '01/06/2024',
  'MOBILE_NUMBER': '+91 98765 43210',
  'EMERGENCY_CONTACT': 'John Doe (+91 91234 56789)',
  'QR_CODE': '',
  'COMPANY_ADDRESS': '123 Sample Street, Sample City - 700001',
  'COMPANY_NAME': 'Sample Company Pvt. Ltd.',
};

// The card is designed in web-safe fonts; iOS ships all five, Android
// falls back to the closest generic family.
const _fontFallbacks = {
  'Arial': ['Helvetica', 'Roboto', 'sans-serif'],
  'Georgia': ['Times New Roman', 'Noto Serif', 'serif'],
  'Verdana': ['Geneva', 'Roboto', 'sans-serif'],
  'Trebuchet MS': ['Roboto', 'sans-serif'],
  'Courier New': ['Courier', 'Roboto Mono', 'monospace'],
};

/// CR-80 card size in inches.
(double, double) cardDimensionsIn(String orientation) =>
    orientation == 'PORTRAIT' ? (2.125, 3.375) : (3.375, 2.125);

/// The element's inspector / list title.
String elementTitle(Json el) {
  switch (el.s('kind')) {
    case 'field':
      return idCardFieldLabels[el.s('fieldKey')] ?? el.s('fieldKey');
    case 'static_text':
      return 'Custom Text';
    case 'photo':
      return 'Photo';
    case 'logo':
      return 'Company Logo';
    default:
      return 'QR Code';
  }
}

bool isUndeletable(Json el) => el.s('kind') == 'field' && idCardUndeletableFieldKeys.contains(el.s('fieldKey'));

/// lib/id-card/canvas-math.ts#clampElement.
Map<String, double> clampElement(Json el, double cardWidth, double cardHeight, {double minSize = 0.2}) {
  final width = math.min(math.max(el.d('width'), minSize), cardWidth);
  final height = math.min(math.max(el.d('height'), minSize), cardHeight);
  final x = math.min(math.max(el.d('x'), 0.0), cardWidth - width);
  final y = math.min(math.max(el.d('y'), 0.0), cardHeight - height);
  return {'x': x, 'y': y, 'width': width, 'height': height};
}

String _newElementId(String kind) {
  final rand = math.Random();
  final suffix = List.generate(5, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[rand.nextInt(36)]).join();
  return '${kind}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_$suffix';
}

Map<String, double> _cascade(int index) => {'x': 0.2 + (index % 5) * 0.18, 'y': 0.2 + (index ~/ 5) * 0.18};

Json makeFieldElement(String fieldKey, int index) => {
      'id': _newElementId('field'),
      'kind': 'field',
      'fieldKey': fieldKey,
      ..._cascade(index),
      'width': 1.3,
      'height': 0.2,
      'fontFamily': 'Arial',
      'fontSize': 7,
      'fontWeight': 400,
      'color': '#0f172a',
      'textAlign': 'left',
      'showLabel': true,
    };

Json makeMediaElement(String kind, int index) => {
      'id': _newElementId(kind),
      'kind': kind,
      ..._cascade(index),
      'width': 0.6,
      'height': 0.6,
    };

Json makeTextElement(int index) => {
      'id': _newElementId('text'),
      'kind': 'static_text',
      'content': 'Text',
      ..._cascade(index),
      'width': 1.3,
      'height': 0.2,
      'fontFamily': 'Arial',
      'fontSize': 6.5,
      'fontWeight': 400,
      'color': '#334155',
      'textAlign': 'left',
    };

/// "#rgb" / "#rrggbb" -> Color.
Color? hexColor(String? value) {
  if (value == null) return null;
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length != 6) return null;
  final n = int.tryParse(hex, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

/// The designer canvas: the card face drawn to scale with every element
/// positioned in inches, exactly like the web canvas. Tap an element to
/// select it; the selected one can be dragged to move it and its corner
/// handle dragged to resize it (both clamped to the card).
class IdCardCanvas extends StatelessWidget {
  const IdCardCanvas({
    super.key,
    required this.layout,
    required this.orientation,
    required this.selectedId,
    required this.onSelect,
    required this.onChange,
    this.backgroundImage,
    this.editable = true,
    this.sampleValues,
    this.onBackgroundPositionChanged,
  });

  final Json layout;
  final String orientation;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final void Function(String id, Map<String, Object?> patch) onChange;
  final Uint8List? backgroundImage;
  final bool editable;
  // The designer's editable "Preview Data" - falls back to the hardcoded
  // defaults (idCardSampleValueDefaults) when the caller doesn't pass one.
  final Map<String, String>? sampleValues;
  // Drag-to-reposition the background image - see layout-types.ts's
  // CardLayout.backgroundImagePositionX/Y. Called with the new 0-100
  // percentages on each axis as the admin drags; omitted (null) makes the
  // background layer a plain tap-to-deselect area with no drag, same as
  // before this feature existed.
  final void Function(double x, double y)? onBackgroundPositionChanged;

  // The web canvas renders at 96px/in x 2.5 zoom; on a phone it's scaled
  // down to fit the width.
  static const _maxPxPerInch = 96 * 2.5;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final (cardW, cardH) = cardDimensionsIn(orientation);
    return LayoutBuilder(
      builder: (context, constraints) {
        final ppi = math.min(constraints.maxWidth / cardW, _maxPxPerInch);
        final pt = ppi / 72;
        final borderColor = hexColor(layout.sn('borderColor'));
        final borderWidth = layout.d('borderWidth');
        final elements = layout.l('elements');
        final resolvedSampleValues = sampleValues ?? idCardSampleValueDefaults;
        // See layout-types.ts's CardLayout.backgroundImagePositionX/Y -
        // 0-100 on each axis, 50 (center) when unset, same default every
        // pre-existing layout already renders at. Flutter's `Alignment`
        // uses -1..1 ("start"..."end") for the same cover-fit positioning
        // CSS `background-position` expresses as 0%-100%, so `(pct/50)-1`
        // is the exact, direction-for-direction equivalent of this
        // percentage on both axes - not an approximation of it.
        final posX = layout.dN('backgroundImagePositionX') ?? 50;
        final posY = layout.dN('backgroundImagePositionY') ?? 50;
        final bgAlignment = Alignment((posX / 50) - 1, (posY / 50) - 1);
        return Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Ts.rLg),
              border: Border.all(color: p.border),
              boxShadow: p.shadowCard,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Ts.rLg - 1),
              child: _BackgroundDragLayer(
                active: backgroundImage != null && editable && onBackgroundPositionChanged != null,
                posX: posX,
                posY: posY,
                cardPxWidth: cardW * ppi,
                cardPxHeight: cardH * ppi,
                onPositionChanged: (x, y) => onBackgroundPositionChanged?.call(x, y),
                onTapDeselect: () => onSelect(null),
                child: Container(
                  width: cardW * ppi,
                  height: cardH * ppi,
                  decoration: BoxDecoration(
                    color: hexColor(layout.sn('backgroundColor')) ?? Colors.white,
                    image: backgroundImage == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(backgroundImage!),
                            fit: BoxFit.cover,
                            alignment: bgAlignment,
                          ),
                    border: borderColor != null && borderWidth > 0
                        ? Border.all(color: borderColor, width: borderWidth * pt)
                        : null,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final el in elements)
                        _CanvasElement(
                          key: ValueKey(el.s('id')),
                          element: el,
                          ppi: ppi,
                          cardWidth: cardW,
                          cardHeight: cardH,
                          selected: el.s('id') == selectedId,
                          editable: editable,
                          sampleValues: resolvedSampleValues,
                          onSelect: () => onSelect(el.s('id')),
                          onChange: (patch) => onChange(el.s('id'), patch),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drag-to-reposition the background image - tracks a 0-100
/// background-position percentage over the card's full on-screen pixel
/// size. Deliberately a `GestureDetector` (onTap + onPanStart/Update),
/// NOT a raw `Listener`: a plain `Listener` receives every raw pointer
/// event in its hit-test area unconditionally, so an ancestor Listener
/// here would ALSO fire while dragging a child `_CanvasElement` below
/// (which claims the gesture via its own `EagerGestureRecognizer` - see
/// `_draggable`). A `GestureDetector`'s recognizers instead properly
/// compete in Flutter's real gesture arena, where an `EagerGestureRecognizer`
/// anywhere in the same hit-test path always wins outright regardless of
/// recognizer type - exactly like today's outer
/// `GestureDetector(onTap: () => onSelect(null))` already coexists
/// correctly with element dragging, just extended here with a pan
/// recognizer for the background-only case. [active] false (no
/// background image, not editable, or the caller didn't want
/// repositioning) omits the pan recognizers entirely, leaving a plain
/// tap-to-deselect area - byte-for-byte the prior behavior. */
class _BackgroundDragLayer extends StatefulWidget {
  const _BackgroundDragLayer({
    required this.child,
    required this.active,
    required this.posX,
    required this.posY,
    required this.cardPxWidth,
    required this.cardPxHeight,
    required this.onPositionChanged,
    required this.onTapDeselect,
  });
  final Widget child;
  final bool active;
  final double posX;
  final double posY;
  final double cardPxWidth;
  final double cardPxHeight;
  final void Function(double x, double y) onPositionChanged;
  final VoidCallback onTapDeselect;

  @override
  State<_BackgroundDragLayer> createState() => _BackgroundDragLayerState();
}

class _BackgroundDragLayerState extends State<_BackgroundDragLayer> {
  double _x = 50;
  double _y = 50;

  void _onPanStart(DragStartDetails d) {
    _x = widget.posX;
    _y = widget.posY;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // Clamped to [0,100] so the image (BoxFit.cover - Flutter's
    // equivalent of CSS background-size:cover) can never be dragged far
    // enough to expose blank space inside the card, same clamp
    // id-card-designer.tsx's clampBgPercent enforces on the web side.
    _x = (_x + d.delta.dx / widget.cardPxWidth * 100).clamp(0.0, 100.0);
    _y = (_y + d.delta.dy / widget.cardPxHeight * 100).clamp(0.0, 100.0);
    widget.onPositionChanged(_x, _y);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTapDeselect,
      onPanStart: widget.active ? _onPanStart : null,
      onPanUpdate: widget.active ? _onPanUpdate : null,
      child: widget.child,
    );
  }
}

class _CanvasElement extends StatefulWidget {
  const _CanvasElement({
    super.key,
    required this.element,
    required this.ppi,
    required this.cardWidth,
    required this.cardHeight,
    required this.selected,
    required this.editable,
    required this.sampleValues,
    required this.onSelect,
    required this.onChange,
  });

  final Json element;
  final double ppi;
  final double cardWidth;
  final double cardHeight;
  final bool selected;
  final bool editable;
  final Map<String, String> sampleValues;
  final VoidCallback onSelect;
  final ValueChanged<Map<String, Object?>> onChange;

  @override
  State<_CanvasElement> createState() => _CanvasElementState();
}

class _CanvasElementState extends State<_CanvasElement> {
  Offset? _start;
  Json? _origin;

  static final _eager = <Type, GestureRecognizerFactory>{
    EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
      EagerGestureRecognizer.new,
      (_) {},
    ),
  };

  void _begin(PointerDownEvent e) {
    _start = e.position;
    _origin = Map.of(widget.element);
  }

  void _move(PointerMoveEvent e, {required bool resize}) {
    final start = _start;
    final origin = _origin;
    if (start == null || origin == null) return;
    final dx = (e.position.dx - start.dx) / widget.ppi;
    final dy = (e.position.dy - start.dy) / widget.ppi;
    final moved = {
      ...origin,
      if (resize) 'width': origin.d('width') + dx else 'x': origin.d('x') + dx,
      if (resize) 'height': origin.d('height') + dy else 'y': origin.d('y') + dy,
    };
    final c = clampElement(moved, widget.cardWidth, widget.cardHeight);
    widget.onChange(resize ? {'width': c['width'], 'height': c['height']} : {'x': c['x'], 'y': c['y']});
  }

  void _end(PointerEvent _) {
    _start = null;
    _origin = null;
  }

  /// While an element is selected, touching it claims the gesture outright
  /// (so the page doesn't scroll) and the raw pointer moves drag it.
  Widget _draggable({required Widget child, required bool resize}) => RawGestureDetector(
        gestures: _eager,
        behavior: HitTestBehavior.opaque,
        child: Listener(
          onPointerDown: _begin,
          onPointerMove: (e) => _move(e, resize: resize),
          onPointerUp: _end,
          onPointerCancel: _end,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final el = widget.element;
    final ppi = widget.ppi;
    final w = el.d('width') * ppi;
    final h = el.d('height') * ppi;
    final body = CustomPaint(
      foregroundPainter: _OutlinePainter(selected: widget.selected),
      child: SizedBox(
        width: w,
        height: h,
        child: ElementPreview(element: el, ppi: ppi, sampleValues: widget.sampleValues),
      ),
    );
    final canDrag = widget.selected && widget.editable;
    return Positioned(
      left: el.d('x') * ppi,
      top: el.d('y') * ppi,
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          canDrag
              ? _draggable(resize: false, child: body)
              : GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onSelect, child: body),
          if (canDrag)
            // The web's 10px handle straddles the corner; the touch target
            // around it is bigger, but only the part inside the element can
            // receive hits.
            Positioned(
              right: -6,
              bottom: -6,
              width: 24,
              height: 24,
              child: _draggable(
                resize: true,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 1, bottom: 1),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `outline: 1.5px solid #2563eb` when selected, otherwise
/// `1px dashed rgba(100,116,139,0.4)`, both offset 1px.
class _OutlinePainter extends CustomPainter {
  _OutlinePainter({required this.selected});
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(selected ? 1.75 : 1.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.5 : 1
      ..color = selected ? const Color(0xFF2563EB) : const Color(0x6664748B);
    if (selected) {
      canvas.drawRect(rect, paint);
      return;
    }
    final path = Path()..addRect(rect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) => old.selected != selected;
}

/// The designer's ElementPreview: a field renders "{PrintLabel}: {sample}"
/// (or just the sample with the label off), custom text its content, and
/// photo/logo/QR a grey placeholder box.
class ElementPreview extends StatelessWidget {
  const ElementPreview({super.key, required this.element, required this.ppi, this.sampleValues});
  final Json element;
  final double ppi;
  // Falls back to the hardcoded defaults when the caller doesn't pass the
  // designer's live (possibly-edited) "Preview Data" map.
  final Map<String, String>? sampleValues;

  @override
  Widget build(BuildContext context) {
    final el = element;
    final pt = ppi / 72;
    final cssPx = ppi / 96;
    final kind = el.s('kind');
    final borderColor = hexColor(el.sn('borderColor'));
    final borderWidth = el.d('borderWidth');
    final border = borderColor != null && borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth * pt) : null;
    final radius = el.b('circular')
        ? BorderRadius.all(Radius.elliptical(el.d('width') * ppi / 2, el.d('height') * ppi / 2))
        : null;

    if (kind == 'field' || kind == 'static_text') {
      final values = sampleValues ?? idCardSampleValueDefaults;
      String text;
      if (kind == 'field') {
        final key = el.sn('fieldKey');
        if (key == null) return const SizedBox.shrink();
        final value = values[key] ?? '';
        text = el.at('showLabel') == false ? value : '${_printLabels[key] ?? key}: $value';
      } else {
        text = el.s('content');
      }
      final align = el.s('textAlign', 'left');
      final family = el.s('fontFamily', 'Arial');
      // `wordWrap`: wraps onto multiple lines instead of the default
      // single-line clip - mirrors id-card-designer.tsx's
      // elementPreviewStyle() (`whiteSpace: "normal"` vs `"nowrap"`) and
      // layout-render.ts's textStyle() (`white-space:normal` vs `nowrap`).
      // The surrounding Container still clips (Clip.hardEdge) with a fixed
      // height, so text that's still too tall clips vertically either way.
      final wordWrap = el.b('wordWrap');
      return Container(
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.symmetric(horizontal: 2 * cssPx),
        alignment: align == 'center'
            ? Alignment.center
            : align == 'right'
                ? Alignment.centerRight
                : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: hexColor(el.sn('backgroundColor')),
          border: border,
          borderRadius: radius,
        ),
        child: Text(
          text,
          maxLines: wordWrap ? null : 1,
          softWrap: wordWrap,
          overflow: TextOverflow.clip,
          textAlign: align == 'center'
              ? TextAlign.center
              : align == 'right'
                  ? TextAlign.right
                  : TextAlign.left,
          style: TextStyle(
            fontFamily: family,
            fontFamilyFallback: _fontFallbacks[family] ?? _fontFallbacks['Arial'],
            fontSize: (el.dN('fontSize') ?? 7) * pt,
            fontWeight: el.i('fontWeight', 400) >= 700 ? FontWeight.w700 : FontWeight.w400,
            color: hexColor(el.sn('color')) ?? const Color(0xFF0F172A),
            height: 1.15,
            letterSpacing: 0,
          ),
        ),
      );
    }

    final label = kind == 'photo' ? 'Photo' : (kind == 'logo' ? 'Logo' : 'QR');
    return Container(
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hexColor(el.sn('backgroundColor')) ?? const Color(0xFFE2E8F0),
        border: border,
        borderRadius: radius,
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(fontFamily: 'Arial', fontSize: 7 * cssPx, color: const Color(0xFF94A3B8), height: 1.1),
      ),
    );
  }
}
