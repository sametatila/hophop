/// HopHop veri modelleri.
class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String? photoBase64;
  final String? birthDate; // yalnızca arkadaşlar + kendisi için dolu (YYYY-AA-GG)
  final String? publicKey; // E2EE — yalnızca arkadaşlar için dolu
  final String friendStatus; // none | requested | incoming | friend | self

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photoBase64,
    this.birthDate,
    this.publicKey,
    this.friendStatus = 'none',
  });

  String get fullName => '$firstName $lastName';

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? friendStatus}) {
    return UserProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      photoBase64: json['photoBase64'] as String?,
      birthDate: json['birthDate'] as String?,
      publicKey: json['publicKey'] as String?,
      friendStatus: friendStatus ?? (json['friendStatus'] as String? ?? 'none'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'photoBase64': photoBase64,
        'birthDate': birthDate,
        'publicKey': publicKey,
        'friendStatus': friendStatus,
      };

  /// Bir sonraki doğum gününe kalan gün (0 = bugün). Doğum tarihi yoksa null.
  int? get daysUntilBirthday {
    final bd = birthDate;
    if (bd == null) return null;
    final parts = bd.split('-').map(int.parse).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var next = DateTime(today.year, parts[1], parts[2]);
    if (next.isBefore(today)) next = DateTime(today.year + 1, parts[1], parts[2]);
    return next.difference(today).inDays;
  }
}

class FriendRequestEntry {
  final String requestId;
  final UserProfile? user;

  FriendRequestEntry({required this.requestId, this.user});

  factory FriendRequestEntry.fromJson(Map<String, dynamic> json) {
    return FriendRequestEntry(
      requestId: json['requestId'] as String,
      user: json['user'] == null
          ? null
          : UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Gelen arama bildirimi payload'ı (FCM data mesajından).
class IncomingCall {
  final String roomName;
  final String callerId;
  final String callerName;
  final bool video;
  final String callerPublicKey;

  IncomingCall({
    required this.roomName,
    required this.callerId,
    required this.callerName,
    required this.video,
    required this.callerPublicKey,
  });

  factory IncomingCall.fromData(Map<String, dynamic> data) => IncomingCall(
        roomName: data['roomName'] as String,
        callerId: data['callerId'] as String,
        callerName: data['callerName'] as String? ?? 'HopHop',
        video: data['video'] == '1',
        callerPublicKey: data['callerPublicKey'] as String? ?? '',
      );

  Map<String, String> toData() => {
        'roomName': roomName,
        'callerId': callerId,
        'callerName': callerName,
        'video': video ? '1' : '0',
        'callerPublicKey': callerPublicKey,
      };
}
