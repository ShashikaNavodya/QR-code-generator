import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/qr_brand_mark.dart';
import '../../generator/presentation/generator_page.dart';
import '../../qr_codes/data/qr_code_repository.dart';
import '../../qr_codes/data/qr_code_service.dart';
import '../../qr_codes/domain/qr_code_entry.dart';
import '../../scanner/presentation/scanner_page.dart';
import 'widgets/app_bottom_navigation.dart';
import 'widgets/qr_code_details_sheet.dart';
import 'widgets/qr_code_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _favoriteFilterKey = 'qrgen.show_favorites';
  static const _saveScansKey = 'qrgen.save_scans';

  final _repository = QrCodeRepository();
  final _qrService = QrCodeService();
  List<QrCodeEntry> _entries = [];
  int _selectedTab = 0;
  bool _loading = true;
  bool _showFavoritesOnly = false;
  bool _saveScans = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await _repository.loadRecent();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _saveScans = prefs.getBool(_saveScansKey) ?? true;
        _showFavoritesOnly = prefs.getBool(_favoriteFilterKey) ?? false;
        _loading = false;
        _loadError = null;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load your QR codes: $error';
      });
    }
  }

  Future<void> _persistEntry(QrCodeEntry entry) async {
    final updated = [
      entry,
      ..._entries.where((item) => item.id != entry.id),
    ].take(100).toList();
    await _repository.saveRecent(updated);
    if (mounted) setState(() => _entries = updated);
  }

  Future<void> _onScanned(String value) async {
    final entry = QrCodeEntry.create(
      data: value,
      type: QrContentType.scan,
      color: AppColors.cyan,
      displayName: _scanLabel(value),
      logoEnabled: false,
    );
    if (_saveScans) {
      try {
        await _persistEntry(entry);
      } on Exception catch (error) {
        if (mounted) _showMessage('Could not save scan history: $error');
      }
    }
    if (mounted) await _showScanResult(entry);
  }

  String _scanLabel(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) return uri.host;
    return value.replaceAll('\n', ' ');
  }

  Future<void> _toggleFavorite(QrCodeEntry entry) async {
    final updated = _entries
        .map(
          (item) => item.id == entry.id
              ? item.copyWith(isFavorite: !item.isFavorite)
              : item,
        )
        .toList();
    setState(() => _entries = updated);
    try {
      await _repository.saveRecent(updated);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not update saved codes: $error');
    }
  }

  Future<void> _confirmDeleteEntry(QrCodeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this code?'),
        content: const Text('This removes the code from My Codes and History.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _deleteEntry(entry);
  }

  Future<void> _deleteEntry(QrCodeEntry entry) async {
    final updated = _entries.where((item) => item.id != entry.id).toList();
    setState(() => _entries = updated);
    try {
      await _repository.saveRecent(updated);
      if (mounted) _showMessage('Code removed.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not remove code: $error');
    }
  }

  Future<void> _clearScanHistory() async {
    final scans = _entries.where((entry) => entry.type == QrContentType.scan);
    if (scans.isEmpty) {
      _showMessage('There are no scanned codes in your history.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear scan history?'),
        content: const Text(
          'This removes scanned codes from History. Your generated codes in My Codes will stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = _entries
        .where((entry) => entry.type != QrContentType.scan)
        .toList();
    setState(() => _entries = updated);
    try {
      await _repository.saveRecent(updated);
      if (mounted) _showMessage('Scan history cleared.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not clear scan history: $error');
    }
  }

  Future<void> _setSaveScans(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(_saveScansKey, value);
    if (!saved) throw StateError('Scan preference could not be saved.');
    if (mounted) setState(() => _saveScans = value);
  }

  Future<void> _setFavoriteFilter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(_favoriteFilterKey, value);
    if (!saved) throw StateError('Code filter could not be saved.');
    if (mounted) setState(() => _showFavoritesOnly = value);
  }

  Future<void> _saveCode(QrCodeEntry entry) async {
    try {
      final path = await _qrService.save(entry);
      if (mounted) _showMessage('QR code saved: $path');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not save QR code: $error');
    }
  }

  Future<void> _shareCode(QrCodeEntry entry) async {
    try {
      await _qrService.share(entry);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not share QR code: $error');
    }
  }

  Future<void> _showDetails(QrCodeEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => QrCodeDetailsSheet(
        entry: entry,
        onSave: () {
          Navigator.pop(sheetContext);
          _saveCode(entry);
        },
        onShare: () {
          Navigator.pop(sheetContext);
          _shareCode(entry);
        },
        onFavorite: entry.type == QrContentType.scan
            ? null
            : () {
                Navigator.pop(sheetContext);
                _toggleFavorite(entry);
              },
        onDelete: () {
          Navigator.pop(sheetContext);
          _confirmDeleteEntry(entry);
        },
        onOpen: _isWebLink(entry.data) ? () => _openUrl(entry.data) : null,
      ),
    );
  }

  Future<void> _showScanResult(QrCodeEntry entry) async {
    final uri = Uri.tryParse(entry.data);
    final canOpen =
        uri != null &&
        uri.hasAuthority &&
        {'http', 'https'}.contains(uri.scheme.toLowerCase());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.cyan),
        title: const Text('QR code scanned'),
        content: SelectableText(entry.data),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.data));
              Navigator.pop(context);
              _showMessage('Copied to clipboard.');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy'),
          ),
          if (canOpen)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openUrl(entry.data);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open link'),
            ),
        ],
      ),
    );
  }

  bool _isWebLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        {'http', 'https'}.contains(uri.scheme.toLowerCase());
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !_isWebLink(value)) {
      _showMessage('This QR code does not contain a web link.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showMessage('Could not open this link.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not open this link: $error');
    }
  }

  Future<void> _showMenu() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (var index = 0; index < 5; index++)
              ListTile(
                leading: Icon(_tabIcon(index), color: AppColors.cyan),
                title: Text(_tabTitle(index)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedTab = index);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  IconData _tabIcon(int index) => switch (index) {
    0 => Icons.qr_code_2_rounded,
    1 => Icons.grid_view_rounded,
    2 => Icons.center_focus_strong_rounded,
    3 => Icons.history_rounded,
    _ => Icons.settings_outlined,
  };

  String _tabTitle(int index) => switch (index) {
    0 => 'Generate',
    1 => 'My Codes',
    2 => 'Scanner',
    3 => 'History',
    _ => 'Settings',
  };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTab(int index) => setState(() => _selectedTab = index);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width > 1000 ? 620.0 : 560.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gradientStart,
              AppColors.gradientMiddle,
              AppColors.gradientEnd,
              AppColors.background,
            ],
            stops: [0, .18, .47, .8],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  Expanded(child: _buildPage()),
                  AppBottomNavigation(
                    selectedIndex: _selectedTab,
                    onSelected: _selectTab,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cyan),
      );
    }
    if (_loadError != null) {
      return _LoadError(message: _loadError!, onRetry: _loadEntries);
    }
    return switch (_selectedTab) {
      0 => GeneratorPage(
        key: const ValueKey('generator'),
        onGenerated: _persistEntry,
        onMenu: _showMenu,
        onSettings: () => _selectTab(4),
      ),
      1 => _buildCodesPage(),
      2 => ScannerPage(onScanned: _onScanned),
      3 => _buildHistoryPage(),
      _ => _buildSettingsPage(),
    };
  }

  Widget _buildCodesPage() {
    final codes = _entries.where((entry) => entry.type != QrContentType.scan);
    final visible = codes
        .where((entry) => !_showFavoritesOnly || entry.isFavorite)
        .toList();
    return _ListPage(
      title: 'MY CODES',
      subtitle: 'Your created codes, saved on this device.',
      leading: Icons.grid_view_rounded,
      action: PopupMenuButton<bool>(
        initialValue: _showFavoritesOnly,
        tooltip: 'Filter codes',
        onSelected: (value) async {
          try {
            await _setFavoriteFilter(value);
          } on Exception catch (error) {
            if (mounted) _showMessage('Could not apply filter: $error');
          }
        },
        icon: const Icon(Icons.filter_list_rounded, color: AppColors.ink),
        itemBuilder: (context) => const [
          PopupMenuItem(value: false, child: Text('All codes')),
          PopupMenuItem(value: true, child: Text('Favorites only')),
        ],
      ),
      child: visible.isEmpty
          ? _EmptyState(
              icon: Icons.qr_code_2_rounded,
              title: _showFavoritesOnly ? 'No favorites yet' : 'No codes yet',
              subtitle: _showFavoritesOnly
                  ? 'Tap the bookmark on a code to save it here.'
                  : 'Create a QR code and it will be collected here.',
              actionLabel: 'Generate a code',
              onAction: () => _selectTab(0),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(17, 10, 17, 20),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final entry = visible[index];
                return QrCodeTile(
                  entry: entry,
                  onShare: () => _shareCode(entry),
                  onDetails: () => _showDetails(entry),
                  onFavorite: () => _toggleFavorite(entry),
                );
              },
            ),
    );
  }

  Widget _buildHistoryPage() {
    final entries = [..._entries]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final grouped = <String, List<QrCodeEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.historyGroup, () => []).add(entry);
    }
    return _ListPage(
      title: 'HISTORY',
      subtitle: 'Generated and scanned QR codes.',
      leading: Icons.history_rounded,
      action: IconButton(
        tooltip: 'Clear scan history',
        onPressed: _clearScanHistory,
        icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.ink),
      ),
      child: entries.isEmpty
          ? const _EmptyState(
              icon: Icons.history_rounded,
              title: 'Nothing here yet',
              subtitle: 'The codes you create or scan will appear here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(17, 10, 17, 20),
              children: [
                for (final group in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(1, 10, 1, 8),
                    child: Text(
                      group.key.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  for (final entry in group.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: QrCodeTile(
                        entry: entry,
                        onShare: () => _shareCode(entry),
                        onDetails: () => _showDetails(entry),
                        onFavorite: entry.type == QrContentType.scan
                            ? null
                            : () => _toggleFavorite(entry),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _buildSettingsPage() {
    return _ListPage(
      title: 'SETTINGS',
      subtitle: 'Make QR Gen work the way you like.',
      leading: Icons.settings_outlined,
      action: const SizedBox(width: 8),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        children: [
          const _SettingSectionTitle('SCANNER'),
          const SizedBox(height: 7),
          _SettingCard(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.cyan,
              value: _saveScans,
              title: const Text(
                'Save scans to History',
                style: TextStyle(color: AppColors.ink, fontSize: 13),
              ),
              subtitle: const Text(
                'Keep scanned results on this device.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              onChanged: (value) async {
                try {
                  await _setSaveScans(value);
                } on Exception catch (error) {
                  if (mounted) _showMessage('Could not save setting: $error');
                }
              },
            ),
          ),
          const SizedBox(height: 17),
          const _SettingSectionTitle('DATA'),
          const SizedBox(height: 7),
          _SettingCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.orange,
              ),
              title: const Text(
                'Clear scan history',
                style: TextStyle(color: AppColors.ink, fontSize: 13),
              ),
              subtitle: const Text(
                'Your generated codes will not be removed.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              onTap: _clearScanHistory,
            ),
          ),
          const SizedBox(height: 17),
          const _SettingSectionTitle('ABOUT'),
          const SizedBox(height: 7),
          const _SettingCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: QrBrandMark(size: 31),
              title: Text(
                'QR Gen',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Private by design. Your codes stay on your device.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.action,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData leading;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 11, 11),
          child: Row(
            children: [
              Icon(leading, color: AppColors.cyan, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              action,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.cyan.withValues(alpha: .7), size: 47),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.orange, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink, fontSize: 12),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SettingSectionTitle extends StatelessWidget {
  const _SettingSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.cyan,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: child,
      ),
    );
  }
}
