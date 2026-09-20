import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextSizeOption { small, standard, large }

extension TextSizeOptionScale on TextSizeOption {
  double get scaleFactor {
    switch (this) {
      case TextSizeOption.small:
        return 0.9;
      case TextSizeOption.standard:
        return 1.0;
      case TextSizeOption.large:
        return 1.2;
    }
  }
}

/// Client-only preferences: nothing here is synced anywhere, so all of it
/// works identically with or without a Firebase project configured.
class AppSettingsProvider extends ChangeNotifier {
  static const _textSizeKey = 'app_text_size';
  static const _batterySaverKey = 'app_battery_saver';
  static const _dataSaverKey = 'app_data_saver';

  TextSizeOption _textSize = TextSizeOption.standard;
  TextSizeOption get textSize => _textSize;

  bool _batterySaver = false;
  bool get batterySaver => _batterySaver;

  bool _dataSaver = false;
  bool get dataSaver => _dataSaver;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSize = prefs.getString(_textSizeKey);
    if (storedSize != null) {
      _textSize = TextSizeOption.values.firstWhere(
        (option) => option.name == storedSize,
        orElse: () => TextSizeOption.standard,
      );
    }
    _batterySaver = prefs.getBool(_batterySaverKey) ?? false;
    _dataSaver = prefs.getBool(_dataSaverKey) ?? false;
    notifyListeners();
  }

  Future<void> setTextSize(TextSizeOption option) async {
    _textSize = option;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textSizeKey, option.name);
  }

  Future<void> setBatterySaver(bool enabled) async {
    _batterySaver = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batterySaverKey, enabled);
  }

  Future<void> setDataSaver(bool enabled) async {
    _dataSaver = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSaverKey, enabled);
  }
}
