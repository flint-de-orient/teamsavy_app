import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../shell/logo.dart';
import '../../shell/app_shell.dart' show ThemeToggle;
import '../../widgets/ts.dart';

/// components/auth/AuthShell.tsx for phones. The web's ink brand panel
/// (hidden below lg) becomes the hero at the top - same ink colour, the
/// same two soft glows and the same headline with its gradient-soft
/// "all in one place." - and the form sits below on the page background.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.compactHero = false,
  });
  final String title;
  final String description;
  final Widget child;
  final bool compactHero;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final top = MediaQuery.of(context).padding.top;
    // Light status-bar icons over the ink hero, in both themes.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: p.background,
        body: ListView(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Container(
              decoration: BoxDecoration(
                color: p.brandPanel,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.8, -1),
                          radius: 1.1,
                          colors: [const Color(0xFFD5E3FB).withValues(alpha: 0.16), const Color(0x00D5E3FB)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(1, 1),
                          radius: 0.9,
                          colors: [const Color(0xFFF9C3A8).withValues(alpha: 0.16), const Color(0x00F9C3A8)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(28, top + 20, 20, compactHero ? 28 : 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onLongPress: () => _serverDialog(context),
                              child: const TeamSavyLogo(height: 26, forceWhite: true),
                            ),
                            const Spacer(),
                            Theme(data: Theme.of(context), child: const _HeroThemeToggle()),
                          ],
                        ),
                        if (!compactHero) ...[
                          const SizedBox(height: 40),
                          RichText(
                            text: TextSpan(
                              style: tx(
                                34,
                                weight: FontWeight.w500,
                                color: p.brandPanelFg,
                                height: 1.05,
                                tracking: -0.02,
                              ),
                              children: [
                                const TextSpan(text: 'Appointment letters, employees & leave — '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (r) => TsPalette.light.gradientSoft.createShader(r),
                                    child: Text(
                                      'all in one place.',
                                      style: tx(
                                        34,
                                        weight: FontWeight.w500,
                                        color: Colors.white,
                                        height: 1.05,
                                        tracking: -0.02,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'The HR system for generating offer & appointment letters, managing staff records, and running leave approvals end to end.',
                            style: tx(14, color: p.brandPanelMuted, height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: tx(24, weight: FontWeight.w800, color: p.foreground, tracking: kTight)),
                  const SizedBox(height: 6),
                  Text(description, style: tx(14, color: p.muted)),
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _serverDialog(BuildContext context) async {
    final controller = TextEditingController(text: AppConfig.baseUrl);
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Server'),
            content: TsInput(
              controller: controller,
              label: 'TeamSavy server URL',
              hint: 'For testing against another deployment.',
              keyboardType: TextInputType.url,
            ),
            actions: [
              TsButton.ghost(label: 'Cancel', compact: true, onPressed: () => Navigator.pop(ctx, false)),
              TsButton(label: 'Save', compact: true, onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
    );
    if (saved == true) {
      await AppConfig.setBaseUrl(controller.text);
      if (context.mounted) toast(context, 'Server set to ${AppConfig.baseUrl}');
    }
  }
}

class _HeroThemeToggle extends StatelessWidget {
  const _HeroThemeToggle();

  @override
  Widget build(BuildContext context) {
    final dark = Ts.of(context).dark;
    return GestureDetector(
      onTap: () => session.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Ts.rLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(dark ? LucideIcons.sun : LucideIcons.moon, size: 16, color: const Color(0xFFC7C9DE)),
      ),
    );
  }
}

/// The plain centered layout of /change-password and /suspended (ThemeToggle
/// top-right, a narrow column in the middle of the page).
class PlainAuthPage extends StatelessWidget {
  const PlainAuthPage({super.key, required this.child, this.showBack = false});
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 384), child: child),
              ),
            ),
            Positioned(top: 12, right: 16, child: const ThemeToggle()),
            if (showBack)
              Positioned(
                top: 12,
                left: 12,
                child: TsIconButton(icon: LucideIcons.arrowLeft, onTap: () => context.pop()),
              ),
          ],
        ),
      ),
    );
  }
}
