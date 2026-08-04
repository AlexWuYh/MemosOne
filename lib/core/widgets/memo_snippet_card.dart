import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Shared feed/Explore card: short preview, white surface, no heavy shadow.
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
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                      Icons.push_pin_rounded,
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    const Spacer(),
                  if (timestamp != null && leadingMeta == null) const Spacer(),
                  if (dirty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '待同步',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  if (isPublic) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.public,
                      size: 14,
                      color: AppTheme.inkMuted,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags
                      .take(6)
                      .map(
                        (t) => Text(
                          '#$t',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              footer ??
                  const Text(
                    '查看全文 →',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state: short copy + one primary action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.edit_note_rounded,
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
            Icon(icon, size: 48, color: AppTheme.inkMuted.withValues(alpha: 0.7)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.inkMuted,
                  height: 1.45,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
