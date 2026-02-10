import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cost_data.dart';
import '../utils/pricing.dart';

/// Service that parses local JSONL files from Claude Code sessions
/// to calculate API usage costs.
///
/// Uses mtime-based caching: on each refresh cycle, file mtimes are compared
/// against the cached state. If no files changed, the cached CostData is
/// returned immediately (fast path). Otherwise a full re-parse is performed
/// and the cache is updated.
class CostTrackingService {
  static const int _cacheVersion = 1;

  /// In-memory cached cost data from the last successful parse or cache load.
  CostData? _cachedCostData;

  /// In-memory file states from the last successful parse or cache load.
  /// Key: file path, Value: {mtime (ms since epoch), size (bytes)}.
  Map<String, _FileState>? _cachedFileStates;

  /// Get the real user home directory, resolving macOS sandbox redirection.
  /// In sandbox, HOME is redirected to the app container path;
  /// we extract the real home to read Claude CLI files.
  static String get _realHomePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (Platform.isMacOS) {
      final containerMatch =
          RegExp(r'^(/Users/[^/]+)/Library/Containers/')
              .firstMatch(home);
      if (containerMatch != null) {
        return containerMatch.group(1)!;
      }
    }
    return home;
  }

  /// Get the sandbox-safe home directory (for cache file writing).
  static String get _sandboxHomePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
  }

  /// Get the Claude projects directory path.
  static String get _claudeProjectsPath {
    return '$_realHomePath/.claude/projects';
  }

  /// Get the cache file path (inside app sandbox on macOS).
  static String get _cacheFilePath {
    return '$_sandboxHomePath/.claudemeter_cost_cache.json';
  }

  /// Scan all JSONL files and compute cost data, using mtime cache.
  Future<CostData> calculateCosts() async {
    final projectsDir = Directory(_claudeProjectsPath);
    if (!projectsDir.existsSync()) {
      return CostData.empty();
    }

    // Collect all .jsonl files (including subagent files)
    final jsonlFiles = <File>[];
    try {
      await _collectJsonlFiles(projectsDir, jsonlFiles);
    } catch (e) {
      if (kDebugMode) debugPrint('Error scanning JSONL files: $e');
      return CostData.empty();
    }

    if (jsonlFiles.isEmpty) return CostData.empty();

    // Collect current file states (mtime + size)
    final currentFileStates = <String, _FileState>{};
    for (final file in jsonlFiles) {
      try {
        final stat = file.statSync();
        currentFileStates[file.path] = _FileState(
          mtimeMs: stat.modified.millisecondsSinceEpoch,
          size: stat.size,
        );
      } catch (_) {
        // File may have been deleted between listing and stat
      }
    }

    // Try in-memory cache first, then disk cache
    if (_cachedCostData != null && _cachedFileStates != null) {
      if (_fileStatesMatch(_cachedFileStates!, currentFileStates)) {
        return _cachedCostData!;
      }
    } else {
      // Try loading from disk cache
      final diskCache = await _loadCache();
      if (diskCache != null) {
        _cachedCostData = diskCache.costData;
        _cachedFileStates = diskCache.fileStates;
        if (_fileStatesMatch(diskCache.fileStates, currentFileStates)) {
          return diskCache.costData;
        }
      }
    }

    // Cache miss — full re-parse
    final costData = await _fullParse(jsonlFiles);

    // Update in-memory cache
    _cachedCostData = costData;
    _cachedFileStates = currentFileStates;

    // Persist to disk (fire-and-forget, don't block return)
    _saveCache(currentFileStates, costData);

    return costData;
  }

  /// Compare two file state maps. Returns true if all paths, mtimes,
  /// and sizes are identical.
  bool _fileStatesMatch(
    Map<String, _FileState> cached,
    Map<String, _FileState> current,
  ) {
    if (cached.length != current.length) return false;
    for (final entry in current.entries) {
      final cachedState = cached[entry.key];
      if (cachedState == null) return false;
      if (cachedState.mtimeMs != entry.value.mtimeMs ||
          cachedState.size != entry.value.size) {
        return false;
      }
    }
    return true;
  }

  /// Perform a full parse of all JSONL files.
  Future<CostData> _fullParse(List<File> jsonlFiles) async {
    final seenMessages = <String>{};
    final dailyCosts = <String, _DailyAccumulator>{};
    final sessionIds = <String>{};
    DateTime? oldestSession;
    DateTime? newestSession;

    for (final file in jsonlFiles) {
      try {
        await _parseJsonlFile(
          file,
          seenMessages,
          dailyCosts,
          sessionIds,
          (timestamp) {
            if (oldestSession == null || timestamp.isBefore(oldestSession!)) {
              oldestSession = timestamp;
            }
            if (newestSession == null || timestamp.isAfter(newestSession!)) {
              newestSession = timestamp;
            }
          },
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error parsing ${file.path}: $e');
      }
    }

    // Build daily costs
    final dailyList = <DailyCost>[];
    final sortedDays = dailyCosts.keys.toList()..sort();
    for (final dayKey in sortedDays) {
      final acc = dailyCosts[dayKey]!;
      dailyList.add(DailyCost(
        date: DateTime.parse(dayKey),
        cost: acc.cost,
        messageCount: acc.messageCount,
        totalTokens: acc.totalTokens,
        modelTokens: Map.unmodifiable(acc.modelTokens),
      ));
    }

    return CostData(
      totalSessions: sessionIds.length,
      totalFiles: jsonlFiles.length,
      oldestSession: oldestSession,
      newestSession: newestSession,
      dailyCosts: dailyList,
      fetchedAt: DateTime.now(),
    );
  }

  /// Load cache from disk. Returns null if cache is missing or invalid.
  Future<_DiskCache?> _loadCache() async {
    try {
      final file = File(_cacheFilePath);
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      if (json['version'] != _cacheVersion) return null;

      final fileStatesJson = json['fileStates'] as Map<String, dynamic>? ?? {};
      final fileStates = fileStatesJson.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, _FileState(
          mtimeMs: m['mtime'] as int,
          size: m['size'] as int,
        ));
      });

      final costDataJson = json['costData'] as Map<String, dynamic>?;
      if (costDataJson == null) return null;

      final costData = CostData.fromJson(costDataJson);
      return _DiskCache(fileStates: fileStates, costData: costData);
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cost cache: $e');
      return null;
    }
  }

  /// Save cache to disk (async, errors are silently ignored).
  Future<void> _saveCache(
    Map<String, _FileState> fileStates,
    CostData costData,
  ) async {
    try {
      final json = {
        'version': _cacheVersion,
        'lastScanAt': DateTime.now().toIso8601String(),
        'fileStates': fileStates.map((k, v) => MapEntry(k, {
              'mtime': v.mtimeMs,
              'size': v.size,
            })),
        'costData': costData.toJson(),
      };
      final file = File(_cacheFilePath);
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving cost cache: $e');
    }
  }

  /// Recursively collect .jsonl files from projects directory.
  Future<void> _collectJsonlFiles(Directory dir, List<File> result) async {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        result.add(entity);
      }
    }
  }

  /// Parse a single JSONL file and accumulate token data.
  Future<void> _parseJsonlFile(
    File file,
    Set<String> seenMessages,
    Map<String, _DailyAccumulator> dailyCosts,
    Set<String> sessionIds,
    void Function(DateTime) onTimestamp,
  ) async {
    final lines = await file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();

    for (final line in lines) {
      if (line.isEmpty) continue;

      Map<String, dynamic> json;
      try {
        json = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      // Only process assistant messages with usage data
      if (json['type'] != 'assistant') continue;

      final message = json['message'];
      if (message is! Map<String, dynamic>) continue;

      final usage = message['usage'];
      if (usage is! Map<String, dynamic>) continue;

      final model = message['model'];
      if (model is! String || model.isEmpty) continue;

      // Skip synthetic entries (internal error messages, not real API calls)
      if (model.startsWith('<')) continue;

      // Deduplicate: Claude Code writes the same message multiple times
      // in JSONL (streaming). Use message.id + requestId as unique key.
      final msgId = message['id'];
      final reqId = json['requestId'];
      if (msgId is String && msgId.isNotEmpty) {
        final dedupKey = '$msgId:${reqId ?? ''}';
        if (!seenMessages.add(dedupKey)) continue;
      }

      // Track session
      final sessionId = json['sessionId'];
      if (sessionId is String) sessionIds.add(sessionId);

      // Parse timestamp
      final timestampRaw = json['timestamp'];
      DateTime? timestamp;
      if (timestampRaw is String) {
        timestamp = DateTime.tryParse(timestampRaw);
      }
      if (timestamp != null) {
        onTimestamp(timestamp);
      }

      // Parse tokens
      final tokenUsage = TokenUsage.fromJson(usage);

      // Accumulate by day
      if (timestamp != null) {
        final dayKey = _dateKey(timestamp);
        final cost = PricingTable.calculateCost(model, tokenUsage);
        final acc = dailyCosts[dayKey] ?? _DailyAccumulator();
        acc.cost += cost;
        acc.messageCount += 1;
        acc.totalTokens += tokenUsage.totalTokens;
        acc.modelTokens[model] =
            (acc.modelTokens[model] ?? const TokenUsage()) + tokenUsage;
        dailyCosts[dayKey] = acc;
      }
    }
  }

  /// Format date as YYYY-MM-DD string in local timezone.
  /// JSONL timestamps are UTC; convert to local so daily buckets
  /// match the user's calendar date.
  static String _dateKey(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _FileState {
  final int mtimeMs;
  final int size;
  const _FileState({required this.mtimeMs, required this.size});
}

class _DiskCache {
  final Map<String, _FileState> fileStates;
  final CostData costData;
  const _DiskCache({required this.fileStates, required this.costData});
}

class _DailyAccumulator {
  double cost = 0;
  int messageCount = 0;
  int totalTokens = 0;
  final Map<String, TokenUsage> modelTokens = {};
}
