import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'package:geolocator/geolocator.dart';

class AiService {
  final String _apiUrl = "https://api.groq.com/openai/v1/chat/completions";
  late final String _apiKey;
  final http.Client _httpClient;
  final DatabaseService _db = DatabaseService();
  final List<Map<String, dynamic>> _chatHistory = [];
  final List<Map<String, dynamic>> _tools = [
    {
      "type": "function",
      "function": {
        "name": "search_doctors",
        "description":
            "Search for doctors in the database based on a specific specialty. Use this when the user asks to find a doctor, asks about a specialty, or needs the nearest doctor.",
        "parameters": {
          "type": "object",
          "properties": {
            "specialty": {
              "type": "string",
              "description": "The exact medical specialty required.",
              "enum": [
                "General Medicine",
                "Dentistry",
                "Cardiology",
                "Psychiatry",
                "Nutrition",
                "Urology",
                "Dermatology",
                "Gynecology & Obstetrics",
                "Orthopedics",
                "Pediatrics",
                "Internal Medicine",
                "Ophthalmology",
                "Neurology",
                "Gastroenterology",
                "ENT",
                "Pulmonology",
                "Endocrinology",
                "Otolaryngology"
              ]
            },
            "sort_by": {
              "type": "string",
              "description":
                  "How to sort the doctors. Use 'nearest' if the user asks for the closest doctor. Use 'rating' for top rated.",
              "enum": ["rating", "nearest", "none"]
            }
          },
          "required": ["specialty", "sort_by"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "get_doctor_availability",
        "description":
            "Check the available time slots for a specific doctor on a specific date. Use this ONLY after the user has selected a doctor and wants to know when they are available to book.",
        "parameters": {
          "type": "object",
          "properties": {
            "doctor_id": {
              "type": "string",
              "description":
                  "The exact ID of the doctor (obtained from the search_doctors tool)."
            },
            "date": {
              "type": "string",
              "description":
                  "The date to check, formatted exactly as YYYY-MM-DD (e.g., 2026-05-29)."
            }
          },
          "required": ["doctor_id", "date"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "book_appointment",
        "description":
            "Book an appointment with a doctor. Use this ONLY after you have successfully retrieved the doctor's available slots using get_doctor_availability, and the user has explicitly chosen a specific time slot from that list.",
        "parameters": {
          "type": "object",
          "properties": {
            "doctor_id": {
              "type": "string",
              "description": "The exact ID of the doctor to book with."
            },
            "date": {
              "type": "string",
              "description": "The chosen date, formatted EXACTLY as YYYY-MM-DD."
            },
            "time": {
              "type": "string",
              "description":
                  "The exact time slot the user picked (e.g., '10:00 PM'). It MUST be one of the available slots you previously showed them."
            }
          },
          "required": ["doctor_id", "date", "time"]
        }
      }
    }
  ];
  // دالة البناء (Constructor). تسمح لنا بتمرير متغيرات اختيارية (مثل httpClient أو apiKey) عند إنشاء هذه الخدمة
  AiService({http.Client? httpClient, String? apiKey})
      // تهيئة الأداة: إذا تم تمرير httpClient نستخدمه، وإلا (علامة ??) ننشئ نسخة جديدة (http.Client()) كقيمة افتراضية
      : _httpClient = httpClient ?? http.Client() {
    const keyFromEnv = String.fromEnvironment('GROQ_API_KEY');
    final key = apiKey ??
        (keyFromEnv.isNotEmpty ? keyFromEnv : dotenv.env['GROQ_API_KEY']);
    if (key == null || key.isEmpty) {
      throw Exception(
          'API Key for Groq is missing! Please provide it using --dart-define=GROQ_API_KEY=your_key or in a .env file.');
    }
    _apiKey = key.trim();
    // جلب تاريخ اليوم الفعلي فقط (بدون الوقت) لكي نعطيه للذكاء الاصطناعي ليعرف تاريخ اليوم (مثلاً 2026-06-22)
    String todayDate = DateTime.now().toString().split(' ')[0];

    // إضافة "الرسالة التأسيسية" (System Prompt) إلى سجل المحادثة. هذه الرسالة تحدد شخصية الذكاء الاصطناعي وقوانينه الصارمة.
    // دورها "system" يعني أنها تعليمات سرية من المبرمج للذكاء الاصطناعي، ولن يراها المستخدم العادي.
    _chatHistory.add({
      "role": "system",
      "content":
          """You are an advanced medical triage and booking AI Agent for the CareFlow app.
You have access to tools to search for doctors, check schedules, and manage appointments.

IMPORTANT RULE: When you are NOT calling a tool (e.g., when asking triage questions, giving advice, or chatting with the user), you MUST respond ONLY in valid JSON format exactly like this:
{
  "status": "asking" or "finished",
  "message": "your text response to the user",
  "urgency": "none", "green", "yellow", or "red",
  "specialty": "none" or the medical specialty (e.g., General Medicine, Cardiology, etc.)
}

RULES:
1. If the user asks about doctors, finding a doctor, booking, or appointments, DO NOT guess. USE THE APPROPRIATE TOOL.
2. If you are doing medical triage, ask a maximum of 3 questions one by one.
3. Never output any markdown or text outside the JSON structure when talking to the user.
4. CRITICAL GPS RULE: Differentiate between the user's GPS and the doctors' locations. If the tool returns an error specifically saying the USER'S location/GPS is off or denied, tell the user to turn it on. BUT, if the tool says that "no doctors have registered their locations", DO NOT blame the user's GPS. Simply tell the user: "There are no doctors with registered locations for this specialty near you."
5. CRITICAL: When using the search_doctors tool, YOU MUST READ THE EXACT "distance_in_km" provided in the JSON response. NEVER assume or change the distance to 0.0. Even if the distance is huge (e.g., 11000 km), REPORT IT EXACTLY as received. DO NOT hallucinate doctor names or distances.
6. CRITICAL: When responding to the user after using a tool, formulate a natural, human-like sentence in the "message" field. DO NOT output code, technical logs, or raw JSON inside the "message" string. Just speak naturally.
7. CRITICAL DATE RULE: Today's exact date is $todayDate. If the user mentions ANY time format (e.g., "today", "tomorrow", "next Sunday", "1 June", "1/6", "1-6"), DO NOT ask them for the date. You are an AI, figure it out! You MUST silently interpret their input based on the current year and month, convert it EXACTLY to YYYY-MM-DD format, and immediately call the get_doctor_availability tool. Example: If today is 2026-05-30 and the user says "1 june" or "1/6", you must automatically pass "2026-06-01" to the tool.
8. ONLY ask the user "For which date..." if they ask for availability WITHOUT mentioning ANY timeframe at all.
9. CRITICAL UI RULE: ALWAYS set "status": "asking" while using ANY tool (including search_doctors, get_doctor_availability, and booking appointments) or when providing information. NEVER set "status": "finished" just because you answered a question or completed a tool call. You MUST keep the conversation open so the user can continue the flow. ONLY set "status": "finished" if the patient explicitly ends the conversation (e.g., saying "I am done", "thank you", "bye", "that is all").
10. CRITICAL RESPONSE RULE: When answering a query about a doctor (e.g., nearest or top-rated), KEEP IT BRIEF. ONLY mention the doctor's name, specialty, and the primary metric requested (e.g., rating or distance). DO NOT output the number of reviews or distance if it is 0.0. NEVER say "located 0.0 km away". If distance is 0.0, assume they do not have a location set and do not mention distance at all.
11. CRITICAL TRIAGE-TO-BOOKING FLOW: When you finish asking the medical triage questions (maximum 3) and determine the urgency (Red, Blue, etc.) AND that the patient needs a doctor:
- DO NOT end the conversation.
- DO NOT tell the patient to click any buttons.
- You MUST tell them the specific medical specialty they need (e.g., General Medicine, Dentistry, Cardiology).
- Then, IMMEDIATELY ask them naturally: "You need to see a [Specialty] doctor. Would you like me to find the best options for you here and book an appointment?"

12. IF THE PATIENT AGREES TO BOOK: 
- Ask them EXACTLY this: "Great! Do you prefer the nearest doctor, the top-rated one, or are you looking for a specific doctor by name?"
- Wait for their answer.
- Once they answer (e.g., "nearest"), IMMEDIATELY use the `search_doctors` tool with the correct `sort_by` parameter and the specialty you determined.
- After finding the doctor, naturally transition to checking availability using `get_doctor_availability`, and finally use `book_appointment`.

13. UI STATE LOCK: During this ENTIRE flow (Triage -> Search -> Availability -> Booking), you MUST keep "status": "asking". NEVER send "status": "finished" unless the patient explicitly says they don't want to book or ends the chat.
14. CRITICAL JSON FORMAT CONSTRAINT: You MUST respond strictly with a valid JSON object matching the required schema. NEVER wrap the JSON in markdown code blocks like ```json ... ```. NEVER output any text, punctuation, whitespace, or commentary before or after the JSON payload. The entire response must strictly be a raw, parseable JSON string. Failure to comply breaks the mobile app interface.
15. STRICT ANTI-ECHO RULE: NEVER repeat or echo the patient's symptoms verbatim in your responses. Process them internally and transition directly to either a follow-up question or the final clinical recommendation.
16. NO VERBAL STALLING: NEVER output passive transition phrases (e.g., "Let me search for available times today") or halt the execution chain to wait for redundant permissions. Execute the tools instantly and seamlessly as defined in the flow."""
    });
  }

  Future<String> getAiResponse(String userMessage) async { // فنكشن مسؤول عن إرسال رسالة المريض والحصول على رد الذكاء الاصطناعي
    _chatHistory.add({"role": "user", "content": userMessage.trim()}); // أضف رسالة المريض إلى سجل المحادثة كرسالة من نوع "يوزر"
    try {
      final response = await _httpClient.post( // أرسل طلب (POST) عبر الإنترنت إلى خادم الذكاء الاصطناعي وانتظر الرد
        Uri.parse(_apiUrl), // حوّل الرابط النصي إلى رابط قابل للاستخدام
        headers: { // ديباجة الطلب (معلومات للخادم قبل المحتوى)
          "Authorization": "Bearer $_apiKey", // كلمة السر (مفتاح الـ API) لإثبات هوية التطبيق للخادم
          "Content-Type": "application/json", // إخبار الخادم أن لغتنا ستكون جيسون (JSON)
        },
        body: jsonEncode({ // محتوى الطلب: حوّله من Map إلى نص JSON قبل الإرسال
          "model": "llama-3.3-70b-versatile", // اسم "عقل" الذكاء الاصطناعي الذي نريد استخدامه
          "messages": _chatHistory, // أرسل سجل المحادثة كاملاً لكي يتذكر الذكاء الاصطناعي السياق
          "temperature": 0.5, // درجة الإبداع والخيال (0 = آلة جامدة، 1 = خيال واسع). 0.5 = توازن مثالي
          "tools": _tools, // أرسل له قائمة الأدوات التي يمكنه استخدامها (البحث عن طبيب، الحجز...)
          "tool_choice": "auto" // اتركه يقرر بنفسه متى يستخدم الأداة ومتى يرد بنص عادي
        }),
      );

      if (response.statusCode == 200) { // إذا كان رمز الحالة 200 يعني الطلب نجح وجاء رد من الخادم
        final data = jsonDecode(response.body); // حوّل نص الجيسون الخام القادم من الخادم إلى خريطة بيانات يفهمها الكود
        final responseMessage = data['choices'][0]['message']; // استخرج رسالة الذكاء الاصطناعي من داخل الخريطة (الخادم يضع الرد دائماً داخل مصفوفة اسمها "تشويسز" ونأخذ أول عنصر منها)

        if (responseMessage['tool_calls'] != null) { // إذا قرر الذكاء الاصطناعي استخدام أداة (يعني ما رد بنص عادي، بل طلب تنفيذ فنكشن)
          final toolCalls = responseMessage['tool_calls']; // استخرج قائمة الأدوات التي طلب الذكاء الاصطناعي تنفيذها
          final toolCall = toolCalls[0]; // خذ أول أداة من القائمة (في الغالب تكون أداة واحدة فقط)
          final toolCallId = toolCall['id']; // رقم تعريفي فريد لهذا الطلب، سنحتاجه لاحقاً لإخبار الذكاء الاصطناعي بنتيجة الأداة
          final toolName = toolCall['function']['name']; // اسم الفنكشن الذي طلب الذكاء الاصطناعي تشغيله (مثلاً "بحث_أطباء" أو "حجز_موعد")

          final toolArgs = jsonDecode(toolCall['function']['arguments']); // حوّل المدخلات التي أرسلها الذكاء الاصطناعي (مثلاً اسم التخصص والتاريخ) من نص جيسون إلى خريطة بيانات يمكن قراءتها

          // أضف قرار الذكاء الاصطناعي (طلب الأداة) إلى سجل المحادثة، حتى يتذكر أنه هو من طلب هذه الأداة عندما نرد عليه لاحقاً
          _chatHistory.add(
              {"role": "assistant", "content": null, "tool_calls": toolCalls});

          String toolResultString = ""; // متغير فارغ سيتم وضع نتيجة الأداة بداخله لاحقاً وإرسالها للذكاء الاصطناعي

          if (toolName == "search_doctors") {
            final String specialty = toolArgs['specialty'];
            // اقرأ طريقة الترتيب التي طلبها الذكاء الاصطناعي. نجرب اسمين مختلفين (sort_by أو sortBy) لأن الذكاء الاصطناعي قد يرسلها بأي شكل منهما
            String rawSort =
                (toolArgs['sort_by'] ?? toolArgs['sortBy'] ?? "none") // إذا لم يرسل الذكاء الاصطناعي أي ترتيب فسنضع قيمة افتراضية "none"
                    .toString() // تأكد أن القيمة نص
                    .toLowerCase() // حوّله إلى حروف صغيرة لتجنب مشكلة اختلاف الحالة (Nearest أو nearest)
                    .trim(); // احذف المسافات الفارغة من بداية ونهاية النص
            final String sortBy =
                rawSort.contains("near") ? "nearest" : rawSort; // إذا كان النص يحتوي على كلمة "near" (مثل nearest أو nearby) فاستخدم قيمة ثابتة "الأقرب" لتوحيد المصطلح

            if (sortBy == "nearest") {
              try {
                bool serviceEnabled =
                    await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  toolResultString =
                      '{"error": "Location service is off. You MUST explicitly ask the user to turn on their device GPS in order to find the nearest doctor."}';
                } else {
                  LocationPermission permission =
                      await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                  }

                  if (permission == LocationPermission.denied ||
                      permission == LocationPermission.deniedForever) {
                    toolResultString =
                        '{"error": "Location permission denied. You MUST tell the user that you cannot find the nearest doctor without GPS permissions."}';
                  } else {
                    Position position = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high);
                    toolResultString = await _db.searchDoctorsForAi(
                        specialty, sortBy,
                        userLat: position.latitude,
                        userLng: position.longitude);
                  }
                }
              } catch (e) {
                toolResultString =
                    '{"error": "Failed to get location from the device: $e"}';
              }
            } else {
              toolResultString =
                  await _db.searchDoctorsForAi(specialty, sortBy);
            }
          } else if (toolName == "get_doctor_availability") {
            final String doctorId = toolArgs['doctor_id'];
            final String date = toolArgs['date'];

            try {
              toolResultString =
                  await _db.getDoctorAvailabilityForAi(doctorId, date);
            } catch (e) {
              toolResultString =
                  '{"error": "Failed to get availability from database: $e"}';
            }
          } else if (toolName == "book_appointment") {
            final String doctorId = toolArgs['doctor_id'];
            final String date = toolArgs['date'];
            final String time = toolArgs['time'];

            try {
              toolResultString =
                  await _db.bookAppointmentForAi(doctorId, date, time);
            } catch (e) {
              toolResultString =
                  '{"error": "Failed to execute booking tool: $e"}';
            }
          }

          _chatHistory.add({
            "role": "tool",
            "tool_call_id": toolCallId,
            "name": toolName,
            "content": toolResultString
          });

          final secondResponse = await _httpClient.post(
            Uri.parse(_apiUrl),
            headers: {
              "Authorization": "Bearer $_apiKey",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model": "llama-3.3-70b-versatile",
              "messages": _chatHistory,
              "temperature": 0.5
            }),
          );

          if (secondResponse.statusCode == 200) {
            final secondData = jsonDecode(secondResponse.body);
            final String finalAiText =
                secondData['choices'][0]['message']['content'];

            _chatHistory.add({"role": "assistant", "content": finalAiText});
            return finalAiText;
          } else {
            _chatHistory.removeRange(
                _chatHistory.length - 2, _chatHistory.length);
            return '{"status": "asking", "message": "Server error in second round: ${secondResponse.statusCode}", "urgency": "none", "specialty": "none"}';
          }
        } else {
          final String aiText = responseMessage['content'];
          _chatHistory.add({"role": "assistant", "content": aiText});
          return aiText;
        }
      } else {
        _chatHistory.removeLast();
        return '{"status": "asking", "message": "Server error: ${response.statusCode}", "urgency": "none", "specialty": "none"}';
      }
    } catch (e) {
      _chatHistory.removeLast();
      return '{"status": "asking", "message": "Connection issue: $e", "urgency": "none", "specialty": "none"}';
    }
  }
}
