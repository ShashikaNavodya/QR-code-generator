import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/qr_code_entry.dart';

class QrCodeRepository {
  static const _storageKey = 'quick_qr.recent_codes';

  Future<List<QrCodeEntry>> loadRecent() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return [];

    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => QrCodeEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRecent(List<QrCodeEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    final saved = await preferences.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('Recent QR codes could not be saved on this device.');
    }
  }
}
