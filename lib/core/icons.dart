import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The web uses lucide-react; the app uses the same lucide set, so every
/// icon is the same glyph. Nav links from the API name their icon in
/// lucide's kebab-case.
IconData lucide(String name) => _byName[name] ?? LucideIcons.circle;

final Map<String, IconData> _byName = {
  'layout-dashboard': LucideIcons.layoutDashboard,
  'file-signature': LucideIcons.fileSignature,
  'users': LucideIcons.users,
  'user-minus': LucideIcons.userMinus,
  'megaphone': LucideIcons.megaphone,
  'clipboard-list': LucideIcons.clipboardList,
  'bar-chart-3': LucideIcons.barChart3,
  'building-2': LucideIcons.building2,
  'sliders-horizontal': LucideIcons.slidersHorizontal,
  'id-card': LucideIcons.idCard,
  'fingerprint': LucideIcons.fingerprint,
  'alert-triangle': LucideIcons.alertTriangle,
  'wrench': LucideIcons.wrench,
  'map-pin': LucideIcons.mapPin,
  'clock': LucideIcons.clock,
  'cpu': LucideIcons.cpu,
  'banknote': LucideIcons.banknote,
  'calculator': LucideIcons.calculator,
  'scroll-text': LucideIcons.scrollText,
  'wallet': LucideIcons.wallet,
  'indian-rupee': LucideIcons.indianRupee,
  'shield-check': LucideIcons.shieldCheck,
  'receipt': LucideIcons.receipt,
  'landmark': LucideIcons.landmark,
  'file-spreadsheet': LucideIcons.fileSpreadsheet,
  'zap': LucideIcons.zap,
  'history': LucideIcons.history,
  'briefcase': LucideIcons.briefcase,
  'list-todo': LucideIcons.listTodo,
  'gauge': LucideIcons.gauge,
  'message-circle': LucideIcons.messageCircle,
  'calendar-days': LucideIcons.calendarDays,
  'file-text': LucideIcons.fileText,
  'check-circle-2': LucideIcons.checkCircle2,
};
