import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Soft workspace card — light border, no hard shadow (AppFlowy-like).
class MemoSnippetCard extends StatelessWidget {
  const MemoSnippetCard({
    super.key,
    required this.preview,
    required this.onTap,
    this.timestamp,
    this.pinned = false,
    this.dirty = false,
    this.isPublic = false,
    this.tags = const [],
    this.footer,
    this.leadingMeta,
  });

  final String preview;
  final VoidCallback onTap;
  final DateTime? timestamp;
  final bool pinned;
  final bool dirty;
  final bool isPublic;
  final List<String> tags;
  final Widget? footer;
  final Widget? leadingMeta;

  static String flattenPreview(String content, {int maxChars = 160}) {
    final flat = content
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[#>*_`\[\]!]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (flat.isEmpty) return '空笔记';
    if (flat.length <= maxChars) return flat;
    return '${flat.substring(0, maxChars).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.paperElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.line),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        hoverColor: AppTheme.surfaceMuted.withValues(alpha: 0.6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (pinned) ...[
                    const Icon(
                      Icons.push_pin_outlined,
                      size: 14,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (leadingMeta != null)
                    Expanded(child: leadingMeta!)
                  else if (timestamp != null)
                    Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(timestamp!),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  else
                    const Spacer(),
                  if (timestamp != null && leadingMeta == null) const Spacer(),
                  if (dirty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningSoft,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        '待同步',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  if (isPublic)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.public_outlined,
                        size: 14,
                        color: AppTheme.inkSubtle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final t in tags.take(6))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          '#$t',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 8),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.sticky_note_2_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, size: 26, color: AppTheme.inkMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.inkMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
