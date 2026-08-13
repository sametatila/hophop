import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'call_manager.dart';

/// FCM'den bağımSIZ, GERÇEK ZAMANLI yedek zil yolu.
///
/// Sunucu her kullanıcıya özel Firebase token'ı üretir; cihaz bununla oturum
/// açıp yalnızca kendi `rings/{uid}` belgesini canlı dinler. Arama yazıldığı
/// AN dinleyici tetiklenir → zil çalar. Yoklama yok: kota maliyeti ~sıfır
/// (okuma yalnızca değişiklikte), gecikme ~anlık.
class RingListener {
  static StreamSubscription? _sub;

  static Future<void> start() async {
    final me = auth.me;
    if (me == null) return;
    try {
      // Firebase oturumu kalıcıdır; yoksa sunucudan özel token alıp açılır.
      if (FirebaseAuth.instance.currentUser?.uid != me.id) {
        final r = await api.firebaseToken();
        await FirebaseAuth.instance.signInWithCustomToken(r);
      }
      await _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('rings')
          .doc(me.id)
          .snapshots()
          .listen((snap) {
        final data = snap.data();
        if (data == null) return;
        final atMs = (data['atMs'] as num?)?.toInt() ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - atMs > 45000) return;
        final call = IncomingCall.fromData(Map<String, dynamic>.from(data));
        CallManager.handleRing(call);
      }, onError: (e) => debugPrint('HopHop ring listener: $e'));
    } catch (e) {
      debugPrint('HopHop ring listener kurulamadı: $e');
    }
  }
}
