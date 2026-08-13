import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';

class Avatar extends StatelessWidget {
  final UserProfile user;
  final double radius;
  const Avatar({super.key, required this.user, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    final photo = user.photoBase64;
    if (photo != null && photo.isNotEmpty) {
      try {
        bytes = base64Decode(photo);
      } catch (_) {}
    }
    if (bytes != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
    }
    final initials = [user.firstName, user.lastName]
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          Colors.primaries[user.id.hashCode.abs() % Colors.primaries.length].shade300,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ),
    );
  }
}
