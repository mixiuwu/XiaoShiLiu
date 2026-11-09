/// 广告位（首页横幅）。
class AdItem {
  final int id;
  final String title;
  final String imageUrl;
  final String? linkUrl;

  const AdItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.linkUrl,
  });

  factory AdItem.fromJson(Map<String, dynamic> json) => AdItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: (json['title'] ?? '').toString(),
        imageUrl: (json['image_url'] ?? '').toString(),
        linkUrl: json['link_url']?.toString(),
      );
}
