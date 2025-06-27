import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoId;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.videoId
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _viewRegistered = false;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  bool _showCompletionMessage = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    _controller.addListener(_checkProgress);
  }

  @override
  void dispose() {
    _controller.removeListener(_checkProgress);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _registerView() async {
    try {
      final viewsSnapshot = await FirebaseFirestore.instance
          .collection('content_views')
          .where('uid', isEqualTo: uid)
          .where('contentId', isEqualTo: widget.videoId)
          .get();

      if (viewsSnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('content_views').add({
          'uid': uid,
          'contentId': widget.videoId,
          'timestamp': DateTime.now().toIso8601String(),
          'progress': 100, // Indica que completó el 100% (aunque solo vimos 90%)
        });

        setState(() {
          _viewRegistered = true;
          _showCompletionMessage = true;
        });

        // Ocultar el mensaje después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showCompletionMessage = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error registrando vista: $e');
    }
  }

  void _checkProgress() {
    if (!_controller.value.isInitialized || _viewRegistered) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (duration.inSeconds > 0 && position.inSeconds > 0) {
      final progress = position.inSeconds / duration.inSeconds;

      if (progress >= 0.01) { // 90% del video visto
        _registerView();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproduciendo Video'),
        actions: [
          if (_viewRegistered)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
                : const CircularProgressIndicator(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}