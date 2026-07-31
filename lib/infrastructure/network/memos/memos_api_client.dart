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
    final stateRaw = (json['state'] as String? ?? json['rowStatus'] as String? ?? '')
        .toUpperCase();
    final pinned = json['pinned'] == true ||
        json['pinned'] == 1 ||
        (json['displayTime'] != null && json['pinned'] == true);

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

  Map<String, dynamic> toCreateBody() {
    return {
      'content': content,
      'visibility': visibility.name.toUpperCase(),
    };
  }

  Map<String, dynamic> toUpdateBody() {
    return {
      'name': name,
      'content': content,
      'visibility': visibility.name.toUpperCase(),
      'pinned': pinned,
      if (archived) 'state': 'ARCHIVED' else 'state': 'NORMAL',
    };
  }

  static DateTime? _parseTime(Object? value) {
    if (value == null) return null;
    if (value is int) {
      // seconds or millis
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

  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      // Try modern auth endpoint variants.
      final attempts = <Future<Response<dynamic>> Function()>[
        () => _dio.post(
              '/api/v1/auth/signin',
              data: {
                'username': username,
                'password': password,
              },
            ),
        () => _dio.post(
              '/api/v1/users/sessions',
              data: {
                'username': username,
                'password': password,
              },
            ),
        () => _dio.post(
              '/api/v1/auth/login',
              data: {
                'username': username,
                'password': password,
              },
            ),
      ];

      DioException? last;
      for (final attempt in attempts) {
        try {
          final res = await attempt();
          final data = res.data;
          if (data is Map) {
            final token = data['accessToken'] as String? ??
                data['token'] as String? ??
                data['access_token'] as String?;
            if (token != null && token.isNotEmpty) return token;
          }
          // Cookie session fallback: some instances set cookie only.
          final setCookie = res.headers['set-cookie'];
          if (setCookie != null && setCookie.isNotEmpty) {
            return setCookie.join(';');
          }
        } on DioException catch (e) {
          last = e;
          if (e.response?.statusCode == 404) continue;
        }
      }
      throw AuthFailure(
        'Login failed',
        cause: last,
      );
    } on DioException catch (e) {
      throw _mapDio(e, 'Login failed');
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
      return res.data ?? {};
    } on DioException {
      // Fallback older path
      try {
        final res = await _dio.get<Map<String, dynamic>>('/api/v1/user/me');
        return res.data ?? {};
      } on DioException catch (e2) {
        throw _mapDio(e2, 'Failed to load user');
      }
    }
  }

  Future<List<RemoteMemoDto>> listMemos({
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
      final list = (res.data?['memos'] as List?) ?? const [];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => RemoteMemoDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e, 'Failed to list memos');
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
      return RemoteMemoDto.fromJson(res.data ?? {});
    } on DioException {
      // Alternate body shape
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
        return RemoteMemoDto.fromJson(res.data ?? {});
      } on DioException catch (e2) {
        throw _mapDio(e2, 'Failed to update memo');
      }
    }
  }

  Future<void> deleteMemo(String name) async {
    try {
      await _dio.delete<void>('/api/v1/$name');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw _mapDio(e, 'Failed to delete memo');
    }
  }

  AppFailure _mapDio(DioException e, String fallback) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String msg = fallback;
    if (data is Map) {
      final map = Map<Object?, Object?>.from(data);
      msg = (map['message'] ?? map['error'] ?? fallback).toString();
    }
    if (code == 401) {
      return AuthFailure(msg, cause: e);
    }
    return NetworkFailure(msg, cause: e, statusCode: code);
  }
}
