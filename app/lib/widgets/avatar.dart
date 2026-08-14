import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/photo_cache.dart';
import '../theme/hop_theme.dart';

class Avatar extends StatelessWidget {
  final UserProfile user;
  final double radius;

  /// Fotoğrafı olan kişide dokununca tam ekran görüntüleyici açılır
  /// (WhatsApp davranışı). Fotoğrafı yoksa dokunma yok sayılır.
  final bool viewable;

  /// Büyürken akıcı geçiş için Hero etiketi. Aynı ekranda aynı etiket iki kez
  /// bulunamaz; kuşku varsa null bırak (geçiş yine yumuşak açılır).
  final String? heroTag;

  const Avatar({
    super.key,
    required this.user,
    this.radius = 28,
    this.viewable = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // Bellekte varsa anında çizilir; yoksa PhotoCache diskten/ağdan getirir.
    final cached = PhotoCache.peek(user.id, user.photoVersion);
    if (cached == null && user.photoVersion != null) {
      return FutureBuilder<Uint8List?>(
        future: PhotoCache.load(user.id, user.photoVersion),
        builder: (context, snap) => _build(context, snap.data),
      );
    }
    return _build(context, cached);
  }

  Widget _build(BuildContext context, Uint8List? bytes) {
    Widget avatar = bytes != null
        ? CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes))
        : CircleAvatar(
            radius: radius,
            backgroundColor: Colors
                .primaries[user.id.hashCode.abs() % Colors.primaries.length]
                .shade300,
            child: Text(
              _initials,
              style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          );

    if (bytes == null || !viewable) return avatar;

    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(PhotoViewer.route(
        bytes: bytes,
        title: user.fullName,
        heroTag: heroTag,
      )),
      child: avatar,
    );
  }

  String get _initials {
    final s = [user.firstName, user.lastName]
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .join();
    return s.isEmpty ? '?' : s;
  }
}

/// Profil fotoğrafının tam ekran hâli: karartılmış zemin, çift dokunuşla ya da
/// parmakla yakınlaştırma, boşluğa dokununca kapanma.
class PhotoViewer extends StatelessWidget {
  final Uint8List bytes;
  final String title;
  final String? heroTag;

  const PhotoViewer({
    super.key,
    required this.bytes,
    required this.title,
    this.heroTag,
  });

  static Route<void> route({
    required Uint8List bytes,
    required String title,
    String? heroTag,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: Hop.normal,
      reverseTransitionDuration: Hop.fast,
      pageBuilder: (_, __, ___) =>
          PhotoViewer(bytes: bytes, title: title, heroTag: heroTag),
      // Hero yoksa da "öne doğru büyüme" hissi kalsın.
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(bytes, fit: BoxFit.contain);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 17)),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: heroTag != null ? Hero(tag: heroTag!, child: image) : image,
          ),
        ),
      ),
    );
  }
}
