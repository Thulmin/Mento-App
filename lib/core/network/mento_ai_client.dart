// Sends privacy-minimised, authenticated requests to Mento's secure AI proxy.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

enum AiEndpoint { studyPlan, replan, taskBreakdown, recommendation, chat }

extension on AiEndpoint {
  String get path => switch (this) {
    AiEndpoint.studyPlan => '/v1/ai/study-plan',
    AiEndpoint.replan => '/v1/ai/replan',
    AiEndpoint.taskBreakdown => '/v1/ai/task-breakdown',
    AiEndpoint.recommendation => '/v1/ai/recommendation',
    AiEndpoint.chat => '/v1/ai/chat',
  };
}

class AiClientFailure implements Exception {
  const AiClientFailure(this.message, {this.code, this.retryAfter});

  final String message;
  final String? code;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

abstract interface class MentoAiGateway {
  Future<Map<String, dynamic>> post(
    AiEndpoint endpoint,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  });
}

class MentoAiClient implements MentoAiGateway {
  MentoAiClient({
    Dio? dio,
    FirebaseAuth? auth,
    FirebaseAppCheck? appCheck,
    String? baseUrl,
  }) : _dio = dio ?? Dio(),
       _auth = auth ?? FirebaseAuth.instance,
       _appCheck = appCheck ?? FirebaseAppCheck.instance,
       _baseUrl = baseUrl ?? AppConfig.workerBaseUrl;

  final Dio _dio;
  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;
  final String _baseUrl;
  static const _uuid = Uuid();

