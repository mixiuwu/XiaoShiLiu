import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/neon_decorations.dart';

/// 注册页：小石榴号唯一性校验 + 确认密码 + 可选邮箱验证码。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _email = TextEditingController();
  final _emailCode = TextEditingController();

  bool _emailEnabled = false;
  bool _obscure = true;
  String? _userIdHint;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmailConfig();
    });
  }

  @override
  void dispose() {
    _userId.dispose();
    _nickname.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _email.dispose();
    _emailCode.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmailConfig() async {
    try {
      final enabled = await ref.read(authRepositoryProvider).isEmailEnabled();
      if (mounted) setState(() => _emailEnabled = enabled);
    } catch (_) {
      // 忽略：默认关闭邮箱字段
    }
  }

  Future<void> _checkUserId() async {
    final id = _userId.text.trim();
    if (id.isEmpty) {
      setState(() => _userIdHint = '请输入小石榴号');
      return;
    }
    try {
      final ok = await ref.read(authRepositoryProvider).isUserIdAvailable(id);
      if (mounted) {
        setState(() => _userIdHint = ok ? null : '该小石榴号已被占用');
      }
    } catch (_) {
      if (mounted) setState(() => _userIdHint = null);
    }
  }

  Future<void> _sendEmailCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _toast('请先输入邮箱地址');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendEmailCode(email);
      if (!mounted) return;
      _toast('验证码已发送，请查收邮箱');
      setState(() => _codeCountdown = 60);
      _codeTimer?.cancel();
      _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_codeCountdown <= 1) {
            _codeCountdown = 0;
            timer.cancel();
          } else {
            _codeCountdown--;
          }
        });
      });
    } catch (_) {
      if (mounted) _toast('验证码发送失败，请稍后重试');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).register(
          userId: _userId.text.trim(),
          nickname: _nickname.text.trim(),
          password: _password.text,
          email: _emailEnabled ? _email.text.trim() : null,
          emailCode: _emailEnabled ? _emailCode.text.trim() : null,
        );
    if (!ok && mounted) {
      final err = ref.read(authControllerProvider).error;
      _toast(err ?? '注册失败');
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).busy;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('注册小石榴'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _userId,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '小石榴号',
                        helperText: _userIdHint,
                        helperStyle: const TextStyle(color: AppColors.danger),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入小石榴号' : null,
                      onEditingComplete: _checkUserId,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nickname,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '昵称',
                        prefixIcon:
                            Icon(Icons.face_retouching_natural_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入昵称' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: '密码（至少 6 位）',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? '密码至少 6 位' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: '确认密码',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请再次输入密码';
                        if (v != _password.text) return '两次输入的密码不一致';
                        return null;
                      },
                    ),
                    if (_emailEnabled) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (!_emailEnabled) return null;
                          if (value == null || value.trim().isEmpty) {
                            return '请输入邮箱地址';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: '邮箱（用于验证与找回密码）',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailCode,
                              validator: (value) {
                                if (!_emailEnabled) return null;
                                if (value == null || value.trim().isEmpty) {
                                  return '请输入邮箱验证码';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: '邮箱验证码',
                                prefixIcon:
                                    Icon(Icons.mark_email_read_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextButton(
                              onPressed:
                                  _codeCountdown > 0 ? null : _sendEmailCode,
                              child: Text(
                                _codeCountdown > 0
                                    ? '${_codeCountdown}s'
                                    : '获取验证码',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    NeonButton(
                      label: '注册并登录',
                      loading: busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('已有账号？',
                            style: TextStyle(color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('去登录',
                              style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
