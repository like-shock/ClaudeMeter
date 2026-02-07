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

  /// Parse credentials from JSON with defensive type checking.
  /// Throws [FormatException] if required fields are missing or invalid.
  factory Credentials.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAt = json['expiresAt'];

    if (accessToken != null && accessToken is! String) {
      throw const FormatException('accessToken must be a String');
    }
    if (refreshToken != null && refreshToken is! String) {
      throw const FormatException('refreshToken must be a String');
    }
    if (expiresAt != null && expiresAt is! int) {
      throw const FormatException('expiresAt must be an int');
    }

    return Credentials(
      accessToken: (accessToken as String?) ?? '',
      refreshToken: (refreshToken as String?) ?? '',
      expiresAt: (expiresAt as int?) ?? 0,
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

  /// Create a cleared/empty credentials instance (for secure token wiping).
  static const Credentials empty = Credentials(
    accessToken: '',
    refreshToken: '',
    expiresAt: 0,
  );
}
