import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  static const bool serialNoItemWiseValidate = true;
  static int roundingPrecision = 2;
  static int roundingPrecisionForQuantity = 0;
  static String roundingRule = 'round';
  
  // Scanning mode: 'datawedge' or 'keystroke'
  static const String _defaultScanningMode = 'keystroke';
  static String _cachedScanningMode = _defaultScanningMode;
  
  // Get scanning mode synchronously (uses cached value)
  static String get scanningMode {
    // Ensure we always return a valid value
    if (_cachedScanningMode != 'keystroke' && _cachedScanningMode != 'datawedge') {
      _cachedScanningMode = _defaultScanningMode;
    }
    return _cachedScanningMode;
  }
  
  // Load scanning mode from SharedPreferences
  static Future<void> loadScanningMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('scanningMode');
      // Validate the saved mode, default to keystroke if invalid or null
      if (savedMode == 'keystroke' || savedMode == 'datawedge') {
        _cachedScanningMode = savedMode ?? "";
      } else {
        _cachedScanningMode = _defaultScanningMode;
        // Clear invalid saved value
        if (savedMode != null) {
          await prefs.remove('scanningMode');
        }
      }
    } catch (e) {
      // If loading fails, use default
      _cachedScanningMode = _defaultScanningMode;
    }
  }
  
  // Save scanning mode to SharedPreferences
  static Future<void> setScanningMode(String mode) async {
    if (mode != 'keystroke' && mode != 'datawedge') {
      throw ArgumentError('Scanning mode must be either "keystroke" or "datawedge"');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scanningMode', mode);
    _cachedScanningMode = mode;
  }
}