  @override
  Future<Map<String, dynamic>> post(
    AiEndpoint endpoint,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) async {
    final uri = _validatedUri(endpoint.path);
    final user = _auth.currentUser;
    if (user == null) {
      throw const AiClientFailure(
        'Sign in before using AI features.',
        code: 'unauthenticated',
      );
    }
    final requestId = _uuid.v4();
    // Remove fields that the planner does not need before data leaves the app.
    final safeInput = minimiseAiContext(input);
    try {
      var idToken = await _firebaseIdToken(user, forceRefresh: false);
      var appCheckToken = await _appCheckToken(forceRefresh: false);
      Response<Map<String, dynamic>> response;
      try {
        response = await _send(
          uri,
          safeInput,
          idToken: idToken,
          appCheckToken: appCheckToken,
          requestId: requestId,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) || error.response?.statusCode != 401) {
          rethrow;
        }
        // Retry once with fresh credentials only after the backend rejects the
        // cached session. This avoids a token-change event on every AI request.
        idToken = await _firebaseIdToken(user, forceRefresh: true);
        appCheckToken = await _appCheckToken(forceRefresh: true);
        response = await _send(
          uri,
          safeInput,
          idToken: idToken,
          appCheckToken: appCheckToken,
          requestId: requestId,
          cancelToken: cancelToken,
        );
      }
      final body = response.data;
      final data = body?['data'];
      if (data is! Map) {
        throw const AiClientFailure(
          'Mento received an invalid AI response. Nothing was saved.',
          code: 'invalid-response',
        );
      }
      return data.map((key, value) => MapEntry(key.toString(), value));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const AiClientFailure(
          'The AI request was cancelled.',
          code: 'cancelled',
        );
      }
      final status = error.response?.statusCode;
      final body = error.response?.data;
      final errorMap = body is Map ? body['error'] : null;
      final code = errorMap is Map ? errorMap['code']?.toString() : null;
      final retryHeader = error.response?.headers.value('retry-after');
      final retrySeconds = int.tryParse(retryHeader ?? '');
      if (status == 401) {
        throw const AiClientFailure(
          'Your secure session or app verification expired. Sign in again and retry.',
          code: 'unauthenticated',
        );
      }
      if (status == 429) {
        throw AiClientFailure(
          'Your daily AI allowance is used. The offline planner is still available.',
          code: code ?? 'quota-exceeded',
          retryAfter:
              retrySeconds == null ? null : Duration(seconds: retrySeconds),
        );
      }
      if (status == 400) {
        throw AiClientFailure(
          'The planner context was not accepted. Review the dates and try again.',
          code: code ?? 'bad-request',
        );
      }
      if (code == 'provider_rejected') {
        throw const AiClientFailure(
          'An AI provider rejected Mento\'s request. Please retry; if this continues, contact the Mento administrator.',
          code: 'provider-rejected',
        );
      }
      if (code == 'provider_rate_limited') {
        throw const AiClientFailure(
          'The AI providers are busy right now. Please wait a moment and try again.',
          code: 'provider-rate-limited',
        );
      }
      if (code == 'provider_network_error' ||
          code == 'provider_upstream_error' ||
          code == 'provider_unavailable') {
        throw const AiClientFailure(
          'The AI providers could not be reached. Please try again shortly.',
          code: 'provider-unavailable',
        );
      }
      if (code == 'provider_timeout') {
        throw const AiClientFailure(
          'The AI providers took too long to respond. Please try again.',
          code: 'timeout',
        );
      }
      if (code == 'invalid_provider_response') {
        throw const AiClientFailure(
          'The AI providers returned an unusable response. Nothing was saved; please retry.',
          code: 'invalid-response',
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const AiClientFailure(
          'The AI service took too long. The offline planner can continue instead.',
          code: 'timeout',
        );
      }
      if (kDebugMode) {
        print(
          'MentoAiClient DioException: ${error.type} - ${error.message} - ${error.error}',
        );
        throw AiClientFailure(
          'AI is temporarily unavailable. Error: ${error.type} - ${error.message} - ${error.error}. Your saved data and offline planner still work.',
          code: 'unavailable',
        );
      }
      throw const AiClientFailure(
        'AI is temporarily unavailable. Your saved data and offline planner still work.',
        code: 'unavailable',
      );
    }
  }

  Future<Response<Map<String, dynamic>>> _send(
    Uri uri,
    Map<String, Object?> input, {
    required String idToken,
    required String appCheckToken,
    required String requestId,
    required CancelToken? cancelToken,
  }) => _dio.postUri<Map<String, dynamic>>(
    uri,
    data: input,
    cancelToken: cancelToken,
    options: Options(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer $idToken',
        'X-Firebase-AppCheck': appCheckToken,
        'X-Client-Request-ID': requestId,
        'Accept': Headers.jsonContentType,
      },
    ),
  );

  Future<String> _firebaseIdToken(
    User user, {
    required bool forceRefresh,
  }) async {
    try {
      final token = await user.getIdToken(forceRefresh) ?? '';
      if (token.isNotEmpty) return token;
    } catch (_) {
      // Mapped to the stable public error below.
    }
    throw const AiClientFailure(
      'Your secure session expired. Sign in again and retry.',
      code: 'unauthenticated',
    );
  }

  Future<String> _appCheckToken({required bool forceRefresh}) async {
    try {
      return await _appCheck.getToken(forceRefresh) ?? '';
    } catch (_) {
      // The Worker decides whether an App Check token is mandatory.
      return '';
    }
  }

  Uri _validatedUri(String path) {
    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasAuthority) {
      throw const AiClientFailure(
        'The secure AI proxy is not configured. Using offline planning is recommended.',
        code: 'not-configured',
      );
    }
    final local =
        base.host == 'localhost' ||
        base.host == '127.0.0.1' ||
        base.host == '10.0.2.2';
    if (base.scheme != 'https' && !(kDebugMode && local)) {
      throw const AiClientFailure(
        'The AI proxy must use HTTPS.',
        code: 'insecure-endpoint',
      );
    }
    return base.resolve(path);
  }
}

@visibleForTesting
Map<String, Object?> minimiseAiContext(Map<String, Object?> input) =>
    _sanitiseMap(input);

Map<String, Object?> _sanitiseMap(Map<String, Object?> input) {
  // Normalising keys also catches variations such as "user_id" and "UserId".
  const blocked = {
    'password',
    'token',
    'authorization',
    'email',
    'phone',
    'uid',
    'userid',
    'latitude',
    'longitude',
    'exactlocation',
    'locationhistory',
  };
  final output = <String, Object?>{};
  for (final entry in input.entries) {
    final normalised = entry.key.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    if (blocked.any(normalised.contains)) continue;
    final value = entry.value;
    output[entry.key] = switch (value) {
      Map<String, Object?>() => _sanitiseMap(value),
      Map() => _sanitiseMap(
        value.map((key, value) => MapEntry(key.toString(), value)),
      ),
      List() => value.map(_sanitiseValue).toList(growable: false),
      String() when value.length > 4000 => value.substring(0, 4000),
      _ => value,
    };
  }
  return output;
}

Object? _sanitiseValue(Object? value) => switch (value) {
  Map<String, Object?>() => _sanitiseMap(value),
  Map() => _sanitiseMap(
    value.map((key, value) => MapEntry(key.toString(), value)),
  ),
  List() => value.map(_sanitiseValue).toList(growable: false),
  String() when value.length > 4000 => value.substring(0, 4000),
  _ => value,
};
