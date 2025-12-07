import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

/// Theme mode options
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Settings state
class SettingsState {
  final AppThemeMode themeMode;
  final int farePrice;
  final bool isLoading;

  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.farePrice = 3200,
    this.isLoading = true,
  });

  SettingsState copyWith({
    AppThemeMode? themeMode,
    int? farePrice,
    bool? isLoading,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      farePrice: farePrice ?? this.farePrice,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'farePrice': farePrice,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      themeMode: AppThemeMode.values[json['themeMode'] as int? ?? 0],
      farePrice: json['farePrice'] as int? ?? 3200,
      isLoading: false,
    );
  }
}

/// Settings notifier
class SettingsNotifier extends Notifier<SettingsState> {
  static const _fileName = 'settings.json';

  @override
  SettingsState build() {
    Future.microtask(() => _loadSettings());
    return const SettingsState();
  }

  Future<File> get _settingsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        state = SettingsState.fromJson(json);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _settingsFile;
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (e) {
      // Silent fail
    }
  }

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
  }

  void setFarePrice(int price) {
    if (price > 0) {
      state = state.copyWith(farePrice: price);
      _saveSettings();
    }
  }

  /// Calculate how many fares the balance can cover
  int calculateFares(double? balance) {
    if (balance == null || balance <= 0) return 0;
    return (balance / state.farePrice).floor();
  }
}

/// Settings provider
final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
