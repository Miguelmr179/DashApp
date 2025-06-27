import 'dart:ui';

import 'package:dashapp/Capacitaciones/screens/users/exam_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dashapp/Capacitaciones/services/video_player_screen.dart';
import 'package:dashapp/Capacitaciones/services/ImageViewerScreen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class LessonsByCourseScreen extends StatefulWidget {
  final String course;

  const LessonsByCourseScreen({Key? key, required this.course})
    : super(key: key);

  @override
  State<LessonsByCourseScreen> createState() => _LessonsByCourseScreenState();
}

class _LessonsByCourseScreenState extends State<LessonsByCourseScreen>
    with SingleTickerProviderStateMixin {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final Map<String, bool> _expandedTiles = {};
  late final AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Stream<Map<String, List<ContentItem>>> _fetchLessonsWithContents() {
    return FirebaseFirestore.instance
        .collection('lessons')
        .where('course', isEqualTo: widget.course)
        .snapshots()
        .asyncMap((lessonSnapshot) async {
          final lessonDocs = lessonSnapshot.docs;

          final contentsSnapshot =
              await FirebaseFirestore.instance
                  .collection('contents')
                  .where('course', isEqualTo: widget.course)
                  .orderBy('order')
                  .get();

          final viewsSnapshot =
              await FirebaseFirestore.instance
                  .collection('content_views')
                  .where('uid', isEqualTo: uid)
                  .get();

          final viewedIds =
              viewsSnapshot.docs
                  .map((doc) => doc['contentId'] as String)
                  .toSet();

          final allContents =
              contentsSnapshot.docs.map((doc) {
                final data = doc.data();
                final id = doc.id;
                final viewed = viewedIds.contains(id);
                return ContentItem.fromJson(data, id).copyWithViewed(viewed);
              }).toList();

          Map<String, List<ContentItem>> lessonsMap = {};
          for (var lessonDoc in lessonDocs) {
            final lessonTitle = lessonDoc['title'] ?? 'Sin título';
            lessonsMap[lessonTitle] =
                allContents
                    .where((content) => content.lesson == lessonTitle)
                    .toList();
          }
          return lessonsMap;
        });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient =
        isDark
            ? const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
            : const LinearGradient(
              colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Lecciones de ${widget.course}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black12,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StreamBuilder<Map<String, List<ContentItem>>>(
            stream: _fetchLessonsWithContents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blueAccent,
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }




              final lessons = snapshot.data ?? {};

              final allContents =
                  lessons.values.expand((list) => list).toList();
              final vistosTotales = allContents.where((c) => c.viewed).length;
              final totalTotales = allContents.length;
              final progresoGlobal =
                  totalTotales > 0
                      ? vistosTotales / totalTotales.toDouble()
                      : 0.0;
              final porcentajeGlobal = (progresoGlobal * 100).toStringAsFixed(
                0,
              );

              return AnimationLimiter(
                child: ListView(
                  padding: const EdgeInsets.only(
                    top: kToolbarHeight + 16,
                    left: 12,
                    right: 12,
                  ),
                  children: [
                    // 📊 Barra de progreso global (encabezado)
                    Card(
                      color: Colors.white.withOpacity(0.1), // Fondo translúcido
                      elevation: 6,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Card(
                        color: Colors.white.withOpacity(0.1),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.bar_chart_rounded,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Progreso del curso',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                AnimatedProgressIndicator(
                                  value: progresoGlobal,
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutQuart,
                                  minHeight: 8,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.3,
                                  ),
                                  color:
                                      progresoGlobal == 1.0
                                          ? Colors.green
                                          : Colors.lightBlueAccent,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Avance total de: $porcentajeGlobal%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 20, top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Favor de visualizar los videos completamente para desbloquear los contenidos y avanzar en la lección.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // 🧩 Lecciones con progreso individual
                    ...AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 375),
                      childAnimationBuilder:
                          (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                      children:
                          lessons.entries.map((entry) {
                            final title = entry.key;
                            final contents = entry.value;
                            int vistos = contents.where((c) => c.viewed).length;
                            int total = contents.length;
                            double progress = total > 0 ? vistos / total : 0;
                            String porcentaje = (progress * 100)
                                .clamp(0, 100)
                                .toStringAsFixed(0);
                            bool nextEnabled = true;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  // InkWell envuelve la cabecera para hacerla completamente interactiva
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _expandedTiles[title] =
                                            !(_expandedTiles[title] ?? false);
                                      });
                                    },
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                AnimatedProgressIndicator(
                                                  value: progress,
                                                  duration: const Duration(
                                                    milliseconds: 800,
                                                  ),
                                                  curve: Curves.easeOutQuart,
                                                  minHeight: 6,
                                                  backgroundColor:
                                                      Colors.grey[300],
                                                  color:
                                                      progress == 1.0
                                                          ? Colors.green
                                                          : Colors.blueAccent,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '$vistos de $total vistos ($porcentaje%)',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            _expandedTiles[title] ?? false
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Contenido expandible (sin cambios)
                                  if (_expandedTiles[title] ?? false) ...[
                                    const Divider(height: 1, thickness: 1),
                                    ...contents.map((content) {
                                      bool isEnabled;
                                      Icon icon;
                                      if (content.viewed) {
                                        isEnabled = true;
                                        icon = const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        );
                                      } else if (nextEnabled) {
                                        isEnabled = true;
                                        nextEnabled = false;
                                        icon = const Icon(
                                          Icons.lock_open,
                                          color: Colors.orange,
                                        );
                                      } else {
                                        isEnabled = false;
                                        icon = const Icon(
                                          Icons.lock,
                                          color: Colors.grey,
                                        );
                                      }

                                      return AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        opacity: isEnabled ? 1.0 : 0.5,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.95,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: _fadeController,
                                              curve: Curves.easeOutBack,
                                            ),
                                          ),
                                          child: ListTile(
                                            title: Text(content.title),
                                            subtitle: Text(content.descripcion),
                                            leading: icon,
                                            onTap:
                                                () => _handleTap(
                                                  content,
                                                  isEnabled,
                                                ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            tileColor:
                                                isEnabled
                                                    ? (content.viewed
                                                        ? Colors.green
                                                            .withOpacity(0.05)
                                                        : Colors.blue
                                                            .withOpacity(0.05))
                                                    : null,
                                          ),
                                        ),
                                      );
                                    }).toList(),

                                    if (progress == 1.0)
                                      StreamBuilder<DocumentSnapshot>(
                                        stream:
                                            FirebaseFirestore.instance
                                                .collection('exam_final_scores_temporal')
                                                .doc(
                                                  '$uid-${widget.course}-$title',
                                                )
                                                .snapshots(),
                                        builder: (context, finalScoreSnapshot) {
                                          if (finalScoreSnapshot
                                                  .connectionState ==
                                              ConnectionState.waiting) {
                                            return const SizedBox.shrink();
                                          }

                                          if (finalScoreSnapshot.hasData &&
                                              finalScoreSnapshot.data!.exists) {
                                            final score =
                                                finalScoreSnapshot.data!.get(
                                                  'finalScore',
                                                ) ??
                                                0.0;
                                            final vistosActuales =
                                                contents
                                                    .where((c) => c.viewed)
                                                    .length;
                                            final totalActuales =
                                                contents.length;

                                            if (vistosActuales <
                                                totalActuales) {
                                              return const SizedBox.shrink();
                                            }

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16.0,
                                                    vertical: 12,
                                                  ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.verified,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Examen acreditado (${score.toStringAsFixed(1)}%)',
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          return FutureBuilder<QuerySnapshot>(
                                            future:
                                                FirebaseFirestore.instance
                                                    .collection('exams')
                                                    .where(
                                                      'category',
                                                      isEqualTo: widget.course,
                                                    )
                                                    .where(
                                                      'lesson',
                                                      isEqualTo: title,
                                                    )
                                                    .where(
                                                      'isActive',
                                                      isEqualTo: true,
                                                    )
                                                    .limit(1)
                                                    .get(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData ||
                                                  snapshot.data!.docs.isEmpty) {
                                                return const SizedBox.shrink();
                                              }

                                              final examDoc =
                                                  snapshot.data!.docs.first;
                                              final examId = examDoc.id;

                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12.0,
                                                      vertical: 12.0,
                                                    ),
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                    Icons.assignment,
                                                  ),
                                                  label: const Text(
                                                    'Realizar examen',
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.deepPurple,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                          horizontal: 20,
                                                        ),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (_) => ExamScreen(
                                                              category:
                                                                  widget.course,
                                                              examId: examId,
                                                              lesson: title,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(ContentItem content, bool isEnabled) async {
    if (!isEnabled) {
      final snackBar = SnackBar(
        content: const Text('Debes ver el contenido anterior primero.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    // 🔒 Si ya fue visto y no es video, no lo vuelve a registrar
    Future<void> _registerViewIfNeeded() async {
      if (!content.viewed) {
        await FirebaseFirestore.instance.collection('content_views').add({
          'uid': uid,
          'contentId': content.id,
          'timestamp': DateTime.now().toIso8601String(),
          'progress': 100,
        });
      }
    }

    if (content.type == 'Video') {
      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder:
              (_, __, ___) => VideoPlayerScreen(
                videoUrl: content.storageUrl,
                videoId: content.id,
              ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else if (content.type == 'Imagen') {
      await _registerViewIfNeeded();

      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder:
              (_, __, ___) => ImageViewerScreen(imageUrl: content.storageUrl),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
              ),
              child: child,
            );
          },
        ),
      );
    } else {
      await _registerViewIfNeeded();
      await launchUrl(Uri.parse(content.storageUrl));
    }

    setState(() {});
  }
}

class AnimatedExpansionTile extends StatefulWidget {
  final Widget title;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final List<Widget> children;

  const AnimatedExpansionTile({
    Key? key,
    required this.title,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    required this.children,
  }) : super(key: key);

  @override
  _AnimatedExpansionTileState createState() => _AnimatedExpansionTileState();
}

class _AnimatedExpansionTileState extends State<AnimatedExpansionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _iconTurns = _controller.drive(
      Tween<double>(
        begin: 0.0,
        end: 0.5,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );

    _isExpanded = widget.initiallyExpanded;
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      widget.onExpansionChanged?.call(_isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller.view,
      builder: (BuildContext context, Widget? child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              onTap: _handleTap,
              title: widget.title,
              trailing: RotationTransition(
                turns: _iconTurns,
                child: const Icon(Icons.expand_more),
              ),
            ),
            ClipRect(
              child: Align(heightFactor: _heightFactor.value, child: child),
            ),
          ],
        );
      },
      child: Column(children: widget.children),
    );
  }
}

class AnimatedProgressIndicator extends StatefulWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double minHeight;
  final Duration duration;
  final Curve curve;

  const AnimatedProgressIndicator({
    Key? key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.minHeight = 4.0,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
  }) : super(key: key);

  @override
  _AnimatedProgressIndicatorState createState() =>
      _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = _controller.drive(CurveTween(curve: widget.curve));
    _controller.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(AnimatedProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _animation.value * widget.value,
          backgroundColor: widget.backgroundColor,
          color: widget.color,
          minHeight: widget.minHeight,
        );
      },
    );
  }
}

class ContentItem {
  final String id;
  final String title;
  final String type;
  final String storageUrl;
  final String uploader;
  final DateTime uploadDate;
  final bool viewed;
  final String descripcion;
  final String lesson;

  ContentItem({
    required this.id,
    required this.title,
    required this.type,
    required this.storageUrl,
    required this.uploader,
    required this.uploadDate,
    this.viewed = false,
    required this.descripcion,
    required this.lesson,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json, String id) {
    return ContentItem(
      id: id,
      title: json['title'] ?? '',
      type: json['type'] ?? 'Video',
      storageUrl: json['storageUrl'] ?? '',
      uploader: json['uploader'] ?? 'Desconocido',
      uploadDate: DateTime.tryParse(json['uploadDate'] ?? '') ?? DateTime.now(),
      descripcion: json['description'] ?? '',
      lesson: json['lesson'] ?? '',
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
      viewed: viewed,
      descripcion: descripcion,
      lesson: lesson,
    );
  }
}
