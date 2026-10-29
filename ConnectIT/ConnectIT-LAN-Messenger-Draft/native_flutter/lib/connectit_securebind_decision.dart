import 'package:connectit_client_staging/connectit/master_auth_client.dart';

import 'connectit_local_pin_gate.dart';

/// A narrow, independent bridge from a trusted-device SecureBind review UI to
/// the Master client. A user must confirm the exact displayed target on EVERY
/// decision. Never expose a reusable authorization or cached "PIN verified" bit.
///
/// Deliberately NOT imported into the existing LAN Messenger application.
/// This only checks an app-local PIN; hardware-backed user presence still needs
/// an OS-level prompt and physical Android/Windows verification.
final class ConnectITSecureBindDecision {
  final ConnectITMasterAuthClient master;
  final ConnectITLocalPinGate localPin;

  const ConnectITSecureBindDecision({
    required this.master,
    required this.localPin,
  });

  Future<void> decide({
    required ConnectITMasterSession session,
    required ConnectITSecureSigner signer,
    required ConnectITOwnDevice own,
    required ConnectITPendingApproval request,
    required String action,
    required int serverTime,
    required String enteredLocalPin,
    required bool userConfirmedExactTarget,
  }) {
    if (action != 'approve' && action != 'revoke' && action != 'not_me') {
      throw ArgumentError('Unsupported SecureBind decision');
    }
    if (!userConfirmedExactTarget) {
      throw StateError('User must explicitly confirm the displayed target');
    }
    if (localPin.devicePublicKeyBase64 != signer.publicKeyBase64) {
      throw StateError('PIN verification identity does not match signer');
    }
    return master.decideBinding(
      session: session,
      signer: signer,
      own: own,
      request: request,
      action: action,
      serverTime: serverTime,
      verifyLocalPinAndConsent: () => localPin.verifyForApproval(
        pin: enteredLocalPin,
        userConfirmed: userConfirmedExactTarget,
      ),
    );
  }
}
