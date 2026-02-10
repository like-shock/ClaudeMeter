import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/pricing.dart';

/// Service for auto-updating model pricing from LiteLLM.
///
/// Fetches pricing daily at noon, with ETag-based conditional requests.
/// Falls back to hardcoded prices on failure.
class PricingUpdateService {
  static const Duration _updateInterval = Duration(hours: 24);
  static const Duration _retryInterval = Duration(hours: 1);
  static const Duration _fetchTimeout = Duration(seconds: 30);

  /// Anthropic official cache multipliers (relative to input rate).
  static const double _cache5mMultiplier = 1.25;
  static const double _cache1hMultiplier = 2.0;
  static const double _cacheReadMultiplier = 0.1;

  static const String _cacheKey = 'cached_pricing';
  static const String _lastFetchKey = 'pricing_last_fetch';
  static const String _etagKey = 'pricing_etag';

  Timer? _timer;
  String? _etag;
  int? _lastFetchTime;

  /// Initialize: load cached prices, check staleness, schedule updates.
  Future<void> init() async {
    await _loadCachedPrices();

    final now = DateTime.now().millisecondsSinceEpoch;
    final stale = _lastFetchTime == null ||
        (now - _lastFetchTime!) > _updateInterval.inMilliseconds;

    if (stale) {
      // Fire-and-forget initial fetch
      fetchAndUpdate().catchError((e) {
        developer.log('Initial pricing fetch failed: $e',
            name: 'PricingUpdateService', level: 900);
      });
    }

    _scheduleNextUpdate();
  }

