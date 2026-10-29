// Pending Dart SDK verification; real wire E2E is covered in Python/Go.
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:connectit_client_staging/connectit/master_auth_client.dart';

void main() {
  final pin = Uint8List(32)..fillRange(0, 32, 7);
  test('remote insecure HTTP is always rejected', () {
    expect(() => ConnectITMasterAuthClient(
      master: Uri.parse('http://example.org:7070'),
      pinnedMasterEd25519PublicKey: pin), throwsArgumentError);
  });
  test('localhost HTTP is allowed only with correct issuer pin', () {
    final client = ConnectITMasterAuthClient(
      master: Uri.parse('http://127.0.0.1:7070'),
      pinnedMasterEd25519PublicKey: pin);
    client.close();
    expect(() => ConnectITMasterAuthClient(
      master: Uri.parse('http://localhost:7070'),
      pinnedMasterEd25519PublicKey: Uint8List(31)), throwsArgumentError);
  });
  test('credentials cannot be put in authority URL', () {
    expect(() => ConnectITMasterAuthClient(
      master: Uri.parse('https://user:password@example.org'),
      pinnedMasterEd25519PublicKey: pin), throwsArgumentError);
  });
  test('signed session respects expiry', () {
    const expired = ConnectITMasterSession('0123456789', 'fake', 12345);
    expect(expired.validNow, false);
  });
}
