import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/memo.dart';
import '../../../domain/entities/workspace.dart';

class RemoteMemoDto {
  RemoteMemoDto({
    required this.name,
    required this.content,
    required this.visibility,
    required this.pinned,
    required this.archived,
    this.createTime,
    this.updateTime,
    this.creator,
  });

  final String name;
  final String content;
  final MemoVisibility visibility;
  final bool pinned;
  final bool archived;
  final DateTime? createTime;
  final DateTime? updateTime;
  final String? creator;

  factory RemoteMemoDto.fromJson(Map<String, dynamic> json) {
    final visibilityRaw =
        (json['visibility'] as String? ?? 'PRIVATE').toUpperCase();
    final stateRaw =
        (json['state'] as String? ?? json['rowStatus'] as String? ?? '')
            .toUpperCase();
    final pinned = json['pinned'] == true || json['pinned'] == 1;

    return RemoteMemoDto(
      name: json['name'] as String? ??
          (json['uid'] != null ? 'memos/${json['uid']}' : ''),
      content: json['content'] as String? ?? '',
      visibility: switch (visibilityRaw) {
        'PUBLIC' => MemoVisibility.public,
        'PROTECTED' => MemoVisibility.protected,
        _ => MemoVisibility.private,
      },
      pinned: pinned,
      archived: stateRaw.contains('ARCHIVED') || stateRaw == 'ARCHIVED',
      createTime: _parseTime(json['createTime'] ?? json['createdTs']),
      updateTime: _parseTime(json['updateTime'] ?? json['updatedTs']),
      creator: json['creator'] as String? ?? json['creatorId']?.toString(),
    );
  }

  static DateTime? _parseTime(Object? value) {
    if (value == null) return null;
    if (value is int) {
      if (value > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
          .toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

class MemosSignInResult {
  const MemosSignInResult({
    required this.accessToken,
    this.expiresAt,
    this.username,
  });

  final String accessToken;
  final DateTime? expiresAt;
  final String? username;
}

class MemosApiClient {
  MemosApiClient({
    required this.baseUrl,
    this.accessToken,
    this.allowInsecureTls = false,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBase(baseUrl),
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                // Keep cookies for refresh-token flows when server sets them.
                // Access token is still primary for Authorization header.
                validateStatus: (s) => s != null && s < 500,
              ),
            ) {
    if (accessToken != null && accessToken!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (allowInsecureTls) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) {
          appLogger.w(
            'HTTP ${e.requestOptions.method} ${e.requestOptions.path} '
            '-> ${e.response?.statusCode}',
          );
          handler.next(e);
        },
      ),
    );
  }

  final String baseUrl;
  final String? accessToken;
  final bool allowInsecureTls;
  final Dio _dio;

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  factory MemosApiClient.forWorkspace(
    Workspace workspace, {
    required String? token,
  }) {
    return MemosApiClient(
      baseUrl: workspace.serverBaseUrl ?? '',
      accessToken: token,
      allowInsecureTls: workspace.allowInsecureTls,
    );
  }

  /// Current Memos API v1 SignIn body shape:
  /// `{ "passwordCredentials": { "username", "password" } }`
  /// Response: `{ "accessToken" | "access_token", "user": {...} }`
  Future<MemosSignInResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final attempts = <MapEntry<String, Map<String, dynamic>>>[
        MapEntry('/api/v1/auth/signin', {
          'passwordCredentials': {
            'username': username,
            'password': password,
          },
        }),
        MapEntry('/api/v1/auth/signin', {
          'password_credentials': {
            'username': username,
            'password': password,
          },
        }),
        MapEntry('/api/v1/auth/signin', {
          'username': username,
          'password': password,
        }),
        MapEntry('/api/v1/auth/login', {
          'username': username,
          'password': password,
        }),
        // Very old memos REST
        MapEntry('/api/v1/auth/status', {
          'username': username,
          'password': password,
        }),
      ];

      DioException? lastNetwork;
      Object? lastBody;
      int? lastStatus;
      String? lastTransportHint;

      for (final attempt in attempts) {
        try {
          final res = await _dio.post<dynamic>(
            attempt.key,
            data: attempt.value,
            options: Options(
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              responseType: ResponseType.json,
              followRedirects: true,
              validateStatus: (s) => s != null && s < 500,
            ),
          );
          lastStatus = res.statusCode;
          lastBody = res.data;
          appLogger.i(
            'SignIn ${attempt.key} -> ${res.statusCode} '
            'bodyType=${res.data.runtimeType}',
          );
          if (res.statusCode != null &&
              res.statusCode! >= 200 &&
              res.statusCode! < 300) {
            final parsed = _parseSignInBody(res.data);
            if (parsed != null) return parsed;
            // 2xx but no token — log keys for diagnostics
            if (res.data is Map) {
              appLogger.w(
                'SignIn 2xx without token, keys=${(res.data as Map).keys.toList()}',
              );
            }
          }
          if (res.statusCode == 401 || res.statusCode == 403) {
            throw AuthFailure(
              _extractErrorMessage(res.data) ??
                  '用户名或密码错误 / 密码登录未启用',
            );
          }
        } on DioException catch (e) {
          lastNetwork = e;
          lastStatus = e.response?.statusCode;
          lastBody = e.response?.data;
          lastTransportHint = _transportHint(e);
          appLogger.w(
            'SignIn DioException type=${e.type} status=${e.response?.statusCode} '
            'msg=${e.message}',
          );
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.unknown && e.response == null) {
            // Network blocked (e.g. missing macOS network.client entitlement)
            // — no point trying alternate bodies.
            throw AuthFailure(
              '无法连接 Memos 服务器（${e.type.name}）。'
              '请确认：1) 地址可访问 2) 本机网络权限已开启 '
              '(macOS 需 com.apple.security.network.client)。'
              '${e.message != null ? ' 详情: ${e.message}' : ''}',
              cause: e,
            );
          }
          if (e.response?.statusCode == 404) continue;
          if (e.response?.statusCode == 400) continue;
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            throw AuthFailure(
              _extractErrorMessage(e.response?.data) ?? '登录被拒绝',
              cause: e,
            );
          }
        }
      }

