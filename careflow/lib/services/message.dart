import 'dart:convert' show jsonEncode;
//لاستقبال الإشعارات من سيرفرات فايربيس
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class MessageServices {
  // دي class بتحتوي على كل ال functions اللي بتتعامل مع ال notifications في التطبيق
  final FirebaseMessaging _fcm = FirebaseMessaging
      .instance; // بنجيب ال instance بتاع ال FirebaseMessaging عشان نقدر نتعامل مع ال notifications

  final String _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/myappse04/messages:send'; // دي ال endpoint اللي هنستخدمها عشان نرسل ال notifications من ال backend

  Future<void> unsubscribeFromTopic({String? topic}) {
    return _fcm.unsubscribeFromTopic(topic!);
  }

  Future<void> subscribeToTopic({String? topic}) {
    return _fcm.subscribeToTopic(topic!);
  }

  Future<String> getAccessToken() async {
    // دي function بتجيب ال access token اللي هنستخدمه في ال authorization لما نرسل ال notifications من ال backend
    var credentials = ServiceAccountCredentials.fromJson({
      "type": "service_account",
      "project_id": "myappse04",
      "private_key_id": "5ff88c693c16eb167e2b5659a721d2027a653433",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCrUC71cDg+jIVc\n/K43kLm5/JuZEAE+gKhL17FOEt1cnB+uAebpK2tG1T6UB1sX+ApNNZhvG5NV8JO2\nLHhmwYrMseTNTBd6Qro+trGK0onJDp24DhaYmEQjprtxh4nq4sYzUad4rVCP55Wn\nSN9EOVlnott0dj75SpSRcjQ8El5YVCjJCaQoMP7qV+WflGlyirEw4B74+5LAAYwl\nakmtqiBkHqeqz7ECi+GCAejiZJR2YPaIQofZd7peydwNIiBKNAxiDVt+HFctSQwN\nAaF0XfeVDRB51PBC1+2ZLOIQSEpJe6Q+VgP8q83freWdYtfN8Yl+bXr0y7rwHbSR\n3edTg1hjAgMBAAECggEAR1b7Tys9yNJkwR3agPosVaa7tyhilEAolXjLdbtGYogD\na0eQfL4fjN5Fkohjp14cEB4HDhHaL7ohEQaA1y222toj8VhEGJ5MB8y1r51QUqFb\nDagUQdR636vRuAvc46svJXTV/FuURnEGsaSXkUYelJlNsTiCrfagWtdHqFJv5nDr\nFrM5rZfdkq4tmsTCSkIG5cy11Q7e2KktVzux33NedmhJ7MtyNU3swBUixtLhVKIy\n1oXeE3YiDWGp4Q3OcN8KpTD8wy7869dKkGp9m8q6pgHYn0kJaXOPODyUdYTAwONZ\n4E8cPXi7goXQZeM8UMXi3XpmlVzAPYWS8dLycgg5hQKBgQDW9atLqVGl8JlpCDpg\nm0qznvmxend13KsHPjBqkXs9yNDS5xV90LzIy0TAQZJowv/TC/TbV1pUIOY5L+GA\nPtrAQ4iW8IhLadS1I9MyGAcqgdBy66vWq/oM2oRWi3QAgyHqU5bSQQ+sJBxYZrmd\n+ZOTx9ePUS/vMyGRYlpEkEql1QKBgQDMBUJJMrud5W7/ATkEAVJpanNcBC/VIkKc\nEYkAgchZ1f5feAyMfxr3xTyxf/q5fxui3xWgTTCSiPPKiSvTGWG8FEdkvL6NJ9zo\nAbb96yF+cEnb7YN592YSf9J90D6An8+YcTPx0LmZkTHzAqa1yMVtSx0zhsx/N3My\nMeSiTs6JVwKBgD6A0H3/ja4id3kC23absOzpnNDuOy4aK+C/RHS4OI2OhqnMZ4Nd\n3obEFAmTB29Ow/Qp1dixXaJ4rniSY49Wt2SQPnclGXxUGXVSJWa7ddn2RRYlUKHq\n/5odL726btB3ULVB+OjJ4jS7i0JpHC/DEhY2VYdmo/l5dJlBb93f1tTBAoGARX71\nGWICrsJckNilx0t7+xSbvxheAsfs0KTYeie7S36ta2/FNoaFdSjmh8AEc/NsQoqj\nHzur8/5arP8Uwo++zwZJW3M/pW2SviT3ZH8Xpa4yOowpYP548ow/80NgRwgo+tB0\n1UY4MqtWzGR2zS1asuQHSmn8dsk4oDyGmRMnH3kCgYEAzCGsMmw6hgS09AEcKCeG\nP9SAyl7KRoeDNOlb/2VhxW/4B3/E3qi++w5PBE5gx1MNarK7KIpP2GJ7Bt9bAjt1\nwxv+kOyhBlAYO4UB+I78OvDXCWgPlSBjvjZWy4UsxL6QPfOkwKkN919rBe6fppuM\nZ6L2nkEZik7N3kHPPptRzEQ=\n-----END PRIVATE KEY-----\n",
      "client_email":
          "firebase-adminsdk-fbsvc@myappse04.iam.gserviceaccount.com",
      "client_id": "100542678279774558088",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40myappse04.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com",
    });

    var scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    var client = await clientViaServiceAccount(credentials, scopes);
    var accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  Future<void> sendNotificationToUser({
    // دي function بتستخدم ال access token اللي جبناها في ال getAccessToken عشان نرسل notification ل user معين باستخدام ال FCM token بتاعه
    required String fcmToken,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      String accessToken = await getAccessToken();

      Map<String, String> data = {
        'type':
            type, // بنضيف ال type في ال data عشان نقدر نستخدمه في ال onMessage و onBackgroundMessage لما يجي notification ونحدد نوعه عشان نعمل حاجات معينة بناءً على نوع ال notification
      };

      var payload = {
        "message": {
          "token": fcmToken,
          "notification": {"title": title, "body": body},
          "data": data,
          "android": {"priority": "high"},
        },
      };

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('Notification sent to doctor successfully!');
      } else {
        print('Failed to notify doctor. Status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification to doctor: $e');
    }
  }

  Future<void> sendNotificationToGroup({
    // دي function بتستخدم ال access token اللي جبناها في ال getAccessToken عشان نرسل notification ل group معين باستخدام ال topic بتاعه
    required String group,
    required String title,
    required String body,
  }) async {
    try {
      String accessToken = await getAccessToken();

      var notificationPayload = {
        "message": {
          "topic": group,
          "notification": {"title": title, "body": body},
        },
      };

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode == 200) {
        print('Group notification sent successfully!');
      } else {
        print(
          'Failed to send group notification. Status code: ${response.statusCode}',
        );
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending group notification: $e');
    }
  }
}
