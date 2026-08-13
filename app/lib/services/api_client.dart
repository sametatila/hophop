import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final int status;
  final String error;
  ApiException(this.status, this.error);
  @override
  String toString() => 'ApiException($status, $error)';
}

/// Vercel API istemcisi. Tüm çağrılar JWT Bearer ile.
class ApiClient {
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final res = switch (method) {
      'GET' => await http.get(uri, headers: _headers),
      'POST' =>
        await http.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
      _ => throw ArgumentError(method),
    };
    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, decoded['error'] as String? ?? 'unknown');
    }
    return decoded;
  }

  // ---- Kimlik ----

  Future<({String token, UserProfile user})> login(
      String firstName, String lastName, String birthDate) async {
    final r = await _request('POST', '/api/login', {
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': birthDate,
    });
    return (
      token: r['token'] as String,
      user: UserProfile.fromJson(r['user'] as Map<String, dynamic>,
          friendStatus: 'self'),
    );
  }

  Future<UserProfile> me() async {
    final r = await _request('GET', '/api/me');
    return UserProfile.fromJson(r['user'] as Map<String, dynamic>,
        friendStatus: 'self');
  }

  Future<void> updateMe({
    String? photoBase64,
    String? publicKey,
    String? addFcmToken,
    String? removeFcmToken,
  }) =>
      _request('POST', '/api/me', {
        if (photoBase64 != null) 'photoBase64': photoBase64,
        if (publicKey != null) 'publicKey': publicKey,
        if (addFcmToken != null) 'addFcmToken': addFcmToken,
        if (removeFcmToken != null) 'removeFcmToken': removeFcmToken,
      });

  // ---- Kişiler ve arkadaşlık ----

  Future<List<UserProfile>> directory() async {
    final r = await _request('GET', '/api/users');
    return (r['users'] as List)
        .map((u) => UserProfile.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserProfile>> friends() async {
    final r = await _request('GET', '/api/friends');
    return (r['friends'] as List)
        .map((u) =>
            UserProfile.fromJson(u as Map<String, dynamic>, friendStatus: 'friend'))
        .toList();
  }

  Future<void> sendFriendRequest(String toUserId) =>
      _request('POST', '/api/friends/request', {'toUserId': toUserId});

  Future<void> cancelFriendRequest(String requestId) =>
      _request('POST', '/api/friends/request', {'cancelRequestId': requestId});

  Future<void> respondFriendRequest(String requestId, bool accept) =>
      _request('POST', '/api/friends/respond',
          {'requestId': requestId, 'accept': accept});

  Future<({List<FriendRequestEntry> incoming, List<FriendRequestEntry> outgoing})>
      friendRequests() async {
    final r = await _request('GET', '/api/friends/requests');
    List<FriendRequestEntry> parse(String key) => (r[key] as List)
        .map((e) => FriendRequestEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return (incoming: parse('incoming'), outgoing: parse('outgoing'));
  }

  // ---- Arama ----

  Future<
      ({
        String roomName,
        String livekitToken,
        String livekitUrl,
        String? calleePublicKey
      })> initiateCall(String calleeId, bool video) async {
    final r = await _request(
        'POST', '/api/call/initiate', {'calleeId': calleeId, 'video': video});
    return (
      roomName: r['roomName'] as String,
      livekitToken: r['livekitToken'] as String,
      livekitUrl: r['livekitUrl'] as String,
      calleePublicKey: r['calleePublicKey'] as String?,
    );
  }

  Future<({String livekitToken, String livekitUrl, String? callerPublicKey})>
      respondCall(String roomName, String callerId, bool accept) async {
    final r = await _request('POST', '/api/call/respond',
        {'roomName': roomName, 'callerId': callerId, 'accept': accept});
    if (!accept) {
      return (livekitToken: '', livekitUrl: '', callerPublicKey: null);
    }
    return (
      livekitToken: r['livekitToken'] as String,
      livekitUrl: r['livekitUrl'] as String,
      callerPublicKey: r['callerPublicKey'] as String?,
    );
  }

  Future<void> cancelCall(String roomName, String calleeId) => _request(
      'POST', '/api/call/cancel', {'roomName': roomName, 'calleeId': calleeId});
}

/// Uygulama genelinde tek örnek.
final api = ApiClient();
