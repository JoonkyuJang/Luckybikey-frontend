import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class RecommendWidget extends StatefulWidget {
  final Function(NLatLng, String) onDestinationSelected;
  final GenerativeModel model;

  const RecommendWidget({
    Key? key,
    required this.onDestinationSelected,
    required this.model,
  }) : super(key: key);

  @override
  State<RecommendWidget> createState() => _RecommendWidgetState();
}

class _RecommendWidgetState extends State<RecommendWidget> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, String>> _messages = [];

  void _addMessage(String role, String content) {
    setState(() {
      _messages.add({'role': role, 'content': content});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  List<Map<String, dynamic>> safeParse(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map<Map<String, dynamic>?>((e) {
            final name = e['name']?.toString();
            final lat = double.tryParse((e['lat'] ?? e['latitude']).toString());
            final lng = double.tryParse(
              (e['lng'] ?? e['longitude']).toString(),
            );

            if (name == null || lat == null || lng == null) return null;

            return {'name': name, 'coord': NLatLng(lat, lng)};
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print("JSON 파싱 실패: $e");
      return [];
    }
  }

  Future<void> _sendToGemini(String message) async {
    setState(() {
      _isLoading = true;
      _locations = [];
    });

    final prompt = [
      Content.text(
        '사용자가 "$message"라고 했을 때, 한국 자전거 여행지 중 추천 3곳을 아래 JSON으로 알려줘. '
        '설명 포함해도 되지만 꼭 이 구조를 따라야 해:\n'
        '[{"name": "장소명", "latitude": 위도, "longitude": 경도, "description": "설명"}]',
      ),
    ];

    try {
      final response = await widget.model.generateContent(prompt);
      final text = response.text?.trim() ?? '';
      print("Gemini 응답 원문:\n$text");

      _addMessage("Gemini", "추천 결과가 도착했어요!");
      final parsed = safeParse(text);
      setState(() {
        _locations = parsed;
      });
    } catch (e) {
      print('Gemini 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('추천 실패: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildChatModal(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      ..._messages.map(
                        (m) => Align(
                          alignment:
                              m['role'] == 'user'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  m['role'] == 'user'
                                      ? Colors.lightGreen[100]
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(m['content'] ?? ''),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_locations.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            const Text(
                              'Gemini 추천 결과',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _locations.length,
                                itemBuilder: (context, index) {
                                  final loc = _locations[index];
                                  return GestureDetector(
                                    onTap: () {
                                      widget.onDestinationSelected(
                                        loc['coord'],
                                        loc['name'],
                                      );
                                      Navigator.pop(context);
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      elevation: 4,
                                      child: Container(
                                        width: 200,
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.place,
                                              size: 32,
                                              color: Colors.lightGreen[700],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              loc['name'],
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${loc['coord'].latitude}, ${loc['coord'].longitude}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: '어디로 가고 싶으신가요?',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.lightGreen),
                      onPressed: () {
                        final text = _chatController.text.trim();
                        if (text.isNotEmpty) {
                          _addMessage("user", text);
                          _sendToGemini(text);
                          _chatController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.grey[100],
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _buildChatModal(context),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightGreen[400],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Gemini에게 도착지 추천 받기',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
