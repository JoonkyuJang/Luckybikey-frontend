import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlng/latlng.dart';
import '../../../utils/mapAPI.dart';

class GeminiService {
  static const _apiKey = gemini_key;
  static const _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey';

  /// 사용자 메시지를 기반으로 장소 추천을 요청하고, JSON 형태로 좌표와 이름을 파싱함
  static Future<List<Map<String, dynamic>>> getSuggestions(
    String userMessage,
  ) async {
    final prompt = '''
너는 자전거 경로 추천 도우미야. 사용자가 "${userMessage}"라고 말했을 때,
한국 내 자전거 여행지 3곳을 추천해줘. 아래 형식으로만 JSON 응답을 줘.

[{"name": "한강공원", "lat": 37.55, "lng": 126.97}, {"name": "올림픽공원", "lat": 37.52, "lng": 127.12}, {"name": "북서울꿈의숲", "lat": 37.62, "lng": 127.03}]
다른 말 하지 말고 위처럼 JSON만 응답해줘.
''';

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];

      final decodedList = jsonDecode(text);
      return (decodedList as List)
          .map((e) => {'name': e['name'], 'coord': LatLng(e['lat'], e['lng'])})
          .toList();
    } else {
      throw Exception('Gemini 응답 실패: ${response.body}');
    }
  }
}
