import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// 相册/相机取素材辅助。首版发布素材从相册或相机选取后上传。
class ImagePickerHelper {
  ImagePickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// 图片体积上限（与后端 image.maxSize=10mb 对齐）
  static const int maxImageBytes = 10 * 1024 * 1024;

  /// 视频体积上限（与后端 video.maxSize=100mb 对齐）
  static const int maxVideoBytes = 100 * 1024 * 1024;

  static Future<List<XFile>> pickImages({int max = 9}) async {
    final list = await _picker.pickMultiImage(imageQuality: 90);
    return list.take(max).toList();
  }

  static Future<XFile?> pickImageFromCamera() =>
      _picker.pickImage(source: ImageSource.camera, imageQuality: 90);

  static Future<XFile?> pickVideo(
          {Duration maxDuration = const Duration(minutes: 5)}) =>
      _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );

  /// 返回文件字节数，文件不存在返回 0。
  static Future<int> sizeOf(XFile file) async {
    try {
      return await File(file.path).length();
    } catch (_) {
      return 0;
    }
  }
}
