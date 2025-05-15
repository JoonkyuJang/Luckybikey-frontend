import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utils/providers/preference_provider.dart';

class EditKeywordsPage extends StatefulWidget {
  const EditKeywordsPage({super.key});

  @override
  _EditKeywordsPageState createState() => _EditKeywordsPageState();
}

class _EditKeywordsPageState extends State<EditKeywordsPage> {
  final List<Map<String, dynamic>> allKeywords = [
    {"type": "like", "keyword": "풍경"},
    {"type": "like", "keyword": "안전"},
    {"type": "like", "keyword": "속도"},
    {"type": "dislike", "keyword": "통행량"},
    {"type": "dislike", "keyword": "신호"},
    {"type": "dislike", "keyword": "오르막"},
  ];

  List<String> availableLikes = [];
  List<String> availableDislikes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preferenceProvider =
      Provider.of<PreferenceProvider>(context, listen: false);
      final currentLikes = preferenceProvider.likes;
      final currentDislikes = preferenceProvider.dislikes;

      setState(() {
        availableLikes = allKeywords
            .where((e) =>
        e["type"] == "like" && !currentLikes.contains(e["keyword"]))
            .map((e) => e["keyword"] as String)
            .toList();

        availableDislikes = allKeywords
            .where((e) =>
        e["type"] == "dislike" &&
            !currentDislikes.contains(e["keyword"]))
            .map((e) => e["keyword"] as String)
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final preferenceProvider = Provider.of<PreferenceProvider>(context);
    final currentLikes = preferenceProvider.likes;
    final currentDislikes = preferenceProvider.dislikes;

    return Scaffold(
      appBar: AppBar(title: Text('취향 키워드 수정하기', style: TextStyle(color: Colors.lightGreen),),
        backgroundColor: Colors.white,),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 좋아요 섹션
            _buildKeywordSection(
              title: '좋아요!',
              color: Colors.green,
              keywords: currentLikes,
              availableKeywords: availableLikes,
              onAdd: (data) {
                setState(() {
                  currentLikes.add(data);
                  availableLikes.remove(data);
                  preferenceProvider.setLikes(currentLikes);
                });
              },
              onRemove: (data) {
                setState(() {
                  currentLikes.remove(data);
                  availableLikes.add(data);
                  preferenceProvider.setLikes(currentLikes);
                });
              },
            ),
            SizedBox(height: 20),
            // 싫어요 섹션
            _buildKeywordSection(
              title: '싫어요!',
              color: Colors.red,
              keywords: currentDislikes,
              availableKeywords: availableDislikes,
              onAdd: (data) {
                setState(() {
                  currentDislikes.add(data);
                  availableDislikes.remove(data);
                  preferenceProvider.setDislikes(currentDislikes);
                });
              },
              onRemove: (data) {
                setState(() {
                  currentDislikes.remove(data);
                  availableDislikes.add(data);
                  preferenceProvider.setDislikes(currentDislikes);
                });
              },
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightGreen,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
              ),
              onPressed: () {
                Navigator.pop(context); // 결과 페이지로 돌아가기
              },
              child: const Text(
                '결과 페이지로 돌아가기',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordSection({
    required String title,
    required Color color,
    required List<String> keywords,
    required List<String> availableKeywords,
    required Function(String) onAdd,
    required Function(String) onRemove,
  }) {
    return Column(
      children: [
        // 키워드 섹션 박스
        Container(
          width: 300,
          height: 200,
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Expanded(
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (data) {
                    // 추가 가능한 키워드인지 확인
                    return allKeywords.any((e) =>
                        e["keyword"] == data &&
                            e["type"] ==
                                (title == '좋아요!' ? "like" : "dislike"));
                  },
                  onAccept: (data) {
                    onAdd(data);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Wrap(
                      spacing: 10,
                      children: keywords
                          .map((keyword) => Chip(
                        label: Text(keyword),
                        backgroundColor: color,
                        labelStyle: TextStyle(color: Colors.white),
                        deleteIcon:
                        Icon(Icons.close, color: Colors.white),
                        onDeleted: () => onRemove(keyword),
                      ))
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        // 추가 가능한 키워드 섹션
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: [
              Text(
                '추가 가능한 $title 키워드',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 10,
                children: availableKeywords
                    .map((keyword) => Draggable<String>(
                  data: keyword,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Chip(
                      label: Text(keyword),
                      backgroundColor: color,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.5,
                    child: Chip(
                      label: Text(keyword),
                      backgroundColor: color,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                  child: Chip(
                    label: Text(keyword),
                    backgroundColor: color,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
