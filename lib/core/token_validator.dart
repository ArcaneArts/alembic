import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum TokenValidationFailureKind {
  invalid,
  rateLimited,
  network,
  unknown,
}

class TokenValidationResult {
  final bool isValid;
  final TokenValidationFailureKind? failureKind;
  final String message;
  final String? login;

  const TokenValidationResult._({
    required this.isValid,
    required this.failureKind,
    required this.message,
    required this.login,
  });

  factory TokenValidationResult.valid({String? login}) {
    return TokenValidationResult._(
      isValid: true,
      failureKind: null,
      message: 'Token is valid.',
      login: login,
    );
  }

  factory TokenValidationResult.invalid(String message) {
    return TokenValidationResult._(
      isValid: false,
      failureKind: TokenValidationFailureKind.invalid,
      message: message,
      login: null,
    );
  }

  factory TokenValidationResult.rateLimited(String message) {
    return TokenValidationResult._(
      isValid: false,
      failureKind: TokenValidationFailureKind.rateLimited,
      message: message,
      login: null,
    );
  }

  factory TokenValidationResult.network(String message) {
    return TokenValidationResult._(
      isValid: false,
      failureKind: TokenValidationFailureKind.network,
      message: message,
      login: null,
    );
  }

  factory TokenValidationResult.unknown(String message) {
    return TokenValidationResult._(
      isValid: false,
      failureKind: TokenValidationFailureKind.unknown,
      message: message,
      login: null,
    );
  }
}

class TokenValidator {
  final http.Client? client;
  final Duration timeout;

  const TokenValidator({
    this.client,
    this.timeout = const Duration(seconds: 15),
  });

  Future<TokenValidationResult> validate(String token) async {
    String normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return TokenValidationResult.invalid('Token is required.');
    }

    http.Client clientToUse = client ?? http.Client();
    bool ownsClient = client == null;

    try {
      http.Response response = await clientToUse.get(
        Uri.parse('https://api.github.com/user'),
        headers: <String, String>{
          'Authorization': 'Bearer $normalizedToken',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        dynamic payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          String login = (payload['login'] as String? ?? '').trim();
          return TokenValidationResult.valid(
            login: login.isEmpty ? null : login,
          );
        }
        return TokenValidationResult.valid();
      }

      if (response.statusCode == 401) {
        return TokenValidationResult.invalid(
          'GitHub rejected this token (401 Unauthorized).',
        );
      }

      if (response.statusCode == 429) {
        return TokenValidationResult.rateLimited(
          'GitHub API rate limit hit. Please retry shortly.',
        );
      }

      if (response.statusCode == 403) {
        String remaining =
            (response.headers['x-ratelimit-remaining'] ?? '').trim();
        String bodyLower = response.body.toLowerCase();
        bool rateLimited = remaining == '0' || bodyLower.contains('rate limit');
        if (rateLimited) {
          return TokenValidationResult.rateLimited(
            'GitHub API rate limit hit. Please retry shortly.',
          );
        }
        return TokenValidationResult.invalid(
          'Token lacks required access or is forbidden (403).',
        );
      }

      return TokenValidationResult.unknown(
        'GitHub validation failed (${response.statusCode}).',
      );
    } on SocketException {
      return TokenValidationResult.network(
        'Network error while validating token. Check connection and retry.',
      );
    } on TimeoutException {
      return TokenValidationResult.network(
        'Validation timed out. Check connection and retry.',
      );
    } on http.ClientException {
      return TokenValidationResult.network(
        'Network client error while validating token.',
      );
    } catch (e) {
      return TokenValidationResult.unknown(
        'Unexpected validation error: $e',
      );
    } finally {
      if (ownsClient) {
        clientToUse.close();
      }
    }
  }
}
