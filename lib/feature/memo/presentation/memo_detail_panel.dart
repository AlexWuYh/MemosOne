import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/memo.dart';

class MemoDetailPanel extends ConsumerStatefulWidget {
  const MemoDetailPanel({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<MemoDetailPanel> createState() => _MemoDetailPanelState();
}

class _MemoDetailPanelState extends ConsumerState<MemoDetailPanel> {
  final _controller = TextEditingController();
  String? _boundId;
  bool _preview = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _bind(Memo? memo) {
    if (memo == null) {
      _boundId = null;
      _controller.clear();
      return;
    }
    if (_boundId == memo.localId && _controller.text == memo.content) return;
    _boundId = memo.localId;
    _controller.text = memo.content;
  }

  Future<void> _save(Memo memo) async {
    if (_saving) return;
    final content = _controller.text;
    if (content == memo.content) return;
    setState(() => _saving = true);
    try {
      await ref.read(memoRepositoryProvider).update(
            memo.localId,
            MemoPatch(content: content),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memo = ref.watch(selectedMemoProvider);
    _bind(memo);

    if (memo == null) {
      return Center(
        child: Text(
          'Select or create a memo',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                if (widget.showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () =>
                        ref.read(selectedMemoIdProvider.notifier).state = null,
                  ),
                Expanded(
                  child: Text(
                    memo.dirty ? 'Editing · unsynced' : 'Editing',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  tooltip: _preview ? 'Edit' : 'Preview',
                  icon: Icon(_preview ? Icons.edit : Icons.visibility),
                  onPressed: () => setState(() => _preview = !_preview),
                ),
                IconButton(
                  tooltip: memo.pinned ? 'Unpin' : 'Pin',
                  icon: Icon(
                    memo.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                  onPressed: () => ref
                      .read(memoRepositoryProvider)
                      .pin(memo.localId, !memo.pinned),
                ),
                IconButton(
                  tooltip: memo.archived ? 'Unarchive' : 'Archive',
                  icon: Icon(
                    memo.archived ? Icons.unarchive : Icons.archive_outlined,
                  ),
                  onPressed: () => ref
                      .read(memoRepositoryProvider)
                      .archive(memo.localId, !memo.archived),
                ),
                IconButton(
                  tooltip: 'Attach file',
                  icon: const Icon(Icons.attach_file),
                  onPressed: () => _attach(memo),
                ),
                IconButton(
                  tooltip: 'History',
                  icon: const Icon(Icons.history),
                  onPressed: () => _showHistory(memo),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete memo?'),
                        content: const Text(
                          'It will be removed locally and queued for server delete if synced.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(memoRepositoryProvider)
                          .softDelete(memo.localId);
                      ref.read(selectedMemoIdProvider.notifier).state = null;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _preview
              ? Markdown(
                  data: _controller.text.isEmpty
                      ? '*Empty*'
                      : _controller.text,
                  selectable: true,
                  padding: const EdgeInsets.all(16),
                )
              : TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    hintText: 'Write in Markdown… #tags supported',
                  ),
                  onChanged: (_) {
                    // autosave debounce via post-frame delayed save
                    Future<void>.delayed(const Duration(milliseconds: 400), () {
                      if (!mounted) return;
                      if (_controller.text != memo.content) {
                        _save(memo);
                      }
                    });
                  },
                ),
        ),
        if (memo.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              children: memo.tags
                  .map(
                    (String t) => ActionChip(
                      label: Text('#$t'),
                      onPressed: () {
                        ref.read(memoFilterProvider.notifier).state =
                            MemoQuery(tag: t);
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _attach(Memo memo) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    if (file.size > AppConstants.attachmentWarnBytes && mounted) {
      final cont = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Large file'),
          content: Text(
            'File is ${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB '
            '(limit warn ${AppConstants.attachmentWarnBytes ~/ (1024 * 1024)} MB). Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Attach'),
            ),
          ],
        ),
      );
      if (cont != true) return;
    }
    await ref.read(memoRepositoryProvider).addLocalAttachment(
          memoLocalId: memo.localId,
          workspaceId: memo.workspaceId,
          localPath: file.path!,
          mimeType: file.extension ?? 'application/octet-stream',
          sizeBytes: file.size,
          fileName: file.name,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attached ${file.name}')),
      );
    }
  }

  Future<void> _showHistory(Memo memo) async {
    final items =
        await ref.read(memoRepositoryProvider).history(memo.localId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        if (items.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('No history yet')),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final h = items[i];
            return ListTile(
              title: Text(
                h.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${h.reason} · ${h.capturedAt}'),
              trailing: TextButton(
                onPressed: () async {
                  await ref
                      .read(memoRepositoryProvider)
                      .restoreFromHistory(h.localId);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Restore'),
              ),
            );
          },
        );
      },
    );
  }
}
