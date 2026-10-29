import 'package:connectit_client_staging/connectit/master_auth_client.dart';

import 'connectit_securebind_decision.dart';

/// Allows widget tests to run without a real Master or signing key.
abstract interface class ConnectITSecureBindGateway {
  Future<ConnectITPendingList> pending();
  Future<void> decide({
    required ConnectITPendingApproval request,
    required String action,
    required int serverTime,
    required String localPin,
    required bool confirmedTarget,
  });
}

/// Actual staging binding: the Master client verifies signed requests while
/// the independent SecureBind decision module enforces the device-bound PIN.
final class ConnectITMasterSecureBindGateway
    implements ConnectITSecureBindGateway {
  final ConnectITMasterAuthClient master;
  final ConnectITMasterSession session;
  final ConnectITSecureSigner signer;
  final ConnectITOwnDevice own;
  final ConnectITSecureBindDecision decision;

  ConnectITMasterSecureBindGateway({
    required this.master,
    required this.session,
    required this.signer,
    required this.own,
    required this.decision,
  }) {
    if (own.accountId != session.accountId ||
        signer.publicKeyBase64 != decision.localPin.devicePublicKeyBase64) {
      throw StateError('SecureBind account or local device identity mismatch');
    }
  }

  @override
  Future<ConnectITPendingList> pending() =>
      master.pendingBindings(session, signer);

  @override
  Future<void> decide({
    required ConnectITPendingApproval request,
    required String action,
    required int serverTime,
    required String localPin,
    required bool confirmedTarget,
  }) => decision.decide(
        session: session,
        signer: signer,
        own: own,
        request: request,
        action: action,
        serverTime: serverTime,
        enteredLocalPin: localPin,
        userConfirmedExactTarget: confirmedTarget,
      );
}
