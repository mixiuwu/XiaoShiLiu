import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/_json.dart';
import '../models/auth.dart';
import '_paged.dart';

/// 视频上传结果（含封面）。
class VideoUploadResult {
  final String url;
  final String? coverUrl;

  const VideoUploadResult({required this.url, this.coverUrl});
}

/// 文件上传：单图 / 多图 / 视频（带可选封面）。
class UploadRepository {
  final ApiClient client;

  UploadRepository(this.client);

  /// 上传单张图片，返回图床绝对地址。
  Future<String> image(File file) async {
    final data = await client.upload(
      Endpoints.uploadSingle,
      field: 'file',
      file: file,
    );
    return UploadResult.fromJson(data).firstUrl;
  }

  /// 上传多张图片（≤9），返回地址列表。
  /// multiple 接口返回 `{success, data:{uploaded:[{url}]}}`（无 code 封装）。
  Future<List<String>> images(List<File> files) async {
    final raw = await client.uploadFiles(
      Endpoints.uploadMultiple,
      field: 'files',
      files: files,
    );
    final body = asDataMap(raw);
    final inner = body['data'] ?? body;
    return UploadResult.fromJson(inner).urls;
  }

  /// 上传视频，可同时附带封面图。
  Future<VideoUploadResult> video(File video, {File? thumbnail}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(video.path),
      if (thumbnail != null)
        'thumbnail': await MultipartFile.fromFile(thumbnail.path),
    });
    final data = await client.post(Endpoints.uploadVideo, data: formData);
    final m = asDataMap(data);
    return VideoUploadResult(
      url: AppConfig.resolveMedia(asStringOrNull(m['url'])),
      coverUrl: m['coverUrl'] == null
          ? null
          : AppConfig.resolveMedia(asStringOrNull(m['coverUrl'])),
    );
  }
}
