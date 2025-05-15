import "package:flutter/material.dart";

// 결과 위젯
class resultWidget extends StatelessWidget {
  final String resultType;

  resultWidget({super.key, required this.resultType});

  final Map<String, Map<String, String>> resultData = {
    "scenery": {
      "title": "자유로운 영혼의 낭만파!",
      "description": "빨리 목적지를 향해 가기보다는 주변을 둘러보기를 좋아하는 당신은 자유로운 영혼의 낭만파 라이더입니다!",
      "imagePath": "assets/images/survey_result/scenery.webp",
    },
    "health": {
      "title": "헛둘헛둘! 나는야 운동 매니아",
      "description":
      "자전거를 이동 수단으로만 생각하지 않는 당신은 운동을 즐기는 멋진 스포츠인! 스피드와 험난한 코스를 즐겨보세요:)",
      "imagePath": "assets/images/survey_result/health.webp",
    },
    "safety": {
      "title": "안!전! 나는야 신호지킴이, \n안전제일주의자",
      "description": "자전거 전용도로를 좋아하는 당신은 도로 위 안전 지킴이! 자전거 길과 함께 안전한 주행을 즐겨요!",
      "imagePath": "assets/images/survey_result/safety.webp",
    },
    "fast": {
      "title": "최단속도, 최대효율! \n난 오로지 목적지를 향한다",
      "description": "산도 신호도, 나를 막을 수 없다! 오로지 가장 빠른 길만을 추구하는 당신은 혹시 ISTJ..?",
      "imagePath": "assets/images/survey_result/fast.webp",
    },
  };

  @override
  Widget build(BuildContext context) {
    final data = resultData[resultType] ??
        {
          "title": "알 수 없는 결과",
          "description": "결과 데이터를 불러올 수 없습니다.",
          "imagePath": "assets/images/survey_result/default.png",
        };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          data["title"]!,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.lightGreen,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            data["imagePath"]!,
            height: 140,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            data["description"]!,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}