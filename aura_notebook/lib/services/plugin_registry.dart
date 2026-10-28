/// AURA Plugin Protocol — Dart-side interface for adding new capabilities.
///
/// Plugins intercept user messages before the LLM and post-process responses
/// after the LLM. The core engine never changes; plugins register at init.
///
/// Usage:
/// ```dart
/// class WebSearchPlugin extends AuraPlugin {
///   String get name => 'web_search';
///
///   bool canHandle(String prompt) =>
///       prompt.toLowerCase().contains('search for');
///
///   Future<String?> handle(String prompt) async {
///     final query = prompt.replaceAll('search for', '').trim();
///     return await WebSearchAPI.search(query);
///   }
/// }
///
/// // Register at startup
/// PluginRegistry.register(WebSearchPlugin());
/// ```
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Base class for AURA plugins. Extend this to add new capabilities.
abstract class AuraPlugin {
  /// Unique identifier (e.g., "web_search", "mcp_tools", "rive_character").
  String get name;

  /// Priority order. Lower = checked first. Default is 100.
  /// 0-50: critical (security, safety)
  /// 50-100: standard (web search, tools)
  /// 100+: cosmetic (animation, logging)
  int get priority => 100;

  /// Called once at app startup. Use this to initialize resources.
  Future<void> init() async {}

  /// Can this plugin handle this user message? Called on every turn.
  bool canHandle(String prompt);

  /// Handle the user message. Return a response to skip the LLM,
  /// or null to let the LLM handle it.
  Future<String?> handle(String prompt);

  /// Post-process the LLM response. Called on every turn, even if
  /// canHandle returned false. Default: no-op.
  String postProcess(String response) => response;

  /// Called on app shutdown. Clean up resources.
  void shutdown() {}
}

/// Plugin registry. Holds all registered plugins and dispatches messages.
class PluginRegistry {
  static final _plugins = <AuraPlugin>[];
  static bool _sorted = false;

  /// Register a plugin. Call this at app startup.
  static void register(AuraPlugin plugin) {
    _plugins.add(plugin);
    _sorted = false;
  }

  /// Sort plugins by priority (if not already sorted).
  static void _ensureSorted() {
    if (!_sorted) {
      _plugins.sort((a, b) => a.priority.compareTo(b.priority));
      _sorted = true;
    }
  }

  /// Initialize all registered plugins. Call once at startup.
  static Future<void> initAll() async {
    _ensureSorted();
    for (final plugin in _plugins) {
      try {
        await plugin.init();
        debugPrint('[PLUGIN] ${plugin.name} initialized');
      } catch (e) {
        debugPrint('[PLUGIN] ${plugin.name} failed to init: $e');
      }
    }
  }

  /// Try to handle a user message with plugins. Returns a response
  /// if a plugin handled it, null if the LLM should handle it.
  static Future<String?> tryHandle(String prompt) async {
    _ensureSorted();
    for (final plugin in _plugins) {
      if (plugin.canHandle(prompt)) {
        try {
          final response = await plugin.handle(prompt);
          if (response != null) {
            if (kDebugMode) {
              debugPrint('[PLUGIN] ${plugin.name} handled prompt');
            }
            return response;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PLUGIN] ${plugin.name} error: $e');
          }
        }
      }
    }
    return null;
  }

  /// Post-process a response through all plugins.
  static String postProcessAll(String response) {
    _ensureSorted();
    var result = response;
    for (final plugin in _plugins) {
      result = plugin.postProcess(result);
    }
    return result;
  }

  /// Shutdown all plugins.
  static void shutdownAll() {
    for (final plugin in _plugins) {
      plugin.shutdown();
      debugPrint('[PLUGIN] ${plugin.name} shut down');
    }
  }

  /// Number of registered plugins.
  static int get count => _plugins.length;

  /// List of registered plugin names.
  static List<String> get names => _plugins.map((p) => p.name).toList();
}
