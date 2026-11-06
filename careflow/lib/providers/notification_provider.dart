import 'package:flutter/foundation.dart';

import '../services/message.dart';

class NotificationProvider with ChangeNotifier {
  MessageServices _messageServices =
      MessageServices(); // بنجيب ال instance بتاع ال MessageServices عشان نقدر نستخدم ال functions اللي فيها في ال provider

  NotificationProvider() {
    notifyListeners();
  }

  Future<void> sendNotificationToUser(
      {required String fcmToken,
      required String title,
      required String body,
      required String type}) async {
    await _messageServices.sendNotificationToUser(
      body: body,
      fcmToken: fcmToken,
      title: title,
      type: type,
    );
  } // دي function بتستخدم ال access token اللي جبناها في ال getAccessToken عشان نرسل notification ل user معين باستخدام ال FCM token بتاعه

  Future<void> sendNotificationToGroup(
      {required String group,
      required String title,
      required String body}) async {
    await _messageServices.sendNotificationToGroup(
      body: body,
      group: group,
      title: title,
    );
  } // دي function بتستخدم ال access token اللي جبناها في ال getAccessToken عشان نرسل notification ل group معين باستخدام ال topic بتاعه

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messageServices.unsubscribeFromTopic(
      topic: topic,
    );
  } // دي function بتستخدم ال access token اللي جبناها في ال getAccessToken عشان نلغي اشتراك user معين من topic معين

  Future<void> subscribeToTopic(String topic) async {
    await _messageServices.subscribeToTopic(
      topic: topic,
    );
  } // دي function بتستخدم ال access token اللي جبناها في ال getAccessToken عشان نشترك user معين في topic معين
}