      throw AuthFailure(
        '登录失败 (HTTP ${lastStatus ?? '无响应'}): '
        '${_extractErrorMessage(lastBody) ?? '响应中没有 accessToken'}。'
        '${lastTransportHint != null ? ' $lastTransportHint' : ''} '
        '也可在设置中用「Access Token」登录（Memos → Settings → Create Access Token）。',
        cause: lastNetwork,
      );
    } on AuthFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e, 'Login failed');
    }
  }

  String? _transportHint(DioException e) {
    if (e.response == null) {
      return '（请求未到达服务器，多为网络/证书/沙盒权限问题）';
    }
    return null;
  }

  MemosSignInResult? _parseSignInBody(Object? data) {
    if (data is String && data.trim().isNotEmpty) {
      // Some gateways return raw JWT string
      final t = data.trim();
      if (t.startsWith('eyJ') || t.startsWith('memos_')) {
        return MemosSignInResult(accessToken: t);
      }
      return null;
    }
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    // Nested wrappers used by some proxies
    final nested = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final token = (nested['accessToken'] ??
            nested['access_token'] ??
            nested['token'] ??
            map['accessToken'] ??
            map['access_token'] ??
            map['token'])
        ?.toString();
    if (token == null || token.isEmpty) return null;
    if (token.toLowerCase().startsWith('memos_session=')) return null;

    DateTime? expires;
    final exp = map['accessTokenExpiresAt'] ??
        map['access_token_expires_at'] ??
        map['expiresAt'];
    if (exp is String) expires = DateTime.tryParse(exp)?.toLocal();
    if (exp is Map && exp['seconds'] != null) {
      final sec = int.tryParse(exp['seconds'].toString());
      if (sec != null) {
        expires = DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true)
            .toLocal();
      }
    }

    String? username;
    final user = map['user'];
    if (user is Map) {
      username = (user['username'] ?? user['name'])?.toString();
    }

    return MemosSignInResult(
      accessToken: token,
      expiresAt: expires,
      username: username,
    );
  }

  String? _extractErrorMessage(Object? data) {
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      return (m['message'] ?? m['error'] ?? m['msg'])?.toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data!;
        if (data['user'] is Map) {
          return Map<String, dynamic>.from(data['user'] as Map);
        }
        return data;
      }
    } on DioException {
      // fall through
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
      if (res.statusCode == 200) return res.data ?? {};
    } on DioException {
      // fall through
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/user/me');
      return res.data ?? {};
    } on DioException catch (e2) {
      throw _mapDio(e2, 'Failed to load user');
    }
  }

  Future<({List<RemoteMemoDto> memos, String? nextPageToken})> listMemosPage({
    String? pageToken,
    int pageSize = 50,
    String? filter,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/memos',
        queryParameters: {
          'pageSize': pageSize,
          if (pageToken != null) 'pageToken': pageToken,
          if (filter != null) 'filter': filter,
        },
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        throw NetworkFailure(
          _extractErrorMessage(res.data) ?? 'Failed to list memos',
          statusCode: res.statusCode,
        );
      }
      final list = (res.data?['memos'] as List?) ?? const [];
      final memos = list
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => RemoteMemoDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList();
      final next = res.data?['nextPageToken'] as String?;
      return (memos: memos, nextPageToken: next);
    } on DioException catch (e) {
      throw _mapDio(e, 'Failed to list memos');
    }
  }

  Future<RemoteMemoDto> createMemo({
    required String content,
    required MemoVisibility visibility,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/memos',
        data: {
          'content': content,
          'visibility': visibility.name.toUpperCase(),
        },
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        throw NetworkFailure(
          _extractErrorMessage(res.data) ?? 'Failed to create memo',
          statusCode: res.statusCode,
        );
      }
      return RemoteMemoDto.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e, 'Failed to create memo');
    }
  }

  Future<RemoteMemoDto> updateMemo({
    required String name,
    required String content,
    required MemoVisibility visibility,
    required bool pinned,
    required bool archived,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/$name',
        data: {
          'memo': {
            'name': name,
            'content': content,
            'visibility': visibility.name.toUpperCase(),
            'pinned': pinned,
            'state': archived ? 'ARCHIVED' : 'NORMAL',
          },
          'updateMask': 'content,visibility,pinned,state',
        },
      );
      if (res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300) {
        return RemoteMemoDto.fromJson(res.data ?? {});
      }
    } on DioException {
      // try alternate
    }
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/$name',
        queryParameters: {
          'updateMask': 'content,visibility,pinned,state',
        },
        data: {
          'name': name,
          'content': content,
          'visibility': visibility.name.toUpperCase(),
          'pinned': pinned,
          'state': archived ? 'ARCHIVED' : 'NORMAL',
        },
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        throw NetworkFailure(
          _extractErrorMessage(res.data) ?? 'Failed to update memo',
          statusCode: res.statusCode,
        );
      }
      return RemoteMemoDto.fromJson(res.data ?? {});
    } on DioException catch (e2) {
      throw _mapDio(e2, 'Failed to update memo');
    }
  }

  Future<void> deleteMemo(String name) async {
    try {
      final res = await _dio.delete<void>('/api/v1/$name');
      if (res.statusCode == 404) return;
      if (res.statusCode != null && res.statusCode! >= 400) {
        throw NetworkFailure(
          'Failed to delete memo',
          statusCode: res.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw _mapDio(e, 'Failed to delete memo');
    }
  }

  AppFailure _mapDio(DioException e, String fallback) {
    final code = e.response?.statusCode;
    final msg = _extractErrorMessage(e.response?.data) ?? fallback;
    if (code == 401) {
      return AuthFailure(msg, cause: e);
    }
    return NetworkFailure(msg, cause: e, statusCode: code);
  }
}
