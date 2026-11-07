// LEGACY NOTIFICATION SENDER — SECURE STUB
//
// History: This file previously contained a Firebase service-account
// private key hardcoded in the client. That key has been REMOVED for
// security and must never be in client code again.
//
// Correct architecture:
//   - FCM push sending must happen server-side (Cloudflare Worker),
//     where the service-account secret lives as a Worker secret.
//   - The client should NEVER hold a private key.
//
// Current behavior:
//   - All send methods are no-ops that log a clear message.
//   - The app will still work; doctor/patient push for new bookings
//     will be enabled once the Cloudflare Worker /notify endpoint
//     is implemented with the careflow-2004 service account.
//
// Do NOT re-add service-account JSON here.
import 'package:flutter/foundation.dart';

class MessageServices {
  // Topic helpers still work (client-side subscribe/unsubscribe).
  Future<void> unsubscribeFromTopic({String? topic}) async {
    debugPrint(
      'MessageServices.unsubscribeFromTopic: topic subscriptions are '
      'handled via FirebaseMessaging in main.dart (was: $topic).',
    );
  }

  Future<void> subscribeToTopic({String? topic}) async {
    debugPrint(
      'MessageServices.subscribeToTopic: topic subscriptions are '
      'handled via FirebaseMessaging in main.dart (was: $topic).',
    );
  }

  Future<String> getAccessToken() async {
    debugPrint(
      'MessageServices.getAccessToken: disabled — service-account keys '
      'must never live in the client. FCM sending is server-side only.',
    );
    throw StateError(
      'FCM sending from client is disabled for security. '
      'Implement server-side (Cloudflare Worker) sending instead.',
    );
  }

  Future<void> sendNotificationToUser({
    required String fcmToken,
    required String title,
    required String body,
    required String type,
  }) async {
    debugPrint(
      'MessageServices.sendNotificationToUser: skipped (server-side only). '
      'title="$title", type="$type"',
    );
    // TODO(backend): POST to Cloudflare Worker /notify endpoint
    //   with { token, title, body, type } once the Worker stores
    //   the careflow-2004 service-account secret.
  }

  Future<void> sendNotificationToGroup({
    required String group,
    required String title,
    required String body,
  }) async {
    debugPrint(
      'MessageServices.sendNotificationToGroup: skipped (server-side only). '
      'group="$group", title="$title"',
    );
  }
}