  /// Fetch latest pricing from LiteLLM and update PricingTable.
  Future<void> fetchAndUpdate() async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      developer.log('Rejected bad certificate for $host:$port',
          name: 'PricingUpdateService.TLS', level: 1000);
      return false;
    };

    try {
      final uri = Uri.parse(ApiConstants.pricingSourceUrl);
      final request = await client.getUrl(uri).timeout(_fetchTimeout);

      // ETag conditional request
      if (_etag != null) {
        request.headers.set('If-None-Match', _etag!);
      }

      final response = await request.close().timeout(_fetchTimeout);

      if (response.statusCode == 304) {
        // Not modified — update fetch time only
        _lastFetchTime = DateTime.now().millisecondsSinceEpoch;
        await _saveLastFetchTime();
        developer.log('Pricing: 304 Not Modified',
            name: 'PricingUpdateService');
        return;
      }

      if (response.statusCode != 200) {
        developer.log('Pricing fetch failed: HTTP ${response.statusCode}',
            name: 'PricingUpdateService', level: 900);
        _scheduleRetry();
        return;
      }

      // Save ETag for next request
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        _etag = newEtag;
      }

      // Read response with size limit
      final bytes = await _readResponseWithLimit(
          response, ApiConstants.maxPricingResponseBytes);
      if (bytes == null) {
        developer.log('Pricing response too large',
            name: 'PricingUpdateService', level: 900);
        _scheduleRetry();
        return;
      }

      final jsonString = utf8.decode(bytes);
      final data = jsonDecode(jsonString);
      if (data is! Map<String, dynamic>) {
        developer.log('Pricing: invalid JSON structure',
            name: 'PricingUpdateService', level: 900);
        _scheduleRetry();
        return;
      }

      final fetched = extractClaudeModels(data);
      if (fetched.isEmpty) {
        developer.log('Pricing: no Claude models found',
            name: 'PricingUpdateService', level: 900);
        _scheduleRetry();
        return;
      }

      final merged = mergeWithHardcoded(fetched);
      PricingTable.updateModels(merged);

      _lastFetchTime = DateTime.now().millisecondsSinceEpoch;
      await _saveCachedPrices(merged);
      await _saveLastFetchTime();
      await _saveEtag();

      developer.log('Pricing updated: ${merged.length} models',
          name: 'PricingUpdateService');
    } on TimeoutException {
      developer.log('Pricing fetch timeout',
          name: 'PricingUpdateService', level: 900);
      _scheduleRetry();
    } on SocketException catch (e) {
      developer.log('Pricing fetch network error: $e',
          name: 'PricingUpdateService', level: 900);
      _scheduleRetry();
    } on FormatException catch (e) {
      developer.log('Pricing JSON parse error: $e',
          name: 'PricingUpdateService', level: 900);
      _scheduleRetry();
    } catch (e) {
      developer.log('Pricing fetch error: $e',
          name: 'PricingUpdateService', level: 900);
      _scheduleRetry();
    } finally {
      client.close();
    }
  }

  /// Cancel scheduled timers.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Extract Claude models from LiteLLM JSON.
  ///
  /// Filters keys starting with "claude-", converts per-token rates to
  /// per-million-token rates, and applies Anthropic cache multipliers.
  static List<ModelPricing> extractClaudeModels(Map<String, dynamic> data) {
    final models = <String, ModelPricing>{};

    for (final entry in data.entries) {
      final key = entry.key;
      if (!key.startsWith('claude-')) continue;
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;

      final inputCost = value['input_cost_per_token'];
      final outputCost = value['output_cost_per_token'];
      if (inputCost is! num || outputCost is! num) continue;
      if (inputCost <= 0 || outputCost <= 0) continue;

      final canonicalId = stripDateSuffix(key);
      // Skip if we already have this canonical ID (first match wins)
      if (models.containsKey(canonicalId)) continue;

      final inputRate = inputCost.toDouble() * 1000000; // per-token → per-MTok
      final outputRate = outputCost.toDouble() * 1000000;

      models[canonicalId] = ModelPricing(
        modelId: canonicalId,
        displayName: generateDisplayName(canonicalId),
        inputRate: inputRate,
        cache5mWriteRate: inputRate * _cache5mMultiplier,
        cache1hWriteRate: inputRate * _cache1hMultiplier,
        cacheReadRate: inputRate * _cacheReadMultiplier,
        outputRate: outputRate,
      );
    }

    return models.values.toList();
  }

  /// Merge fetched models with hardcoded fallbacks.
  ///
  /// Fetched models override hardcoded ones with the same ID.
  /// Hardcoded models not present in fetched data are preserved.
  static List<ModelPricing> mergeWithHardcoded(List<ModelPricing> fetched) {
    final merged = <String, ModelPricing>{};

    // Start with hardcoded models
    for (final m in PricingTable.hardcodedModels) {
      merged[m.modelId] = m;
    }

    // Override/add with fetched models
    for (final m in fetched) {
      merged[m.modelId] = m;
    }

    return merged.values.toList();
  }

  /// Strip date suffix from model ID.
  /// "claude-opus-4-6-20260101" → "claude-opus-4-6"
  static String stripDateSuffix(String modelId) {
    final match = RegExp(r'-(\d{8})$').firstMatch(modelId);
    if (match != null) {
      return modelId.substring(0, match.start);
    }
    return modelId;
  }

  /// Generate display name from canonical model ID.
  /// "claude-opus-4-6" → "Opus 4.6"
  /// "claude-sonnet-4-5" → "Sonnet 4.5"
  /// "claude-3-5-haiku" → "Haiku 3.5"
  static String generateDisplayName(String modelId) {
    // Legacy pattern: claude-3-5-haiku, claude-3-5-sonnet
    final legacyMatch =
        RegExp(r'^claude-(\d+)-(\d+)-(\w+)$').firstMatch(modelId);
    if (legacyMatch != null) {
      final major = legacyMatch.group(1)!;
      final minor = legacyMatch.group(2)!;
      final family = legacyMatch.group(3)!;
      final capitalizedFamily =
          family[0].toUpperCase() + family.substring(1).toLowerCase();
      return '$capitalizedFamily $major.$minor';
    }

    // Modern pattern: claude-{family}-{major}-{minor}
    final modernMatch =
        RegExp(r'^claude-(\w+?)-(\d+)(?:-(\d+))?$').firstMatch(modelId);
    if (modernMatch != null) {
      final family = modernMatch.group(1)!;
      final major = modernMatch.group(2)!;
      final minor = modernMatch.group(3);
      final capitalizedFamily =
          family[0].toUpperCase() + family.substring(1).toLowerCase();
      if (minor != null) {
        return '$capitalizedFamily $major.$minor';
      }
      return '$capitalizedFamily $major';
    }

    // Fallback: strip "claude-" prefix
    return modelId.replaceFirst('claude-', '');
  }

  /// Check if pricing data is stale.
  bool shouldFetch() {
    if (_lastFetchTime == null) return true;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _lastFetchTime!;
    return elapsed > _updateInterval.inMilliseconds;
  }

  // ── Private helpers ────────────────────────────────────────────

  void _scheduleNextUpdate() {
    _timer?.cancel();

    final now = DateTime.now();
    // Schedule for next noon (local time)
    var nextNoon = DateTime(now.year, now.month, now.day, 12);
    if (now.isAfter(nextNoon)) {
      nextNoon = nextNoon.add(const Duration(days: 1));
    }
    final delay = nextNoon.difference(now);

    _timer = Timer(delay, () async {
      await fetchAndUpdate().catchError((e) {
        developer.log('Scheduled pricing fetch failed: $e',
            name: 'PricingUpdateService', level: 900);
      });
      _scheduleNextUpdate();
    });

    developer.log('Next pricing update in ${delay.inHours}h ${delay.inMinutes % 60}m',
        name: 'PricingUpdateService');
  }

  void _scheduleRetry() {
    _timer?.cancel();
    _timer = Timer(_retryInterval, () async {
      await fetchAndUpdate().catchError((e) {
        developer.log('Retry pricing fetch failed: $e',
            name: 'PricingUpdateService', level: 900);
      });
      _scheduleNextUpdate();
    });
    developer.log('Pricing retry scheduled in 1h',
        name: 'PricingUpdateService');
  }

  Future<void> _loadCachedPrices() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _lastFetchTime = prefs.getInt(_lastFetchKey);
      _etag = prefs.getString(_etagKey);

      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final models = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => ModelPricing.fromJson(m))
              .where((m) => m.modelId.isNotEmpty)
              .toList();
          if (models.isNotEmpty) {
            PricingTable.updateModels(models);
            developer.log('Loaded ${models.length} cached pricing models',
                name: 'PricingUpdateService');
          }
        }
      }
    } catch (e) {
      developer.log('Failed to load cached prices: $e',
          name: 'PricingUpdateService', level: 900);
      // Keep hardcoded prices
    }
  }

  Future<void> _saveCachedPrices(List<ModelPricing> models) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(models.map((m) => m.toJson()).toList());
      await prefs.setString(_cacheKey, jsonStr);
    } catch (e) {
      developer.log('Failed to save cached prices: $e',
          name: 'PricingUpdateService', level: 900);
    }
  }

  Future<void> _saveLastFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastFetchKey, _lastFetchTime!);
    } catch (e) {
      developer.log('Failed to save fetch time: $e',
          name: 'PricingUpdateService', level: 900);
    }
  }

  Future<void> _saveEtag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_etag != null) {
        await prefs.setString(_etagKey, _etag!);
      }
    } catch (e) {
      developer.log('Failed to save ETag: $e',
          name: 'PricingUpdateService', level: 900);
    }
  }

  /// Read HTTP response body with size limit.
  static Future<List<int>?> _readResponseWithLimit(
      HttpClientResponse response, int maxBytes) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        return null;
      }
    }
    return builder.takeBytes();
  }
}
