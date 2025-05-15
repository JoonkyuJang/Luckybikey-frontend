import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';

import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../../utils/providers/page_provider.dart';
import '../../../utils/providers/preference_provider.dart';
import '../../../utils/providers/kakao_login_provider.dart';

import 'kakao_share.dart';
import 'result_widget.dart';

class SurveyResultPage extends StatelessWidget {
  final ScreenshotController fullScreenshotController = ScreenshotController();
  final ScreenshotController kakaoScreenshotController = ScreenshotController();
  final String resultType;

  SurveyResultPage({super.key, required this.resultType});

  @override
  Widget build(BuildContext context) {
    final preferenceProvider = Provider.of<PreferenceProvider>(context);
    final pageProvider = Provider.of<PageProvider>(context, listen: false);
    final kakaoLoginProvider = Provider.of<KakaoLoginProvider>(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  /// 스크린샷에 포함될 영역
                  Screenshot(
                    controller: fullScreenshotController,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Screenshot(
                            controller: kakaoScreenshotController,
                            child: Column(
                              children: [
                                Text(
                                  '${kakaoLoginProvider.user?.kakaoAccount?.profile?.nickname ?? "사용자"} 님의 주행 취향은?',
                                  style: TextStyle(fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                resultWidget(resultType: resultType),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "취향 키워드 모아보기",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightGreen[700],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children:
                                preferenceProvider.likes.map((like) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Text(
                                      like,
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children:
                                preferenceProvider.dislikes.map((dislike) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.red),
                                    ),
                                    child: Text(
                                      dislike,
                                      style: TextStyle(
                                        color: Colors.red[800],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  /// 다운로드 & 공유 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.download, color: Colors.green[600]),
                        onPressed: () async {
                          await fullScreenshotController
                              .capture(
                                delay: Duration(milliseconds: 10),
                                pixelRatio:
                                    MediaQuery.of(context).devicePixelRatio,
                              )
                              .then((Uint8List? image) async {
                                if (image != null) {
                                  final directory =
                                      await getApplicationDocumentsDirectory();
                                  final imagePath =
                                      await File(
                                        '${directory.path}/image.png',
                                      ).create();
                                  await imagePath.writeAsBytes(image);
                                  await ImageGallerySaverPlus.saveFile(
                                    imagePath.path,
                                    name: 'screenshot',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('이미지가 저장되었습니다.')),
                                  );
                                }
                              });
                        },
                        tooltip: '다운로드',
                      ),
                      const SizedBox(width: 40),
                      IconButton(
                        icon: Icon(Icons.share, color: Colors.green[600]),
                        onPressed: () async {
                          try {
                            Uint8List? capturedImage =
                                await kakaoScreenshotController.capture();
                            if (capturedImage != null) {
                              await kakaoShareWithImage(capturedImage);
                            } else {
                              throw '이미지를 캡처하지 못했습니다.';
                            }
                          } catch (error) {
                            print('공유 실패: $error');
                          }
                        },
                        tooltip: '공유',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// 경로 검색 버튼
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 40,
                      ),
                    ),
                    onPressed: () {
                      pageProvider.setPage(1);
                      Navigator.popAndPushNamed(context, '/Search');
                    },
                    child: const Text(
                      '맞춤 경로 검색하러 가기',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 취향 키워드 수정 버튼 -> 추가하려면

// TextButton(
//   onPressed: () => {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) {
//           return EditKeywordsPage();
//         },
//       ),
//     )
//   },
//   child: Text(
//     '취향 키워드 수정하기',
//     style: const TextStyle(
//         color: Colors.black38, fontSize: 12),
//   ),
// ),
