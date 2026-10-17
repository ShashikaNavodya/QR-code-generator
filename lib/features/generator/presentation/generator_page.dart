import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/qr_code_display.dart';
import '../../../core/widgets/qr_brand_mark.dart';
import '../../qr_codes/data/qr_code_service.dart';
import '../../qr_codes/domain/qr_code_entry.dart';

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({
    required this.onGenerated,
    required this.onMenu,
    required this.onSettings,
    super.key,
  });

  final Future<void> Function(QrCodeEntry entry) onGenerated;
  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  final _qrService = QrCodeService();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'url',
      'text',
      'name',
      'phone',
      'email',
      'organization',
      'ssid',
      'password',
      'sms',
      'message',
    ])
      key: TextEditingController(),
  };

  QrContentType _type = QrContentType.url;
  QrCodeEntry? _entry;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _fields[key]!.text.trim();

  String? _buildPayload() {
    switch (_type) {
      case QrContentType.url:
        return _value('url');
      case QrContentType.text:
        return _value('text');
      case QrContentType.contact:
        if (_value('name').isEmpty) return null;
        return [
          'BEGIN:VCARD',
          'VERSION:3.0',
          'FN:${_value('name')}',
          if (_value('organization').isNotEmpty)
            'ORG:${_value('organization')}',
          if (_value('phone').isNotEmpty) 'TEL:${_value('phone')}',
          if (_value('email').isNotEmpty) 'EMAIL:${_value('email')}',
          'END:VCARD',
        ].join('\n');
      case QrContentType.wifi:
        if (_value('ssid').isEmpty) return null;
        final security = _wifiSecurity;
        if (security != 'nopass' && _value('password').isEmpty) return null;
        return 'WIFI:T:$security;S:${_qrService.escapeWifiField(_value('ssid'))};'
            '${security == 'nopass' ? '' : 'P:${_qrService.escapeWifiField(_value('password'))};'}'
            'H:${_hiddenNetwork ? 'true' : 'false'};;';
      case QrContentType.sms:
        if (_value('sms').isEmpty) return null;
        return 'SMSTO:${_value('sms')}:${_value('message')}';
      case QrContentType.scan:
        return null;
    }
  }

  String _wifiSecurity = 'WPA';
  bool _hiddenNetwork = false;

  String get _displayName => switch (_type) {
    QrContentType.url => _value('url'),
    QrContentType.text => _value('text'),
    QrContentType.contact => _value('name'),
    QrContentType.wifi => _value('ssid'),
    QrContentType.sms => _value('sms'),
    QrContentType.scan => '',
  };

  Future<void> _generate() async {
    final payload = _buildPayload();
    if (payload == null) {
      setState(() => _error = _missingContentError);
      return;
    }
    final error = _qrService.validate(payload, _type);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final entry = QrCodeEntry.create(
      data: payload,
      type: _type,
      color: Colors.black,
      displayName: _displayName,
      logoEnabled: false,
    );
    setState(() {
      _entry = entry;
      _error = null;
      _busy = true;
    });
    try {
      await widget.onGenerated(entry);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not save to your history: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _missingContentError => switch (_type) {
    QrContentType.contact when _value('name').isEmpty =>
      'Enter a contact name.',
    QrContentType.wifi when _value('ssid').isEmpty =>
      'Enter the Wi-Fi network name.',
    QrContentType.wifi
        when _wifiSecurity != 'nopass' && _value('password').isEmpty =>
      'Enter the Wi-Fi password or select Open.',
    QrContentType.sms when _value('sms').isEmpty => 'Enter a phone number.',
    _ => 'Add some content to create your QR code.',
  };

  void _invalidateEntry() {
    if (_entry == null && _error == null) return;
    setState(() {
      _entry = null;
      _error = null;
    });
  }

  Future<void> _pasteUrl() async {
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final url = clipboard?.text?.trim();
      if (url == null || url.isEmpty) {
        _showMessage('There is no URL in the clipboard.');
        return;
      }
      final controller = _fields['url']!;
      controller.value = TextEditingValue(
        text: url,
        selection: TextSelection.collapsed(offset: url.length),
      );
      _invalidateEntry();
    } on PlatformException catch (error) {
      _showMessage('Could not paste from the clipboard: ${error.message}');
    }
  }

  Future<void> _save() async {
    final entry = _entry;
    if (entry == null) return;
    setState(() => _busy = true);
    try {
      final path = await _qrService.save(entry);
      if (mounted) _showMessage('QR code saved: $path');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not save QR code: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final entry = _entry;
    if (entry == null) return;
    setState(() => _busy = true);
    try {
      await _qrService.share(entry);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not share QR code: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectType(QrContentType type) {
    setState(() {
      _type = type;
      _entry = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Column(
      children: [
        _GeneratorHeader(onMenu: widget.onMenu, onSettings: widget.onSettings),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 7, 18, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'GENERATE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildEditor()),
                          const SizedBox(width: 22),
                          Expanded(child: _buildQrPreview()),
                        ],
                      )
                    else ...[
                      _buildQrPreview(),
                      const SizedBox(height: 6),
                      _buildEditor(),
                    ],
                    const SizedBox(height: 12),
                    if (_entry != null) _buildExportActions(),
                    if (_entry == null)
                      const Text(
                        'Your plain black-and-white QR code appears here after you create it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrPreview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 202,
          height: 202,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF10243A),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: AppColors.cyan.withValues(alpha: .35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: .12),
                blurRadius: 25,
                spreadRadius: 1,
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _entry == null
                  ? const Icon(
                      Icons.qr_code_2_rounded,
                      color: Color(0xFFB3C1D2),
                      size: 118,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(5),
                      child: QrCodeDisplay(data: _entry!.data),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _entry == null ? 'QR CODE PREVIEW' : _entry!.title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldCaption('ENTER YOUR CONTENT'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          children: [
            for (final (type, label, icon) in [
              (QrContentType.url, 'URL', Icons.link_rounded),
              (QrContentType.text, 'TEXT', Icons.notes_rounded),
              (QrContentType.contact, 'CONTACT', Icons.badge_outlined),
              (QrContentType.wifi, 'WI-FI', Icons.wifi_rounded),
              (QrContentType.sms, 'SMS', Icons.chat_bubble_outline_rounded),
            ])
              _TypeButton(
                label: label,
                icon: icon,
                selected: _type == type,
                onTap: () => _selectType(type),
              ),
          ],
        ),
        const SizedBox(height: 9),
        ..._buildInputFields(),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFFF8B85), fontSize: 11),
          ),
        ],
        const SizedBox(height: 11),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.blue, AppColors.purple],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: .27),
                  blurRadius: 16,
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
              label: Text(
                _entry == null ? 'GENERATE QR' : 'GENERATE AGAIN',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .35,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInputFields() {
    switch (_type) {
      case QrContentType.url:
        return [
          _input(
            'url',
            'https://www.example.com',
            keyboard: TextInputType.url,
            suffixIcon: IconButton(
              onPressed: _pasteUrl,
              icon: const Icon(Icons.content_paste_rounded),
              tooltip: 'Paste URL',
            ),
          ),
        ];
      case QrContentType.text:
        return [_input('text', 'Type your message', maxLines: 2)];
      case QrContentType.contact:
        return [
          _input('name', 'Full name'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _input('phone', 'Phone', keyboard: TextInputType.phone),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _input(
                  'email',
                  'Email',
                  keyboard: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _input('organization', 'Company (optional)'),
        ];
      case QrContentType.wifi:
        return [
          _input('ssid', 'Network name (SSID)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _input('password', 'Password', obscure: true)),
              const SizedBox(width: 7),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _wifiSecurity,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
                    DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                    DropdownMenuItem(value: 'nopass', child: Text('Open')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _wifiSecurity = value);
                      _invalidateEntry();
                    }
                  },
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AppColors.cyan,
            title: const Text(
              'Hidden network',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            value: _hiddenNetwork,
            onChanged: (value) {
              setState(() => _hiddenNetwork = value);
              _invalidateEntry();
            },
          ),
        ];
      case QrContentType.sms:
        return [
          _input('sms', 'Phone number', keyboard: TextInputType.phone),
          const SizedBox(height: 6),
          _input('message', 'Message (optional)', maxLines: 2),
        ];
      case QrContentType.scan:
        return const [];
    }
  }

  Widget _input(
    String key,
    String hint, {
    TextInputType? keyboard,
    bool obscure = false,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: _fields[key],
      keyboardType: keyboard,
      obscureText: obscure,
      minLines: maxLines,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.ink, fontSize: 12),
      onChanged: (_) => _invalidateEntry(),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildExportActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share_outlined, size: 17),
          label: const Text('SHARE'),
        ),
        const SizedBox(width: 24),
        TextButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.download_outlined, size: 17),
          label: const Text('SAVE'),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _busy
              ? null
              : () async {
                  final entry = _entry;
                  if (entry == null) return;
                  await widget.onGenerated(entry.copyWith(isFavorite: true));
                  if (mounted) _showMessage('Added to My Codes.');
                },
          icon: const Icon(Icons.bookmark_add_outlined),
          tooltip: 'Add to My Codes',
        ),
      ],
    );
  }
}

class _GeneratorHeader extends StatelessWidget {
  const _GeneratorHeader({required this.onMenu, required this.onSettings});

  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 4, 13, 3),
      child: SizedBox(
        height: 45,
        child: Row(
          children: [
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded, color: AppColors.ink),
              tooltip: 'Open menu',
            ),
            const Spacer(),
            const QrBrandMark(size: 26),
            const SizedBox(width: 6),
            const Text(
              'QR Gen',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onSettings,
              icon: const Icon(
                Icons.account_circle_outlined,
                color: AppColors.ink,
              ),
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 57,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: .25),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}
