import 'package:cloud_firestore/cloud_firestore.dart';

class ContentItem {
  final String id;
  final String title;
  final String type; // 'Video', 'Imagen', 'Archivo'
  final String storageUrl;
  final String uploader;
  final DateTime uploadDate;
  final bool viewed;
  final int order; // ← nuevo campo

  ContentItem({
    required this.id,
    required this.title,
    required this.type,
    required this.storageUrl,
    required this.uploader,
    required this.uploadDate,
    this.viewed = false,
    required this.order,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json, String id) {
    final rawDate = json['dateCreated'] ?? json['uploadDate'];
    DateTime parsedDate;

    try {
      parsedDate = rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.parse(rawDate);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ContentItem(
      id: id,
      title: json['title'] ?? '',
      type: json['type'] ?? 'Video',
      storageUrl: json['storageUrl'] ?? '',
      uploader: json['uploader'] ?? json['creator'] ?? 'Desconocido',
      uploadDate: parsedDate,
      order: json['order'] ?? 9999, // ← fallback si no existe
    );
  }

  ContentItem copyWithViewed(bool viewed) {
    return ContentItem(
      id: id,
      title: title,
      type: type,
      storageUrl: storageUrl,
      uploader: uploader,
      uploadDate: uploadDate,
      order: order,
      viewed: viewed,
    );
  }
}
