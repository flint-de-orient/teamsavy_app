import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'json.dart';

/// An API failure as the user should see it. [code] mirrors the backend's
/// machine code (`unauthenticated`, `forbidden`, `suspended`,
/// `must_change_password`, `not_found`, ...).
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code, this.redirect});
  final int status;
  final String message;
  final String? code;
  final String? redirect;

  bool get isForbidden => status == 403 && code == 'forbidden';
  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

/// What a server action returned. The web actions answer with
/// `{ error }`, `{ success, message? , ...extra }`, nothing (void), or a
/// redirect - this folds all four into one shape.
class ActionResult {
  ActionResult({this.data, this.redirect, this.failure});

  /// The action's own return value (often `{error}` / `{success,message}`).
  final Json? data;

  /// Where the web app would navigate after this action, if anywhere.
  final String? redirect;

  /// Transport-level failure (network, 401, 500...).
  final String? failure;

  String? get error => failure ?? data?.sn('error');
  bool get ok => error == null;
  String? get message => data?.sn('message');
  String? get warning => data?.sn('warning');
}

/// A file picked on the device, to send as multipart.
class UploadFile {
  UploadFile(this.path, {this.filename, this.contentType});
  final String path;
  final String? filename;
  final String? contentType;
}

typedef SessionExpiredHandler = void Function(ApiException e);

class Api {
  Api._();
  static final Api instance = Api._();

  String? token;

