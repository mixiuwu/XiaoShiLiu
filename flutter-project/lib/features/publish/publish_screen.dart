import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/neon_decorations.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../data/models/music.dart';
import '../../data/repositories/post_repository.dart';

final _categoriesProvider = FutureProvider.autoDispose<List<Category>>(
    (ref) => ref.watch(postRepositoryProvider).categories());

final _hotMusicsProvider = FutureProvider.autoDispose<List<Music>>(
    (ref) => ref.watch(musicRepositoryProvider).hot(limit: 20));

/// 发布页：选素材 → 上传 → 填信息 → 发布 / 存草稿。
class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();

  int _type = 2; // 2 视频 / 1 图文
  final List<File> _images = [];
  File? _video;

  Category? _category;
  Music? _music;

  bool _withPoll = false;
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    _pollQuestion.dispose();
    for (final o in _pollOptions) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePickerHelper.pickImages();
    if (picked.isEmpty) return;
    setState(() {
      _type = 1;
      _video = null;
      _images
        ..clear()
        ..addAll(picked.map((e) => File(e.path)));
    });
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePickerHelper.pickVideo();
    if (picked == null) return;
    final size = await ImagePickerHelper.sizeOf(picked);
    if (size > ImagePickerHelper.maxVideoBytes) {
      _toast('视频超过 100MB 限制');
      return;
    }
    setState(() {
      _type = 2;
      _images.clear();
      _video = File(picked.path);
    });
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _submit({required int status}) async {
    if (_submitting) return;
    if (_type == 2 && _video == null) return _toast('请先选择视频');
    if (_type == 1 && _images.isEmpty) return _toast('请先选择图片');
    final title = _title.text.trim();
    if (title.isEmpty) return _toast('请填写标题');

    setState(() => _submitting = true);
    try {
      final upload = ref.read(uploadRepositoryProvider);
      final posts = ref.read(postRepositoryProvider);

      List<String>? images;
      Map<String, dynamic>? video;
      if (_type == 2) {
        final v = await upload.video(_video!);
        video = {'url': v.url, if (v.coverUrl != null) 'coverUrl': v.coverUrl};
      } else {
        images = await upload.images(_images);
      }

      final tags = _tags.text
          .split(RegExp(r'[,\s#]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(5)
          .toList();

      Map<String, dynamic>? poll;
      if (_withPoll) {
        final q = _pollQuestion.text.trim();
        final opts = _pollOptions
            .map((e) => e.text.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (q.isNotEmpty && opts.length >= 2) {
          poll = {'question': q, 'options': opts, 'duration_hours': 0};
        }
      }

      final id = await posts.create(
        title: title,
        content: _content.text.trim(),
        type: _type,
        status: status,
        categoryId: _category?.id,
        images: images,
        video: video,
        tags: tags.isEmpty ? null : tags,
        musicId: _music?.id,
        poll: poll,
      );

      if (!mounted) return;
      _toast(status == 1 ? '已存草稿' : '发布成功');
      if (id > 0 && status == 0) {
        context.pushReplacement('/player/$id');
      } else {
        context.pop();
      }
    } catch (e) {
      _toast('发布失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('发布'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/feed'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _typeSwitch(),
              const SizedBox(height: 16),
              _mediaPicker(),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '正文'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: '标签（空格或逗号分隔，最多5个）',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 12),
              _categoryTile(),
              _musicTile(),
              const SizedBox(height: 12),
              _pollSection(),
              const SizedBox(height: 24),
              NeonButton(
                label: '发布',
                loading: _submitting,
                onPressed: () => _submit(status: 0),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting ? null : () => _submit(status: 1),
                icon: const Icon(Icons.save_outlined),
                label: const Text('存草稿'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSwitch() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 2, label: Text('视频'), icon: Icon(Icons.videocam)),
        ButtonSegment(
            value: 1, label: Text('图文'), icon: Icon(Icons.photo_library)),
      ],
      selected: {_type},
      onSelectionChanged: (s) => setState(() => _type = s.first),
    );
  }

  Widget _mediaPicker() {
    return GestureDetector(
      onTap: _type == 2 ? _pickVideo : _pickImages,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: _preview(),
      ),
    );
  }

  Widget _preview() {
    if (_type == 2) {
      if (_video == null) return _pickHint(Icons.videocam_outlined, '点击选择视频');
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(
              color: AppColors.surfaceAlt,
              child: Center(
                  child: Icon(Icons.play_circle_outline,
                      size: 48, color: AppColors.primary)),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(
                _video!.path.split(Platform.pathSeparator).last,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    if (_images.isEmpty) {
      return _pickHint(Icons.add_photo_alternate_outlined, '点击选择图片');
    }
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(6),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: _images
          .map((f) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(f, fit: BoxFit.cover),
              ))
          .toList(),
    );
  }

  Widget _pickHint(IconData icon, String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 42, color: AppColors.textTertiary),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _categoryTile() {
    final cats = ref.watch(_categoriesProvider);
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: () async {
        final list = cats.valueOrNull ?? const [];
        if (list.isEmpty) return _toast('分类加载中或为空');
        final picked = await showModalBottomSheet<Category>(
          context: context,
          backgroundColor: AppColors.surface,
          builder: (_) => ListView(
            children: list
                .map((c) => ListTile(
                      title: Text(c.name,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      onTap: () => Navigator.pop(context, c),
                    ))
                .toList(),
          ),
        );
        if (picked != null) setState(() => _category = picked);
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.category_outlined, color: AppColors.cyan),
        title: Text(
          _category?.name ?? '选择分类',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _musicTile() {
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: () async {
        final musics = ref.read(_hotMusicsProvider).valueOrNull ?? const [];
        if (musics.isEmpty) return _toast('暂无音乐');
        final picked = await showModalBottomSheet<Music>(
          context: context,
          backgroundColor: AppColors.surface,
          builder: (_) => ListView(
            children: musics
                .map((m) => ListTile(
                      title: Text(m.title,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: m.author != null
                          ? Text(m.author!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary))
                          : null,
                      onTap: () => Navigator.pop(context, m),
                    ))
                .toList(),
          ),
        );
        if (picked != null) setState(() => _music = picked);
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.audiotrack, color: AppColors.purple),
        title: Text(
          _music != null ? '原声：${_music!.title}' : '选择背景音乐',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing: _music == null
            ? const Icon(Icons.chevron_right, color: AppColors.textTertiary)
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.textTertiary),
                onPressed: () => setState(() => _music = null),
              ),
      ),
    );
  }

  Widget _pollSection() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('添加投票（可选）',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
              ),
              Switch(
                value: _withPoll,
                onChanged: (v) => setState(() => _withPoll = v),
              ),
            ],
          ),
          if (_withPoll) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _pollQuestion,
              decoration: const InputDecoration(labelText: '投票问题'),
            ),
            const SizedBox(height: 8),
            ...List.generate(_pollOptions.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _pollOptions[i],
                  decoration: InputDecoration(
                    labelText: '选项 ${i + 1}',
                    suffixIcon: _pollOptions.length > 2
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(
                                () => _pollOptions.removeAt(i).dispose()),
                          )
                        : null,
                  ),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _pollOptions.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('添加选项'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
