import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usage_data.dart';
import '../utils/constants.dart';
import 'oauth_service.dart';

/// Service for fetching Claude usage data.
class UsageService {
  final OAuthService _oauthService;

  UsageService(this._oauthService);

  /// Fetch current usage data from the API.
  Future<UsageData> fetchUsage() async {
    final token = await _oauthService.getAccessToken();
    if (token == null) {
      throw Exception('Not logged in');
    }

    final response = await http.get(
      Uri.parse(ApiConstants.usageUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'anthropic-beta': 'oauth-2025-04-20',
      },
    ).timeout(ApiConstants.apiTimeout);

    if (response.statusCode == 401) {
      throw Exception('auth_expired');
    }

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UsageData.fromJson(json);
  }
}
