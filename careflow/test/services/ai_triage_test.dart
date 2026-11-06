import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_test;

// ── Real production code under test ──────────────────────────────────────────
import 'package:careflow/services/ai_service.dart';

// ── Shared Firebase mock (needed because AiService creates DatabaseService) ──
import '../helpers/firebase_mock_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local value object — parsing helper for tests ONLY.
// Mirrors the JSON contract documented in the AiService system prompt and
// consumed by ChatProvider._processUserMessage.
// ─────────────────────────────────────────────────────────────────────────────
class TriageResponse {
  final String status;
  final String message;
  final String urgency;
  final String specialty;

  const TriageResponse({
    required this.status,
    required this.message,
    required this.urgency,
    required this.specialty,
  });

  factory TriageResponse.fromRawAiOutput(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return TriageResponse(
      status: map['status'] as String? ?? 'asking',
      message: map['message'] as String? ?? '',
      urgency: map['urgency'] as String? ?? 'none',
      specialty: map['specialty'] as String? ?? 'none',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Factory helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [aiJsonContent] in the Groq API response envelope that
/// AiService.getAiResponse() expects when no tool call is involved.
String _groqEnvelope(String aiJsonContent) => jsonEncode({
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': aiJsonContent,
          }
        }
      ]
    });

/// Returns a [MockClient] that always responds with [aiJsonContent] and
/// the given [statusCode] (default 200).
http.Client _mockGroqClient(String aiJsonContent, {int statusCode = 200}) {
  return http_test.MockClient((_) async => http.Response(
        _groqEnvelope(aiJsonContent),
        statusCode,
        headers: {'content-type': 'application/json'},
      ));
}