  /// Called for 401s and account-state 403s (suspended, must change
  /// password) so the router can move to the right screen.
  SessionExpiredHandler? onSessionProblem;

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 90),
      validateStatus: (_) => true,
      responseType: ResponseType.json,
    ),
  );

  String get host => AppConfig.baseUrl;
  String get mobileBase => '$host/api/mobile/v1';

  Map<String, String> get authHeaders => {if (token != null) 'Authorization': 'Bearer $token'};

  ApiException _error(Response res) {
    final body = res.data;
    final json = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    final e = ApiException(
      res.statusCode ?? 0,
      json.sn('error') ?? 'Something went wrong (${res.statusCode}).',
      code: json.sn('code'),
      redirect: json.sn('redirect'),
    );
    if (e.status == 401 ||
        (e.status == 403 &&
            (e.code == 'suspended' || e.code == 'must_change_password' || e.code == 'onboarding_documents'))) {
      onSessionProblem?.call(e);
    }
    return e;
  }

  ApiException _network(Object err) {
    if (err is DioException) {
      switch (err.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return ApiException(0, 'The server took too long to respond. Try again.', code: 'timeout');
        default:
          return ApiException(0, "Couldn't reach the server. Check your internet connection.", code: 'network');
      }
    }
    return ApiException(0, err.toString(), code: 'network');
  }

  /// GET `/api/mobile/v1/{path}`. Null/empty query values are dropped.
  Future<dynamic> get(String path, {Map<String, Object?>? query}) async {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    Response res;
    try {
      res = await _dio.get('$mobileBase$path', queryParameters: q, options: Options(headers: authHeaders));
    } catch (e) {
      throw _network(e);
    }
    if ((res.statusCode ?? 0) >= 400) throw _error(res);
    return res.data;
  }

  Future<Json> getJson(String path, {Map<String, Object?>? query}) async => asJson(await get(path, query: query));

  /// POST to a raw mobile endpoint (auth routes).
  Future<Json> post(String path, Map<String, Object?> body) async {
    Response res;
    try {
      res = await _dio.post('$mobileBase$path', data: body, options: Options(headers: authHeaders));
    } catch (e) {
      throw _network(e);
    }
    if ((res.statusCode ?? 0) >= 400) throw _error(res);
    return asJson(res.data);
  }

  /// Runs a web server action through POST `/api/mobile/v1/actions/{name}`.
  ///
  /// [fields] are the form fields the web form posts (lists become repeated
  /// fields, bools become "true"/"false", nulls are skipped). [args] are the
  /// ids the web page binds in front of the action. [files] are uploads.
  /// Never throws - failures come back as [ActionResult.failure].
  Future<ActionResult> action(
    String name, {
    Map<String, Object?> fields = const {},
    List<Object> args = const [],
    Map<String, UploadFile?> files = const {},
  }) async {
    final form = FormData();
    fields.forEach((k, v) {
      if (v == null) return;
      final values = v is Iterable ? v : [v];
      for (final item in values) {
        if (item == null) continue;
        form.fields.add(MapEntry(k, item.toString()));
      }
    });
    if (args.isNotEmpty) {
      form.fields.add(MapEntry('__args', '[${args.map((a) => '"${a.toString().replaceAll('"', r'\"')}"').join(',')}]'));
    }
    for (final entry in files.entries) {
      final f = entry.value;
      if (f == null) continue;
      form.files.add(
        MapEntry(
          entry.key,
          await MultipartFile.fromFile(
            f.path,
            filename: f.filename ?? f.path.split(Platform.pathSeparator).last,
            contentType: f.contentType == null ? null : DioMediaType.parse(f.contentType!),
          ),
        ),
      );
    }
    Response res;
    try {
      res = await _dio.post('$mobileBase/actions/$name', data: form, options: Options(headers: authHeaders));
    } catch (e) {
      return ActionResult(failure: _network(e).message);
    }
    if ((res.statusCode ?? 0) >= 400) {
      return ActionResult(failure: _error(res).message);
    }
    final body = asJson(res.data);
    final result = body['result'];
    return ActionResult(data: result is Map ? result.cast<String, dynamic>() : null, redirect: body.sn('redirect'));
  }

  /// Downloads one of the web app's file routes (PDFs, CSVs, receipts) with
  /// the session token and opens it with the device's viewer.
  /// [path] is the site path, e.g. `/api/payroll/payslips/<id>/pdf`.
  Future<void> openFile(String path, {String? filename}) async {
    final dir = await getTemporaryDirectory();
    final uri = Uri.parse('$host$path');
    final name = filename ?? _filenameFor(uri);
    final target = '${dir.path}${Platform.pathSeparator}$name';
    Response res;
    try {
      res = await _dio.get(uri.toString(), options: Options(headers: authHeaders, responseType: ResponseType.bytes));
    } catch (e) {
      throw _network(e);
    }
    if ((res.statusCode ?? 0) >= 400) {
      // The file routes answer failures with `{ error }` JSON - surface it.
      String? message;
      try {
        final body = jsonDecode(utf8.decode(res.data as List<int>));
        if (body is Map && body['error'] is String) message = body['error'] as String;
      } catch (_) {}
      throw ApiException(res.statusCode ?? 0, message ?? "Couldn't download this file (${res.statusCode}).");
    }
    final disposition = res.headers.value('content-disposition');
    final fromHeader = disposition == null ? null : RegExp(r'filename="?([^";]+)"?').firstMatch(disposition)?.group(1);
    final file = File(fromHeader != null ? '${dir.path}${Platform.pathSeparator}$fromHeader' : target);
    await file.writeAsBytes(res.data as List<int>);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && kDebugMode) {
      debugPrint('open file: ${result.message}');
    }
  }

  /// Raw bytes of a protected image (logo, selfie, receipt previews).
  Future<Uint8List?> bytes(String path) async {
    try {
      final res = await _dio.get(
        '$host$path',
        options: Options(headers: authHeaders, responseType: ResponseType.bytes),
      );
      if ((res.statusCode ?? 0) >= 400) return null;
      return Uint8List.fromList(res.data as List<int>);
    } catch (_) {
      return null;
    }
  }

  String _filenameFor(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final last = segments.isEmpty ? 'file' : segments.last;
    final ext = last.contains('.') ? '' : (last == 'csv' ? '.csv' : '.pdf');
    final stem = segments.length >= 2 ? '${segments[segments.length - 2]}-$last' : last;
    return '$stem$ext';
  }
}

final api = Api.instance;
