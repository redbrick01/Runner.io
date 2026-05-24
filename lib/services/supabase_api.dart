import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

typedef JsonMap = Map<String, dynamic>;
typedef JsonList = List<dynamic>;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SupabaseApi {
  SupabaseApi._();

  static String get baseUrl => SupabaseConfig.url;
  static String get anonKey => SupabaseConfig.anonKey;

  static User? get currentUser => Supabase.instance.client.auth.currentUser;
  static Session? get currentSession =>
      Supabase.instance.client.auth.currentSession;

  static Uri functionUri(
    String functionName, {
    Map<String, dynamic>? queryParameters,
  }) {
    SupabaseConfig.requireConfigured();
    final normalizedQuery = queryParameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    return Uri.parse(
      '$baseUrl/functions/v1/$functionName',
    ).replace(queryParameters: normalizedQuery);
  }

  static Map<String, String> headers({
    bool includeJsonContentType = false,
    bool includeAuthorization = true,
    Session? session,
  }) {
    SupabaseConfig.requireConfigured();
    final result = <String, String>{'apikey': anonKey};

    if (includeJsonContentType) {
      result['Content-Type'] = 'application/json';
    }

    if (includeAuthorization) {
      final accessToken = session?.accessToken ?? currentSession?.accessToken;
      result['Authorization'] = 'Bearer ${accessToken ?? anonKey}';
    }

    return result;
  }

  static Future<Session?> waitForSession({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final existingSession = currentSession;
    if (existingSession != null) {
      return existingSession;
    }

    final completer = Completer<Session?>();
    late final StreamSubscription<AuthState> subscription;
    subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      if (!completer.isCompleted && authState.session != null) {
        completer.complete(authState.session);
      }
    });

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => currentSession,
      );
    } finally {
      await subscription.cancel();
    }
  }

  static Future<dynamic> getFunctionJson(
    String functionName, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final session = await waitForSession();
    final response = await http.get(
      functionUri(functionName, queryParameters: queryParameters),
      headers: headers(includeJsonContentType: true, session: session),
    );
    return _decodeResponse(response, functionName);
  }

  static Future<dynamic> postFunctionJson(
    String functionName, {
    required Map<String, dynamic> body,
    Map<String, dynamic>? queryParameters,
  }) async {
    final session = await waitForSession();
    final response = await http.post(
      functionUri(functionName, queryParameters: queryParameters),
      headers: headers(includeJsonContentType: true, session: session),
      body: json.encode(body),
    );
    return _decodeResponse(response, functionName);
  }

  static JsonMap requireJsonMap(dynamic decoded, String functionName) {
    if (decoded is JsonMap) {
      return decoded;
    }
    throw ApiException('$functionName returned an invalid response');
  }

  static dynamic _decodeResponse(http.Response response, String functionName) {
    debugPrint('$functionName response status: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        '$functionName request failed: ${response.statusCode} - ${response.body}',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      return null;
    }

    return json.decode(response.body);
  }
}
