import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/qr_code_display.dart';
import '../../../qr_codes/domain/qr_code_entry.dart';

class QrCodeDetailsSheet extends StatelessWidget {
  const QrCodeDetailsSheet({
    required this.entry,
    required this.onSave,
    required this.onShare,
    required this.onDelete,
    this.onFavorite,
    this.onOpen,
    super.key,
  });

  final QrCodeEntry entry;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback? onFavorite;
  final VoidCallback onDelete;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              entry.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Container(
              width: 164,
              height: 164,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: QrCodeDisplay(data: entry.data),
            ),
            const SizedBox(height: 14),
            _DetailRow(label: 'Content', value: entry.data),
            const SizedBox(height: 7),
            _DetailRow(label: 'Created', value: entry.createdLabel),
            const SizedBox(height: 17),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 9,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Save PNG'),
                ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share'),
                ),
                if (onFavorite != null)
                  OutlinedButton.icon(
                    onPressed: onFavorite,
                    icon: Icon(
                      entry.isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 16,
                    ),
                    label: Text(entry.isFavorite ? 'Saved' : 'Save code'),
                  ),
                if (onOpen != null)
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open link'),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            maxLines: 4,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
