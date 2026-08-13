import 'package:flutter_test/flutter_test.dart';
import 'package:hophop/models/models.dart';

void main() {
  test('daysUntilBirthday hesaplanır', () {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final u = UserProfile(
      id: 'x',
      firstName: 'Test',
      lastName: 'Kişi',
      birthDate:
          '2016-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}',
    );
    expect(u.daysUntilBirthday, 1);
  });

  test('IncomingCall FCM verisinden çözülür', () {
    final call = IncomingCall.fromData({
      'roomName': 'a_b_123',
      'callerId': 'a',
      'callerName': 'Dede',
      'video': '1',
      'callerPublicKey': 'pk',
    });
    expect(call.video, true);
    expect(call.toData()['callerName'], 'Dede');
  });
}
