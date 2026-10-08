import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'json.dart';

/// One drawer link, as built by the backend from the web sidebar's rules.
class NavLink {
  NavLink({required this.href, required this.label, required this.icon, this.group});
  final String href;
  final String label;
  final String icon;
  final String? group;

  factory NavLink.fromJson(Json j) =>
      NavLink(href: j.s('href'), label: j.s('label'), icon: j.s('icon'), group: j.sn('group'));
}

/// The signed-in user and everything the app chrome needs (GET /me).
class Me {
  Me(this.raw);
  final Json raw;

  String get userId => raw.s('user.id');
  String get name => raw.s('user.name');
  String get email => raw.s('user.email');
  String get role => raw.s('user.role');
  bool get isHr => role == 'HR_ADMIN' || role == 'TENANT_ADMIN';
  bool get isTenantAdmin => role == 'TENANT_ADMIN';
  String get homePath => raw.s('homePath', '/leave');
  List<String> get modules => raw.list<String>('modules');
  bool hasModule(String key) => modules.contains(key);
  bool get hasLogo => raw.b('company.hasLogo');
  String get companyName => raw.s('company.name', 'TeamSavy');
  Json? get employee => raw.mN('employee');
  bool get mustChangePassword => raw.b('mustChangePassword');
  bool get needsOnboardingDocuments => raw.b('needsOnboardingDocuments');
  List<NavLink> get nav => raw.l('nav').map(NavLink.fromJson).toList();
  bool canSee(String href) => nav.any((l) => l.href == href);

  String get roleLabel =>
      const {
        'PLATFORM_ADMIN': 'Platform Admin',
        'PLATFORM_SUPPORT': 'Platform Support',
        'TENANT_ADMIN': 'Tenant Admin',
        'HR_ADMIN': 'HR Admin',
        'EMPLOYEE': 'Employee',
      }[role] ??
      role;
}

enum AuthStatus { unknown, signedOut, signedIn }

class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'session_token';
  static const _themeKey = 'theme';

  AuthStatus status = AuthStatus.unknown;
  Me? me;

  /// Set when the backend says the account is suspended (/suspended).
  String? suspendedReason;

  ThemeMode themeMode = ThemeMode.system;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_themeKey);
    themeMode =
        theme == 'dark'
            ? ThemeMode.dark
            : theme == 'light'
            ? ThemeMode.light
            : ThemeMode.system;

    api.onSessionProblem = _onSessionProblem;
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (_) {
      token = null;
    }
    if (token == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    api.token = token;
    try {
      await refreshMe();
      status = AuthStatus.signedIn;
    } on ApiException catch (e) {
      // Offline at launch: keep the token, show the app; screens will show
      // their own retry state. Only a real auth failure signs out.
      if (e.status == 401 || e.code == 'platform_account') {
        await _clear();
      } else if (e.code == 'suspended') {
        status = AuthStatus.signedIn;
      } else {
        status = AuthStatus.signedIn;
      }
    }
    notifyListeners();
  }

  Future<void> refreshMe() async {
    final json = await api.getJson('/me');
    me = Me(json);
    suspendedReason = null;
    notifyListeners();
  }

  /// Stores a freshly issued token and loads the profile.
  Future<void> signIn(String token) async {
    api.token = token;
    await _storage.write(key: _tokenKey, value: token);
    await refreshMe();
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clear();
    notifyListeners();
  }

  Future<void> _clear() async {
    api.token = null;
    me = null;
    status = AuthStatus.signedOut;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  void _onSessionProblem(ApiException e) {
    if (e.status == 401) {
      if (status == AuthStatus.signedIn) {
        _clear().then((_) => notifyListeners());
      }
    } else if (e.code == 'suspended') {
      suspendedReason = (e.redirect ?? '').contains('reason=trial') ? 'trial' : 'suspended';
      notifyListeners();
    } else if (e.code == 'must_change_password' || e.code == 'onboarding_documents') {
      refreshMe().catchError((_) {});
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final session = Session.instance;

/// Bumped after any successful mutation so every visible screen reloads -
/// the app's equivalent of the web's revalidatePath().
class RefreshBus extends ValueNotifier<int> {
  RefreshBus._() : super(0);
  static final RefreshBus instance = RefreshBus._();
  void bump() => value++;
}

final refreshBus = RefreshBus.instance;
