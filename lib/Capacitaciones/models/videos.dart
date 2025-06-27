import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String area;
  final String storageUrl;
  final String uploader;
  final DateTime uploadDate;
  final String course;
  final String lesson;
  final bool viewed;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.area,
    required this.storageUrl,
    required this.uploader,
    required this.uploadDate,
    required this.course,
    required this.lesson,
    this.viewed = false,
  });

  factory Video.fromJson(Map<String, dynamic> json, String id) {
    return Video(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      area: json['area'] ?? '',
      storageUrl: json['storageUrl'] ?? '',
      uploader: json['uploader'] ?? '',
      uploadDate: json['uploadDate'] is Timestamp
          ? json['uploadDate'].toDate()
          : DateTime.tryParse(json['uploadDate'] ?? '') ?? DateTime.now(),
      course: json['course'] ?? '',
      lesson: json['lesson'] ?? '',
      viewed: json['viewed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'area': area,
      'storageUrl': storageUrl,
      'uploader': uploader,
      'uploadDate': uploadDate.toIso8601String(),
      'course': course,
      'lesson': lesson,
      'viewed': viewed,
    };
  }

  Video copyWithViewed(bool hasViewed) {
    return Video(
      id: id,
      title: title,
      description: description,
      area: area,
      storageUrl: storageUrl,
      uploader: uploader,
      uploadDate: uploadDate,
      course: course,
      lesson: lesson,
      viewed: hasViewed,
    );
  }
}

class VideoService {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Video>> getAllVideos() async {
    try {
      final snapshot = await _firestore.collection('contents').get();
      return snapshot.docs
          .map((doc) => Video.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching videos: $e');
      return [];
    }
  }

  Future<Video> getVideoById(String videoId) async {
    try {
      final doc = await _firestore.collection('contents').doc(videoId).get();
      if (doc.exists) {
        return Video.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        throw Exception('Video no encontrado');
      }
    } catch (e) {
      throw Exception('Error obteniendo video: $e');
    }
  }

  Future<void> updateVideo(Video video) async {
    try {
      await _firestore.collection('contents').doc(video.id).update(video.toJson());
    } catch (e) {
      print('Error actualizando video: $e');
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      final ref = _firestore.collection('contents').doc(videoId);
      final doc = await ref.get();

      if (!doc.exists) {
        throw Exception('El video no existe');
      }

      final data = doc.data() as Map<String, dynamic>;
      final String storageUrl = data['storageUrl'];

      final fullPath = Uri.decodeFull(
        RegExp(r'/o/(.*?)\?alt=')
            .firstMatch(storageUrl)
            ?.group(1)
            ?.replaceAll('%2F', '/') ??
            '',
      );

      if (fullPath.isNotEmpty) {
        await FirebaseStorage.instance.ref(fullPath).delete();
      }

      await ref.delete();
      print('Video eliminado correctamente: $videoId');
    } catch (e) {
      print('Error eliminando video: $e');
    }
  }
}
