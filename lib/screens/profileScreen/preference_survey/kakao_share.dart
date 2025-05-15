import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:path_provider/path_provider.dart';


Future<void> kakaoShareWithImage(Uint8List imageBytes) async {
  try {
    // 1. 캡처된 이미지를 파일로 저장
    File imageFile = await saveImageToTempFile(imageBytes);

    // 2. 이미지 업로드
    ImageUploadResult imageUploadResult =
    await ShareClient.instance.uploadImage(image: imageFile);
    String uploadedImageUrl = imageUploadResult.infos.original.url;


    int templateId = 114642; // 실제 템플릿 ID로 교체
    String url = "https://github.com/jjoing/luckybikey"; // 공유할 웹 페이지 URL

    // 3. 공유 템플릿 생성
    Uri uri = await ShareClient.instance.shareScrap(
      url: url,
      templateId: templateId, // Kakao Developers의 템플릿 ID
      templateArgs: {
        "THU": uploadedImageUrl, // 사용자 인자에 업로드된 이미지 URL 추가
      },
    );

    await ShareClient.instance.launchKakaoTalk(uri);
    print('카카오톡 공유 성공');
  } catch (error) {
    print('카카오톡 공유 실패: $error');
  }
}

Future<File> saveImageToTempFile(Uint8List imageBytes) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/screenshot.png');
  return file.writeAsBytes(imageBytes);
}


Future<void> kakaoShareForRanking(Uint8List imageBytes) async {
  try {
    // 1. 캡처된 이미지를 파일로 저장
    File imageFile = await saveImageToTempFile(imageBytes);

    // 2. 이미지 업로드
    ImageUploadResult imageUploadResult =
    await ShareClient.instance.uploadImage(image: imageFile);
    String uploadedImageUrl = imageUploadResult.infos.original.url;


    int templateId = 115223; // 실제 템플릿 ID로 교체
    String url = "https://github.com/jjoing/luckybikey"; // 공유할 웹 페이지 URL

    // 3. 공유 템플릿 생성
    Uri uri = await ShareClient.instance.shareScrap(
      url: url,
      templateId: templateId, // Kakao Developers의 템플릿 ID
      templateArgs: {
        "THU": uploadedImageUrl, // 사용자 인자에 업로드된 이미지 URL 추가
      },
    );

    await ShareClient.instance.launchKakaoTalk(uri);
    print('카카오톡 공유 성공');
  } catch (error) {
    print('카카오톡 공유 실패: $error');
  }
}