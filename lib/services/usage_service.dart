import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/usage_data.dart';
import '../utils/constants.dart';
import 'oauth_service.dart';

/// Service for fetching Claude usage data.
///
/// Uses dart:io HttpClient with badCertificateCallback for TLS verification,
/// consistent with OAuthService's secure HTTP approach.
class UsageService {
  final OAuthService _oauthService;

  UsageService(this._oauthService);

  /// Create a secure HttpClient with TLS certificate verification.
  HttpClient _createSecureHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      developer.log(
        'Rejected bad certificate for $host:$port',
        name: 'UsageService.TLS',
        level: 1000, // SEVERE
      );
      return false;
    };
    return client;
  }

  /// Fetch user profile from the API.
  Future<String?> fetchUserEmail() async {
    final token = await _oauthService.getAccessToken();
    if (token == null) return null;

    final client = _createSecureHttpClient();
    try {
      final uri = Uri.parse(ApiConstants.profileUrl);
      final request = await client.getUrl(uri);

      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('User-Agent', ApiConstants.userAgent);

      final response = await request.close().timeout(ApiConstants.apiTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        debugPrint('Profile API error: ${response.statusCode}');
        return null;
      }

      debugPrint('Profile API response: $responseBody');
      
      final json = jsonDecode(responseBody);
      if (json is! Map<String, dynamic>) return null;
      
      // API returns account.email
      final account = json['account'];
      if (account is Map<String, dynamic>) {
        return account['email'] as String? ?? 
               account['display_name'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Profile fetch error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetch current usage data from the API.
  Future<UsageData> fetchUsage() async {
    final token = await _oauthService.getAccessToken();
    if (token == null) {
      throw Exception('Not logged in');
    }

    final client = _createSecureHttpClient();
    try {
      final uri = Uri.parse(ApiConstants.usageUrl);
      final request = await client.getUrl(uri);

      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('User-Agent', ApiConstants.userAgent);
      request.headers.set('anthropic-beta', 'oauth-2025-04-20');

      final response = await request.close().timeout(ApiConstants.apiTimeout);

      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 401) {
        throw Exception('auth_expired');
      }

      if (response.statusCode != 200) {
        developer.log(
          'Usage API error: ${response.statusCode} - $responseBody',
          name: 'UsageService',
          level: 900, // WARNING
        );
        throw Exception('API error: ${response.statusCode}');
      }

      debugPrint('Usage API response: $responseBody');
      
      final json = jsonDecode(responseBody);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Usage response is not a JSON object');
      }
      return UsageData.fromJson(json);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to fetch usage data',
        name: 'UsageService',
        error: e,
        stackTrace: stackTrace,
        level: 900, // WARNING
      );
      rethrow;
    } finally {
      client.close();
    }
  }
}