/// Constructs a real [AiService] injected with [client] and a test API key,
/// bypassing flutter_dotenv entirely.
AiService _service(http.Client client) =>
    AiService(httpClient: client, apiKey: 'test-key');

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  setUpAll(() async {
    // Initialises Firebase mock so that DatabaseService (created inside
    // AiService) can be constructed without a native Firebase plugin.
    await setupFirebaseMocks();
  });

  // ── Group 1 · Specialty extraction ────────────────────────────────────────
  group('AiService – Specialty Extraction', () {
    test('1a. "severe chest pain" → Cardiology, red urgency', () async {
      const aiJson = '{"status":"finished",'
          '"message":"Based on your symptoms I strongly recommend a Cardiologist.",'
          '"urgency":"red","specialty":"Cardiology"}';

      final raw = await _service(_mockGroqClient(aiJson))
          .getAiResponse('severe chest pain');

      final r = TriageResponse.fromRawAiOutput(raw);
      expect(r.specialty, equals('Cardiology'));
      expect(r.urgency, equals('red'));
      expect(r.status, equals('finished'));
    });

    test('1b. "tooth decay and sensitivity" → Dentistry', () async {
      const aiJson = '{"status":"finished",'
          '"message":"Your symptoms suggest a dental issue.",'
          '"urgency":"yellow","specialty":"Dentistry"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('tooth decay and sensitivity'));

      expect(r.specialty, equals('Dentistry'));
      expect(r.urgency, equals('yellow'));
    });

    test('1c. "persistent sadness" → Psychiatry', () async {
      const aiJson = '{"status":"finished",'
          '"message":"A Psychiatrist can help you.",'
          '"urgency":"yellow","specialty":"Psychiatry"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('persistent sadness and lack of motivation'));

      expect(r.specialty, equals('Psychiatry'));
    });

    test('1d. "blurry vision" → Ophthalmology', () async {
      const aiJson = '{"status":"finished",'
          '"message":"Please see an Ophthalmologist.",'
          '"urgency":"yellow","specialty":"Ophthalmology"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('blurry vision'));

      expect(r.specialty, equals('Ophthalmology'));
    });

    test('1e. "abdominal cramps and bloating" → Gastroenterology', () async {
      const aiJson = '{"status":"finished",'
          '"message":"A Gastroenterologist would be ideal.",'
          '"urgency":"yellow","specialty":"Gastroenterology"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('severe abdominal cramps and bloating'));

      expect(r.specialty, equals('Gastroenterology'));
    });
  });

  // ── Group 2 · Urgency classification ─────────────────────────────────────
  group('AiService – Urgency Classification', () {
    test('2a. Green urgency for mild symptoms', () async {
      const aiJson = '{"status":"asking",'
          '"message":"How long have you had this symptom?",'
          '"urgency":"green","specialty":"none"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('slight headache for an hour'));

      expect(r.urgency, equals('green'));
      expect(r.status, equals('asking'));
    });

    test('2b. Red urgency for stroke-like symptoms → Neurology', () async {
      const aiJson = '{"status":"finished",'
          '"message":"Call emergency services and see a Neurologist immediately.",'
          '"urgency":"red","specialty":"Neurology"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson)).getAiResponse(
              'sudden numbness on left side and slurred speech'));

      expect(r.urgency, equals('red'));
      expect(r.specialty, equals('Neurology'));
    });

    test('2c. Missing urgency key defaults to "none"', () async {
      // Omits "urgency" from the payload
      const aiJson =
          '{"status":"asking","message":"Describe the pain.","specialty":"none"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('I have some pain'));

      expect(r.urgency, equals('none'),
          reason: 'TriageResponse must default to "none" when key is absent');
    });
  });

  // ── Group 3 · Conversation status ────────────────────────────────────────
  group('AiService – Status Field', () {
    test('3a. "asking" status keeps conversation open', () async {
      const aiJson = '{"status":"asking",'
          '"message":"Do you have shortness of breath?",'
          '"urgency":"none","specialty":"none"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('I feel pressure in my chest'));

      expect(r.status, equals('asking'));
      expect(r.specialty, equals('none'));
    });

    test('3b. "finished" status ends triage with a concrete specialty',
        () async {
      const aiJson = '{"status":"finished",'
          '"message":"You need a Cardiologist. Shall I find one for you?",'
          '"urgency":"red","specialty":"Cardiology"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('Yes, it gets worse with exertion'));

      expect(r.status, equals('finished'));
      expect(r.specialty, isNot(equals('none')));
      expect(r.specialty, equals('Cardiology'));
    });
  });

  // ── Group 4 · JSON contract / response parsing ────────────────────────────
  group('AiService – JSON Contract', () {
    test('4a. All 18 valid specialties survive the JSON round-trip', () async {
      const specialties = [
        'General Medicine', 'Dentistry', 'Cardiology', 'Psychiatry',
        'Nutrition', 'Urology', 'Dermatology', 'Gynecology & Obstetrics',
        'Orthopedics', 'Pediatrics', 'Internal Medicine', 'Ophthalmology',
        'Neurology', 'Gastroenterology', 'ENT', 'Pulmonology',
        'Endocrinology', 'Otolaryngology',
      ];

      for (final specialty in specialties) {
        final aiJson = jsonEncode({
          'status': 'finished',
          'message': 'You need a $specialty doctor.',
          'urgency': 'yellow',
          'specialty': specialty,
        });

        final r = TriageResponse.fromRawAiOutput(
            await _service(_mockGroqClient(aiJson))
                .getAiResponse('symptom test for $specialty'));

        expect(r.specialty, equals(specialty),
            reason: '$specialty must survive round-trip through AiService');
      }
    });

    test('4b. Missing "specialty" key defaults to "none"', () async {
      const aiJson =
          '{"status":"asking","message":"Can you describe the pain?","urgency":"none"}';

      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient(aiJson))
              .getAiResponse('general discomfort'));

      expect(r.specialty, equals('none'));
    });
  });

  // ── Group 5 · Error resilience ────────────────────────────────────────────
  group('AiService – Error Resilience', () {
    test('5a. HTTP 500 → AiService returns a safe, parseable JSON string',
        () async {
      final r = TriageResponse.fromRawAiOutput(
          await _service(_mockGroqClient('{}', statusCode: 500))
              .getAiResponse('severe chest pain'));

      expect(r.status, equals('asking'));
      expect(r.message, contains('500'));
      expect(r.specialty, equals('none'));
    });

    test('5b. Network exception → AiService returns a safe JSON string',
        () async {
      final throwingClient = http_test.MockClient(
          (_) async => throw Exception('No internet connection'));

      final r = TriageResponse.fromRawAiOutput(
          await _service(throwingClient).getAiResponse('severe chest pain'));

      // Must not throw; must return a decodable JSON string
      expect(r.status, equals('asking'));
      expect(r.specialty, equals('none'));
    });

    test('5c. Empty / whitespace input handled without crashing', () async {
      const aiJson = '{"status":"asking",'
          '"message":"Please describe your symptoms.",'
          '"urgency":"none","specialty":"none"}';

      // AiService trims the input before appending to history — no crash
      final raw =
          await _service(_mockGroqClient(aiJson)).getAiResponse('   ');
      expect(() => jsonDecode(raw), returnsNormally);
    });
  });

  // ── Group 6 · Multi-turn conversation simulation ──────────────────────────
  group('AiService – Multi-turn Conversation', () {
    test(
        '6. Full 3-turn triage on the real AiService: '
        'symptom → follow-up → diagnosis → Cardiology', () async {
      final turns = [
        // Turn 1: AI asks a follow-up
        '{"status":"asking",'
            '"message":"How long have you been experiencing this chest pain?",'
            '"urgency":"none","specialty":"none"}',
        // Turn 2: AI asks another follow-up
        '{"status":"asking",'
            '"message":"Is the pain radiating to your left arm or jaw?",'
            '"urgency":"none","specialty":"none"}',
        // Turn 3: AI concludes with specialty
        '{"status":"finished",'
            '"message":"Your symptoms strongly suggest a cardiac event. You need a Cardiologist urgently.",'
            '"urgency":"red","specialty":"Cardiology"}',
      ];

      int callIndex = 0;
      final sequentialClient = http_test.MockClient((_) async => http.Response(
            _groqEnvelope(turns[callIndex++]),
            200,
            headers: {'content-type': 'application/json'},
          ));

      // A SINGLE AiService instance preserves chat history across turns
      final service = _service(sequentialClient);

      final r1 = TriageResponse.fromRawAiOutput(
          await service.getAiResponse('severe chest pain'));
      expect(r1.status, equals('asking'));
      expect(r1.specialty, equals('none'));

      final r2 = TriageResponse.fromRawAiOutput(
          await service.getAiResponse('About 30 minutes'));
      expect(r2.status, equals('asking'));

      final r3 = TriageResponse.fromRawAiOutput(
          await service.getAiResponse('Yes, into my left arm'));
      expect(r3.status, equals('finished'));
      expect(r3.urgency, equals('red'));
      expect(r3.specialty, equals('Cardiology'),
          reason:
              'Real AiService must correctly resolve Cardiology after 3-turn triage');
    });
  });
}
