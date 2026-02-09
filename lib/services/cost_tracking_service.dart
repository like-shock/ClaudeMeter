import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cost_data.dart';
import '../utils/pricing.dart';

/// Service that parses local JSONL files from Claude Code sessions
/// to calculate API usage costs.
class CostTrackingService {
  /// Get the Claude projects directory path.
  static String get _claudeProjectsPath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return '$home/.claude/projects';
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

    // Parse all files and accumulate costs
    final modelTokens = <String, TokenUsage>{};
    final dailyCosts = <String, _DailyAccumulator>{};
    final sessionIds = <String>{};
    DateTime? oldestSession;
    DateTime? newestSession;

    for (final file in jsonlFiles) {
      try {
        await _parseJsonlFile(
          file,
          modelTokens,
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

    // Build model breakdown
    final modelBreakdown = <ModelCost>[];
    double totalCost = 0;
    for (final entry in modelTokens.entries) {
      final cost = PricingTable.calculateCost(entry.key, entry.value);
      totalCost += cost;
      modelBreakdown.add(ModelCost(
        modelId: entry.key,
        displayName: PricingTable.normalizeModelId(entry.key),
        tokens: entry.value,
        cost: cost,
      ));
    }
    // Sort by cost descending
    modelBreakdown.sort((a, b) => b.cost.compareTo(a.cost));

    // Build daily costs
    final today = _dateKey(DateTime.now());
    double todayCost = 0;
    final dailyList = <DailyCost>[];
    final sortedDays = dailyCosts.keys.toList()..sort();
    for (final dayKey in sortedDays) {
      final acc = dailyCosts[dayKey]!;
      final dayCost = DailyCost(
        date: DateTime.parse(dayKey),
        cost: acc.cost,
        messageCount: acc.messageCount,
      );
      dailyList.add(dayCost);
      if (dayKey == today) {
        todayCost = acc.cost;
      }
    }

    return CostData(
      todayCost: todayCost,
      totalCost: totalCost,
      totalSessions: sessionIds.length,
      totalFiles: jsonlFiles.length,
      oldestSession: oldestSession,
      newestSession: newestSession,
      modelBreakdown: modelBreakdown,
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
    Map<String, TokenUsage> modelTokens,
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

      // Accumulate by model
      modelTokens[model] = (modelTokens[model] ?? const TokenUsage()) + tokenUsage;

      // Accumulate by day
      if (timestamp != null) {
        final dayKey = _dateKey(timestamp);
        final cost = PricingTable.calculateCost(model, tokenUsage);
        final acc = dailyCosts[dayKey] ?? _DailyAccumulator();
        acc.cost += cost;
        acc.messageCount += 1;
        dailyCosts[dayKey] = acc;
      }
    }
  }

  /// Format date as YYYY-MM-DD string.
  static String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _DailyAccumulator {
  double cost = 0;
  int messageCount = 0;
}
