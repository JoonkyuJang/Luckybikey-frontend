import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../utils/mapAPI.dart';
import 'navigation_utils.dart';

Future<List<Map<String, dynamic>>> pulicBike() async {
  final results = await http.get(
    Uri.parse(
      'http://openapi.seoul.go.kr:8088/$public_bike_key/json/bikeList/1/1000/',
    ),
  );
  List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
    jsonDecode(results.body)['rentBikeStatus']["row"].map(
      (item) => {
        "NLatLng": NLatLng(
          double.parse(item['stationLatitude']),
          double.parse(item['stationLongitude']),
        ),
        "StationName": item['stationName'],
        "ParkingBikeTotCnt": item['parkingBikeTotCnt'],
        "RackTotCnt": item['rackTotCnt'],
        "Shared": item['shared'],
        "StationId": item['stationId'],
      },
    ),
  );
  return result;
}

//길찾기 3번 연결하기

void searchRoute(
  searchResult,
  usePublicBike,
  publicBikes,
  firestore,
  authentication,
  routeSelectorProvider,
) async {
  String userGroup = await firestore
      .collection('users')
      .doc(authentication.currentUser?.uid)
      .get()
      .then((value) => value.data()!['label'].toString());
  List<double> groupPreference = await firestore
      .collection('clusters')
      .doc(userGroup)
      .get()
      .then((value) => List<double>.from(value.data()!['centroid']));
  if (usePublicBike) {
    Map<String, dynamic> startStation = _getClosestPublicBikeStation(
      searchResult[0]['mapy'],
      searchResult[0]['mapx'],
      publicBikes,
    );
    Map<String, dynamic> endStation = _getClosestPublicBikeStation(
      searchResult[1]['mapy'],
      searchResult[1]['mapx'],
      publicBikes,
    );
    _requestRoutePublic([
      {
        "StartPoint": {
          "lat": searchResult[0]['mapy'],
          "lon": searchResult[0]['mapx'],
        },
        "EndPoint": {
          "lat": startStation['NLatLng'].latitude,
          "lon": startStation['NLatLng'].longitude,
        },
        "UserTaste": false,
        "UserGroup": userGroup,
        "GroupPreference": groupPreference,
      },
      {
        "StartPoint": {
          "lat": startStation['NLatLng'].latitude,
          "lon": startStation['NLatLng'].longitude,
        },
        "EndPoint": {
          "lat": endStation['NLatLng'].latitude,
          "lon": endStation['NLatLng'].longitude,
        },
        "UserTaste": false,
        "UserGroup": userGroup,
        "GroupPreference": groupPreference,
      },
      {
        "StartPoint": {
          "lat": endStation['NLatLng'].latitude,
          "lon": endStation['NLatLng'].longitude,
        },
        "EndPoint": {
          "lat": searchResult[1]['mapy'],
          "lon": searchResult[1]['mapx'],
        },
        "UserTaste": false,
        "UserGroup": userGroup,
        "GroupPreference": groupPreference,
      },
    ], routeSelectorProvider);
  } else {
    _requestRoute({
      "StartPoint": {
        "lat": searchResult[0]['mapy'],
        "lon": searchResult[0]['mapx'],
      },
      "EndPoint": {
        "lat": searchResult[1]['mapy'],
        "lon": searchResult[1]['mapx'],
      },
      "UserTaste": false,
      "UserGroup": userGroup,
      "GroupPreference": groupPreference,
    }, routeSelectorProvider);
  }
}

//get closest 비어있지 않은 public bike
Map<String, dynamic> _getClosestPublicBikeStation(
  curLat,
  curLng,
  List<Map<String, dynamic>> publicBikes,
) {
  double? closestDistance;
  Map<String, dynamic> nearestStation = {};

  for (var station in publicBikes) {
    // 자전거 수가 0인 대여소는 제외
    if (int.parse(station['ParkingBikeTotCnt']) > 0) {
      // 대여소 위치
      double stationLat = station['NLatLng'].latitude;
      double stationLng = station['NLatLng'].longitude;

      // 두 지점 간의 거리 계산 (하버사인 공식 사용)
      double distance = calculateDistance(
        curLat,
        curLng,
        stationLat,
        stationLng,
      );

      // 가장 가까운 대여소 업데이트
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        nearestStation = station;
      }
    }
  }

  return nearestStation;
}

void _requestRoute(req, routeSelectorProvider) async {
  final Map<String, dynamic> call = {
    "StartPoint": {
      "lat": req['StartPoint']['lat'],
      "lon": req['StartPoint']['lon'],
    },
    "EndPoint": {"lat": req['EndPoint']['lat'], "lon": req['EndPoint']['lon']},
    "UserTaste": true,
    "UserGroup": req['UserGroup'],
    "GroupPreference": req['GroupPreference'],
  };

  final results = await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
      .httpsCallable(
        'request_route',
        options: HttpsCallableOptions(timeout: Duration(seconds: 600)),
      )
      .call(call);
  for (int index = 0; index < 5; index++) {
    final route = results.data[index];
    // print(route);
    routeSelectorProvider.setRoute({
      "route": _preprocessRoute(
        List<Map<String, dynamic>>.from(
          route["path"].map((point) {
            return {
              "NLatLng": NLatLng(point['lat'], point['lon']),
              "distance": point['distance'],
              "id": point['node_id'],
            };
          }),
        ),
      ),
      "full_distance": route['full_distance'],
    }, index);
  }
}

