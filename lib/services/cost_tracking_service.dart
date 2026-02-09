import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cost_data.dart';
import '../utils/pricing.dart';

/// Service that parses local JSONL files from Claude Code sessions
/// to calculate API usage costs.
class CostTrackingService {
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

  /// Get the Claude projects directory path.
  static String get _claudeProjectsPath {
    return '$_realHomePath/.claude/projects';
  }

  /// Scan all JSONL files and compute cost data.
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

    // Parse all files and accumulate costs.
    // Deduplicate by message.id + requestId — Claude Code writes the same
    // assistant message multiple times (streaming chunks) in JSONL.
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

class _DailyAccumulator {
  double cost = 0;
  int messageCount = 0;
  int totalTokens = 0;
  final Map<String, TokenUsage> modelTokens = {};
}
