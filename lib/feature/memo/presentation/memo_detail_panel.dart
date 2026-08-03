import 'dart:async';

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
  final _scrollController = ScrollController();
  String? _boundId;
  String _boundContent = '';
  bool _preview = true;
  bool _saving = false;
  Timer? _autosaveTimer;
  ProviderSubscription<Memo?>? _memoSub;

  @override
  void initState() {
    super.initState();
    _memoSub = ref.listenManual<Memo?>(selectedMemoProvider, (prev, next) {
      _onMemoChanged(next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onMemoChanged(ref.read(selectedMemoProvider));
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _memoSub?.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMemoChanged(Memo? memo) {
    _autosaveTimer?.cancel();
    if (memo == null) {
      _boundId = null;
      _boundContent = '';
      if (_controller.text.isNotEmpty) _controller.clear();
      if (mounted) setState(() => _preview = true);
      return;
    }
    if (_boundId == memo.localId && _controller.text == memo.content) {
      _boundContent = memo.content;
      return;
    }
    final previousId = _boundId;
    final previousBound = _boundContent;
    final draft = _controller.text;
    if (previousId != null &&
        previousId != memo.localId &&
        draft != previousBound) {
      unawaited(
        _saveById(
          previousId,
          draft,
          expectedContent: previousBound,
          enterPreview: false,
        ),
      );
    }
    _boundId = memo.localId;
    _boundContent = memo.content;
    _controller.value = TextEditingValue(
      text: memo.content,
      selection: TextSelection.collapsed(offset: memo.content.length),
    );
    // New empty memo starts in edit mode; existing content shows markdown.
    if (mounted) {
      setState(() => _preview = memo.content.trim().isNotEmpty);
    }
  }

  Future<void> _saveById(
    String localId,
    String content, {
    required String expectedContent,
    bool enterPreview = true,
  }) async {
    if (content == expectedContent) {
      if (enterPreview && mounted) setState(() => _preview = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(memoRepositoryProvider).update(
            localId,
            MemoPatch(content: content),
          );
      if (_boundId == localId) {
        _boundContent = content;
      }
      if (enterPreview && mounted && _boundId == localId) {
        setState(() => _preview = true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _scheduleAutosave(Memo memo) {
    _autosaveTimer?.cancel();
    // Typing → leave preview so user sees raw markdown while editing.
    if (_preview) setState(() => _preview = false);
    final localId = memo.localId;
    final expected = _boundContent;
    _autosaveTimer = Timer(
      const Duration(milliseconds: AppConstants.autosaveDebounceMs),
      () {
        if (!mounted) return;
        if (_boundId != localId) return;
        final content = _controller.text;
        if (content == expected) return;
        unawaited(
          _saveById(
            localId,
            content,
            expectedContent: expected,
            enterPreview: true,
          ),
        );
      },
    );
  }

  Future<void> _manualSave(Memo memo) async {
    _autosaveTimer?.cancel();
    await _saveById(
      memo.localId,
      _controller.text,
      expectedContent: _boundContent,
      enterPreview: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final memo = ref.watch(selectedMemoProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final allowAttach = workspace == null || workspace.isLocal;
    final scheme = Theme.of(context).colorScheme;

    if (memo == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              '选择或新建一条笔记',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(
            children: [
              if (widget.showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () =>
                      ref.read(selectedMemoIdProvider.notifier).state = null,
                ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('编辑'),
                    icon: Icon(Icons.edit_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('预览'),
                    icon: Icon(Icons.visibility_outlined, size: 16),
                  ),
                ],
                selected: {_preview},
                onSelectionChanged: (s) async {
                  if (s.first) {
                    await _manualSave(memo);
                  } else {
                    setState(() => _preview = false);
                  }
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              if (_saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  memo.dirty ? '已保存 · 待同步' : '已保存',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              const Spacer(),
              PopupMenuButton<MemoVisibility>(
                tooltip: '可见性',
                initialValue: memo.visibility,
                onSelected: (v) {
                  ref.read(memoRepositoryProvider).update(
                        memo.localId,
                        MemoPatch(visibility: v),
                      );
                },
                itemBuilder: (ctx) => [
                  for (final v in MemoVisibility.values)
                    PopupMenuItem(
                      value: v,
                      child: Text(v.name.toUpperCase()),
                    ),
                ],
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.public, size: 16),
                  label: Text(memo.visibility.name.toUpperCase()),
                ),
              ),
              IconButton(
                tooltip: memo.pinned ? '取消置顶' : '置顶',
                icon: Icon(
                  memo.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                ),
                onPressed: () => ref
                    .read(memoRepositoryProvider)
                    .pin(memo.localId, !memo.pinned),
              ),
              IconButton(
                tooltip: memo.archived ? '取消归档' : '归档',
                icon: Icon(
                  memo.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                onPressed: () => ref
                    .read(memoRepositoryProvider)
                    .archive(memo.localId, !memo.archived),
              ),
              if (allowAttach)
                IconButton(
                  tooltip: '附件（仅本地工作区）',
                  icon: const Icon(Icons.attach_file_rounded),
                  onPressed: () => _attach(memo),
                ),
              IconButton(
                tooltip: '历史版本',
                icon: const Icon(Icons.history_rounded),
                onPressed: () => _showHistory(memo),
              ),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除笔记？'),
                      content: const Text('将从本地删除，并在联网后同步到服务器。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    _autosaveTimer?.cancel();
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
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        Expanded(
          child: _preview
              ? Markdown(
                  controller: _scrollController,
                  data: _controller.text.isEmpty
                      ? '*空笔记 — 切换到编辑开始书写*'
                      : _controller.text,
                  selectable: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                    p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                        ),
                    h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    blockquoteDecoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: scheme.primary, width: 3),
                      ),
                    ),
                  ),
                  )
              : TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const [
                          'Monaco',
                          'Consolas',
                          'monospace',
                        ],
                        fontSize: 14.5,
                      ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                    hintText: '用 Markdown 书写… 支持 #标签\n停顿后自动保存并渲染预览',
                  ),
                  onChanged: (_) => _scheduleAutosave(memo),
                ),
        ),
        if (memo.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: memo.tags
                  .map(
                    (String t) => ActionChip(
                      label: Text('#$t'),
                      visualDensity: VisualDensity.compact,
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
          title: const Text('大文件'),
          content: Text(
            '文件约 ${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB，是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('附加'),
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
        SnackBar(content: Text('已附加 ${file.name}')),
      );
    }
  }

  Future<void> _showHistory(Memo memo) async {
    final items =
        await ref.read(memoRepositoryProvider).history(memo.localId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (items.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('暂无历史版本')),
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
                child: const Text('恢复'),
              ),
            );
          },
        );
      },
    );
  }
}