void _requestRoutePublic(reqs, routeSelectorProvider) async {
  final List<Map<String, dynamic>> calls = List<Map<String, dynamic>>.generate(
    3,
    (index) {
      final req = reqs[index];
      return {
        "Index": index,
        "StartPoint": {
          "lat": req['StartPoint']['lat'],
          "lon": req['StartPoint']['lon'],
        },
        "EndPoint": {
          "lat": req['EndPoint']['lat'],
          "lon": req['EndPoint']['lon'],
        },
        "UserTaste": true,
        "UserGroup": req['UserGroup'],
        "GroupPreference": req['GroupPreference'],
      };
    },
  );

  List<HttpsCallableResult<dynamic>?> http_results =
      List<HttpsCallableResult<dynamic>?>.filled(3, null);

  await Future.wait(
    calls.map((req) async {
      http_results[req['Index']] = await FirebaseFunctions.instanceFor(
            region: 'asia-northeast3',
          )
          .httpsCallable(
            'request_route',
            options: HttpsCallableOptions(timeout: Duration(seconds: 600)),
          )
          .call(req);
    }),
  );

  List<List<dynamic>> results = List<List<dynamic>>.generate(5, (index) {
    return List<dynamic>.generate(3, (i) {
      return http_results[i]?.data[index];
    });
  });
  // 모든 route 정보 합치기
  for (int index = 0; index < 3; index++) {
    final route = results[index];
    List<Map<String, dynamic>> combinedRoute =
        List<Map<String, dynamic>>.from(
          route[0].data['path'].map((point) {
            return {
              "NLatLng": NLatLng(point['lat'], point['lon']),
              "distance": point['distance'],
              "id": point['node_id'],
            };
          }),
        ) +
        List<Map<String, dynamic>>.from(
          route[1].data['path'].sublist(1).map((point) {
            return {
              "NLatLng": NLatLng(point['lat'], point['lon']),
              "distance": point['distance'],
              "id": point['node_id'],
            };
          }),
        ) +
        List<Map<String, dynamic>>.from(
          route[2].data['path'].sublist(1).map((point) {
            return {
              "NLatLng": NLatLng(point['lat'], point['lon']),
              "distance": point['distance'],
              "id": point['node_id'],
            };
          }),
        );

    // full_distance 계산
    double combinedFullDistance =
        route[0].data['full_distance'] +
        route[1].data['full_distance'] +
        route[2].data['full_distance'];

    routeSelectorProvider.setRoute({
      "route": _preprocessRoute(combinedRoute),
      "full_distance": combinedFullDistance,
    }, index);
  }
}

List<Map<String, dynamic>> _preprocessRoute(List<Map<String, dynamic>> route) {
  List<Map<String, dynamic>> routeInfo = [];

  for (var i = 0; i < route.length - 2; i++) {
    final Map<String, dynamic> currentNode = route[i];
    final Map<String, dynamic> nextNode = route[i + 1];
    final Map<String, dynamic> nextNextNode = route[i + 2];

    final link1 = [
      nextNode["NLatLng"].longitude - currentNode["NLatLng"].longitude,
      nextNode["NLatLng"].latitude - currentNode["NLatLng"].latitude,
      0.0,
    ];
    final link1Norm = sqrt(pow(link1[0], 2) + pow(link1[1], 2));
    final link2 = [
      nextNextNode["NLatLng"].longitude - nextNode["NLatLng"].longitude,
      nextNextNode["NLatLng"].latitude - nextNode["NLatLng"].latitude,
      0.0,
    ];
    final link2Norm = sqrt(pow(link2[0], 2) + pow(link2[1], 2));
    final crossProduct = [
      link1[1] * link2[2] - link1[2] * link2[1],
      link1[2] * link2[0] - link1[0] * link2[2],
      link1[0] * link2[1] - link1[1] * link2[0],
    ];
    final dotProduct =
        link1[0] * link2[0] + link1[1] * link2[1] + link1[2] * link2[2];
    routeInfo.add({
      "NLatLng": currentNode["NLatLng"], // 현재 노드의 좌표
      "distance": nextNode['distance'], // 다음 노드까지의 거리
      "id": currentNode['id'], // 현재 노드의 id
      "isleft": crossProduct[2] > 0, // 다음 노드에서 좌회전인지 우회전인지 여부
      "angle":
          acos(dotProduct / (link1Norm * link2Norm)) *
          180 /
          pi, // 다음 노드에서의 회전각도
    });
  }
  routeInfo.add({
    "NLatLng": route[route.length - 2]["NLatLng"],
    "distance": route[route.length - 1]['distance'],
    "id": route[route.length - 2]['id'],
    "isleft": null,
    "angle": null,
  });
  routeInfo.add({
    "NLatLng": route[route.length - 1]["NLatLng"],
    "distance": null,
    "id": route[route.length - 1]['id'],
    "isleft": null,
    "angle": null,
  });

  return routeInfo;
}

Future<List<Map<String, dynamic>>> searchRequest(req) async {
  String query = req['query'];
  final results = await http.get(
    Uri.parse(
      'https://openapi.naver.com/v1/search/local.json?query=$query&display=8&start=1&sort=random',
    ),
    headers: {
      "X-Naver-Client-Id": client_id,
      "X-Naver-Client-Secret": client_secret,
    },
  );
  List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
    jsonDecode(results.body)['items'].map((item) {
      return {
        "title": item['title'].replaceAll(RegExp(r'<[^>]*>'), ''),
        "link": item['link'],
        "category": item['category'],
        "description": item['description'],
        "telephone": item['telephone'],
        "address": item['address'],
        "roadAddress": item['roadAddress'],
        "NLatLng": NLatLng(
          double.parse(item['mapy']) / 10e6,
          double.parse(item['mapx']) / 10e6,
        ),
        "mapx": double.parse(item['mapx']) / 10e6,
        "mapy": double.parse(item['mapy']) / 10e6,
      };
    }),
  );
  return result;
}
