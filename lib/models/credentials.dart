/// OAuth credentials for Claude API.
class Credentials {
  final String accessToken;
  final String refreshToken;
  final int expiresAt; // Unix milliseconds

  const Credentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory Credentials.fromJson(Map<String, dynamic> json) {
    return Credentials(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt,
    };
  }

  /// Check if credentials are valid.
  bool get hasCredentials => refreshToken.isNotEmpty;

  /// Check if access token is expired (with 1 minute buffer).
  bool get isExpired {
    if (expiresAt == 0) return true;
    final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
    final buffer = DateTime.now().add(const Duration(minutes: 1));
    return buffer.isAfter(expiresAtDate);
  }

  /// Create new credentials with updated tokens.
  Credentials copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresAt,
  }) {
    return Credentials(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
