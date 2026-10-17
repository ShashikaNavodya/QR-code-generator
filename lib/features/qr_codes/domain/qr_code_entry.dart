import 'package:flutter/material.dart';

enum QrContentType { url, text, contact, wifi, sms, scan }

class QrCodeEntry {
  const QrCodeEntry({
    required this.id,
    required this.data,
    required this.type,
    required this.createdAt,
    required this.colorValue,
    this.displayName = '',
    this.isFavorite = false,
    this.logoEnabled = true,
  });

  final String id;
  final String data;
  final QrContentType type;
  final DateTime createdAt;
  final int colorValue;
  final String displayName;
  final bool isFavorite;
  final bool logoEnabled;

  Color get color => Color(colorValue);

  String get title => switch (type) {
    QrContentType.url => 'Website URL',
    QrContentType.text => 'Text Message',
    QrContentType.contact => 'Contact Card',
    QrContentType.wifi => 'Wi-Fi Network',
    QrContentType.sms => 'SMS Message',
    QrContentType.scan => 'Scanned Code',
  };

  String get subtitle {
    if (type == QrContentType.url) {
      final uri = Uri.tryParse(data);
      if (uri != null && uri.host.isNotEmpty) return uri.host;
    }
    if (displayName.isNotEmpty) return displayName;
    return data.replaceAll('\n', ' ');
  }

  factory QrCodeEntry.create({
    required String data,
    required QrContentType type,
    required Color color,
    String displayName = '',
    bool logoEnabled = true,
  }) {
    final now = DateTime.now();
    return QrCodeEntry(
      id: '${now.microsecondsSinceEpoch}',
      data: data,
      type: type,
      createdAt: now,
      colorValue: color.toARGB32(),
      displayName: displayName,
      logoEnabled: logoEnabled,
    );
  }

  QrCodeEntry copyWith({bool? isFavorite}) => QrCodeEntry(
    id: id,
    data: data,
    type: type,
    createdAt: createdAt,
    colorValue: colorValue,
    displayName: displayName,
    isFavorite: isFavorite ?? this.isFavorite,
    logoEnabled: logoEnabled,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'data': data,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'colorValue': colorValue,
    'displayName': displayName,
    'isFavorite': isFavorite,
    'logoEnabled': logoEnabled,
  };

  factory QrCodeEntry.fromJson(Map<String, dynamic> json) {
    return QrCodeEntry(
      id: json['id'] as String,
      data: json['data'] as String,
      type: QrContentType.values.byName(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      colorValue: json['colorValue'] as int,
      displayName: json['displayName'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      logoEnabled: json['logoEnabled'] as bool? ?? true,
    );
  }

  String get createdLabel {
    final now = DateTime.now();
    final date = createdAt;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String get historyGroup {
    final now = DateTime.now();
    if (createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (createdAt.year == yesterday.year &&
        createdAt.month == yesterday.month &&
        createdAt.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }
}
