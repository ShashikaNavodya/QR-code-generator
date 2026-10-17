import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/qr_code_display.dart';
import '../../../qr_codes/domain/qr_code_entry.dart';

class QrCodeTile extends StatelessWidget {
  const QrCodeTile({
    required this.entry,
    required this.onShare,
    required this.onDetails,
    this.onFavorite,
    super.key,
  });

  final QrCodeEntry entry;
  final VoidCallback onShare;
  final VoidCallback onDetails;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrCodeDisplay(data: entry.data),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                const SizedBox(height: 1),
                Text(
                  entry.createdLabel,
                  style: const TextStyle(color: AppColors.muted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          if (onFavorite != null)
            _TileAction(
              icon: entry.isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: 'Save',
              color: entry.isFavorite ? AppColors.cyan : AppColors.ink,
              onPressed: onFavorite!,
            ),
          _TileAction(
            icon: Icons.share_outlined,
            label: 'Share',
            onPressed: onShare,
          ),
          _TileAction(
            icon: Icons.info_outline_rounded,
            label: 'Details',
            onPressed: onDetails,
          ),
        ],
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 27, height: 27),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: color,
            ),
            icon: Icon(icon, size: 14),
            tooltip: label,
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 7),
          ),
        ],
      ),
    );
  }
}
