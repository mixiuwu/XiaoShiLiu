import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/neon_decorations.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/image_picker_helper.dart';
import '../profile/profile_providers.dart';

/// 编辑资料（`/edit-profile`）：头像 / 昵称 / 简介 / 所在地 / 性别 / 兴趣标签。
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nickname;
  late final TextEditingController _bio;
  late final TextEditingController _location;
  late final TextEditingController _interests;

  late String? _gender;
  String? _avatarRaw; // 变更后的头像地址（发送给后端）
  bool _saving = false;
  bool _uploading = false;
  bool _emailEnabled = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nickname = TextEditingController(text: user?.nickname ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _location = TextEditingController(text: user?.location ?? '');
    _interests = TextEditingController(text: user?.interests.join(' ') ?? '');
    _gender = user?.gender;
    _avatarRaw = null; // 未改动则不提交头像

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final enabled = await ref.read(authRepositoryProvider).isEmailEnabled();
        if (mounted) setState(() => _emailEnabled = enabled);
      } catch (_) {
        // 获取失败时隐藏邮箱入口
      }
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _location.dispose();
    _interests.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePickerHelper.pickImages(max: 1);
    if (picked.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(uploadRepositoryProvider)
          .image(File(picked.first.path));
      if (mounted) setState(() => _avatarRaw = url);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('头像上传失败：${e.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('头像上传失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('昵称不能为空')));
      return;
    }
    final account = ref.read(authControllerProvider).user?.account;
    if (account == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
            account,
            nickname: nickname,
            avatar: _avatarRaw,
            bio: _bio.text.trim(),
            location: _location.text.trim(),
            gender: _gender,
            interests: _parseInterests(),
          );
      final fresh = await ref.read(userRepositoryProvider).detail(account);
      ref.read(authControllerProvider.notifier).setUser(fresh);
      ref.invalidate(userDetailProvider(account));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('资料已更新')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：${e.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseInterests() {
    return _interests.text
        .split(RegExp(r'[,，\s]+'))
        .where((s) => s.isNotEmpty)
        .take(10)
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openBindEmailDialog() async {
    final user = ref.read(authControllerProvider).user;
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final codeCtrl = TextEditingController();
    bool sending = false;
    bool binding = false;
    int countdown = 0;
    Timer? timer;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendCode() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) {
                _toast('请先输入邮箱地址');
                return;
              }
              setDialogState(() => sending = true);
              try {
                await ref.read(authRepositoryProvider).sendEmailCode(email);
                if (!dialogContext.mounted) return;
                setDialogState(() => countdown = 60);
                timer?.cancel();
                timer = Timer.periodic(const Duration(seconds: 1), (t) {
                  if (!dialogContext.mounted) {
                    t.cancel();
                    return;
                  }
                  setDialogState(() {
                    if (countdown <= 1) {
                      countdown = 0;
                      t.cancel();
                    } else {
                      countdown--;
                    }
                  });
                });
                _toast('验证码已发送，请查收邮箱');
              } catch (e) {
                _toast(e is ApiException ? e.message : '验证码发送失败，请稍后重试');
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => sending = false);
                }
              }
            }

            Future<void> submit() async {
              final email = emailCtrl.text.trim();
              final code = codeCtrl.text.trim();
              if (email.isEmpty || code.isEmpty) {
                _toast('请输入邮箱和验证码');
                return;
              }
              setDialogState(() => binding = true);
              try {
                await ref
                    .read(authRepositoryProvider)
                    .bindEmail(email: email, emailCode: code);
                final fresh = await ref.read(authRepositoryProvider).fetchMe();
                ref.read(authControllerProvider.notifier).setUser(fresh);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _toast('邮箱绑定成功');
              } catch (e) {
                _toast(e is ApiException ? e.message : '绑定失败，请稍后重试');
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => binding = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('绑定邮箱', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '邮箱地址',
                      hintText: 'name@example.com',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          decoration:
                              const InputDecoration(labelText: '邮箱验证码'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: sending || countdown > 0 ? null : sendCode,
                        child: Text(
                          countdown > 0
                              ? '${countdown}s'
                              : (sending ? '发送中...' : '获取验证码'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '验证码 10 分钟内有效',
                      style:
                          TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: binding
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: binding ? null : submit,
                  child: Text(binding ? '提交中...' : '确认绑定'),
                ),
              ],
            );
          },
        );
      },
    );

    timer?.cancel();
    emailCtrl.dispose();
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final avatarRaw = _avatarRaw ?? user?.avatar ?? '';
    final display = avatarRaw.isEmpty
        ? ''
        : (avatarRaw.startsWith('http')
            ? avatarRaw
            : AppConfig.resolveMedia(avatarRaw));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('编辑资料')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploading ? null : _pickAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: display.isEmpty
                          ? const _AvatarFallback()
                          : CachedNetworkImage(
                              imageUrl: display,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const _AvatarFallback(),
                            ),
                    ),
                    if (_uploading)
                      const SizedBox(
                        width: 88,
                        height: 88,
                        child: Center(
                          child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary)),
                        ),
                      ),
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.photo_camera,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('点击更换头像',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ),
            const SizedBox(height: 24),
            _field('昵称', _nickname, maxLength: 20),
            _field('简介', _bio, maxLines: 3, maxLength: 120, hint: '介绍一下你自己吧'),
            _field('所在地', _location, maxLength: 30, hint: '如：四川 成都'),
            _field('兴趣标签', _interests, maxLines: 2, hint: '空格或逗号分隔，最多 10 个'),
            if (_emailEnabled) ...[
              const SizedBox(height: 4),
              NeonCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('邮箱',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            user?.email?.isNotEmpty == true
                                ? user!.email!
                                : '未绑定邮箱',
                            style: TextStyle(
                              color: user?.email?.isNotEmpty == true
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _openBindEmailDialog,
                      child: Text(user?.email?.isNotEmpty == true ? '换绑' : '绑定'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('性别',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: const ['男', '女', '其他']
                        .map((g) => ChoiceChip(
                              label: Text(g),
                              selected: _gender == g,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                  color: _gender == g
                                      ? Colors.white
                                      : AppColors.textSecondary),
                              onSelected: (_) => setState(() => _gender = g),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            NeonButton(
              label: '保存',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, int? maxLength, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeonCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: maxLines,
              maxLength: maxLength,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Icon(Icons.person, size: 48, color: AppColors.textTertiary),
    );
  }
}
