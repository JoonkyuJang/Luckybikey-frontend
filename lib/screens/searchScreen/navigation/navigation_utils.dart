import 'dart:math';

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

Map<String, dynamic> updateNavState(
  Map<String, dynamic> navState,
  double tick,
  NaverMapController? ct,
  FlutterTts tts,
) {
  Map beforePosition = navState['CurrentPosition'];

  _determinePosition().then((value) {
    navState['CurrentPosition'] = {
      'latitude': value.latitude,
      'longitude': value.longitude,
    };
  });

  final distanceDelta = calculateDistance(
    beforePosition['latitude'],
    beforePosition['longitude'],
    navState['CurrentPosition']['latitude'],
    navState['CurrentPosition']['longitude'],
  );

  if (distanceDelta < 2 &&
      tick - navState['toggleTime'] > 10 &&
      navState['finishFlag'] == false) {
    navState['toggleFeedback'] = true;
    navState['toggleTime'] = tick;
  }

  //사정거리안에 들어오거나 가장 가까운 노드 찾기
  //그 노드가 연결한 Route들 중 점 직선 사이 거리가 가장 가까운 node 쌍 찾기_ (node1, node2) node1 to node2
  final newIndex = _getProjectionNodes(
    navState['Route'],
    navState['CurrentPosition']['latitude'],
    navState['CurrentPosition']['longitude'],
    navState['CurrentIndex'],
  );
  if (newIndex != navState['CurrentIndex']) {
    navState['CurrentIndex'] = newIndex;
    navState['ttsFlag'] = [false, false, false];
  }
  //투영한 위치 반환
  //이걸로 update

  navState['ProjectedPosition'] = _getProjectedPosition(
    navState['Route'],
    navState['CurrentPosition']['latitude'],
    navState['CurrentPosition']['longitude'],
    navState['CurrentIndex'],
  );

  //회전 정보 (State, 상수)
  //직진 => distance 몇까지 직진인지 확인()
  //=> 20m 이하 : []회전, 0m(후 []회전)
  //=> 20m 이상 50m 이하 직진 : 직진 후 []회전, 0m(후 []회전)
  //=> 50m 이상 직진 : 직진, 0m(동안 직진)
  //[]회전 => state는 항상 []회전
  //=> 회전 후 직진 : []회전, 0
  //=> []회전 후 []회전 : []회전, 1
  //=> []회전 후 {}회전 : []회전, 2

  final currentNode = navState['Route'][navState['CurrentIndex']];
  final nextNode = navState['Route'][navState['CurrentIndex'] + 1];

  final distance = calculateDistance(
    navState['ProjectedPosition']['latitude'],
    navState['ProjectedPosition']['longitude'],
    nextNode['NLatLng'].latitude,
    nextNode['NLatLng'].longitude,
  );

  final distanceToEnd = calculateDistance(
    navState['ProjectedPosition']['latitude'],
    navState['ProjectedPosition']['longitude'],
    navState['Route'][navState['Route'].length - 1]['NLatLng'].latitude,
    navState['Route'][navState['Route'].length - 1]['NLatLng'].longitude,
  );

  navState['Angle'] = calculateBearing(
    currentNode['NLatLng'].latitude,
    currentNode['NLatLng'].longitude,
    nextNode['NLatLng'].latitude,
    nextNode['NLatLng'].longitude,
  );

  print('current index: ${navState["CurrentIndex"]} distance: $distance');

  if (distanceToEnd < 50) {
    tts.speak('목적지에 도착했습니다');
    print('목적지에 도착했습니다');
    navState['finishFlag'] = true;
    return navState;
  }
  if (navState['CurrentIndex'] == navState['Route'].length - 2) {
    if (distance < 50) {
      tts.speak('목적지에 도착했습니다');
      print('목적지에 도착했습니다');
      navState['finishFlag'] = true;
      return navState;
    } else if (navState['ttsFlag'][0] == false) {
      tts.speak('목적지까지 ${(distance / 10).floor() * 10}미터 남았습니다');
      print('목적지까지 ${distance.round()}미터 남았습니다');
      navState['ttsFlag'][0] = true;
    }
  } else {
    var ttsMessage = '';
    if (distance < 50) {
      if (navState['ttsFlag'][0] == false) {
        ttsMessage = '${(distance / 10).floor() * 10}미터 앞 ';
        if (currentNode['angle'] > 60) {
          switch (currentNode['isleft']) {
            case true:
              ttsMessage += '좌회전입니다';
            case false:
              ttsMessage += '우회전입니다';
          }
        } else {
          ttsMessage += '직진입니다';
        }
        tts.speak(ttsMessage);
        print(ttsMessage);
        navState['ttsFlag'][0] = true;
      }
    } else if (distance < 100) {
      if (navState['ttsFlag'][1] == false) {
        ttsMessage = '${(distance / 10).floor() * 10}미터 후 ';
        if (currentNode['angle'] > 60) {
          switch (currentNode['isleft']) {
            case true:
              ttsMessage += '좌회전하세요';
            case false:
              ttsMessage += '우회전하세요';
          }
        } else {
          ttsMessage += '직진하세요';
        }
        tts.speak(ttsMessage);
        print(ttsMessage);
        navState['ttsFlag'][1] = true;
      }
    } else if (navState['ttsFlag'][2] == false) {
      ttsMessage = '${(distance / 10).floor() * 10}미터동안 직진입니다';
      tts.speak(ttsMessage);
      print(ttsMessage);
      navState['ttsFlag'][2] = true;
    }
  }
  return navState;
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // 지구 반경 (미터)
  double phi1 = lat1 * (3.141592653589793 / 180);
  double phi2 = lat2 * (3.141592653589793 / 180);
  double deltaPhi = (lat2 - lat1) * (3.141592653589793 / 180);
  double deltaLambda = (lon2 - lon1) * (3.141592653589793 / 180);

  double a =
      (sin(deltaPhi / 2) * sin(deltaPhi / 2)) +
      cos(phi1) * cos(phi2) * (sin(deltaLambda / 2) * sin(deltaLambda / 2));
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c; // 거리 (미터 단위)
}

double _calculateTriangleDistance(
  double pointLat,
  double pointLon,
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  double distance = 99999999999;
  double projectionFactor =
      ((pointLat - lat1) * (lat2 - lat1) + (pointLon - lon1) * (lon2 - lon1)) /
      ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1));
  if (projectionFactor >= -0.5 && projectionFactor <= 1.5) {
    distance =
        ((lon2 - lon1) * (lat1 - pointLat) - (lon1 - pointLon) * (lat2 - lat1))
            .abs() /
        sqrt(pow(lon2 - lon1, 2) + pow(lat2 - lat1, 2));
  } else if (projectionFactor < -0.5) {
    distance = sqrt(
      (pointLat - lat1) * (pointLat - lat1) +
          (pointLon - lon1) * (pointLon - lon1),
    );
  } else if (projectionFactor > 1.5) {
    distance = sqrt(
      (pointLat - lat2) * (pointLat - lat2) +
          (pointLon - lon2) * (pointLon - lon2),
    );
  }

  return distance;
}

Map<String, dynamic> _getProjectedPosition(
  List<Map<String, dynamic>> route,
  double currentLatitude,
  double currentLongitude,
  int projectionNodeIndex,
) {
  var point = route[projectionNodeIndex];
  var nextPoint = route[projectionNodeIndex + 1];

  // 직선의 두 점 (point)과 (nextPoint) 사이에서 currentPosition을 투영
  double dx = nextPoint['NLatLng'].latitude - point['NLatLng'].latitude;
  double dy = nextPoint['NLatLng'].longitude - point['NLatLng'].longitude;
  double dotProduct =
      (currentLatitude - point['NLatLng'].latitude) * dx +
      (currentLongitude - point['NLatLng'].longitude) * dy;
  double lineLengthSquare = dx * dx + dy * dy;
  double projectionFactor = dotProduct / lineLengthSquare;

  double projectionLatitude = 0;
  double projectionLongitude = 0;

  // 투영된 점 계산
  if (projectionFactor < 0) {
    projectionLatitude = point['NLatLng'].latitude;
    projectionLongitude = point['NLatLng'].longitude;
  } else if (projectionFactor > 1) {
    projectionLatitude = nextPoint['NLatLng'].latitude;
    projectionLongitude = nextPoint['NLatLng'].longitude;
  } else {
    projectionLatitude = point['NLatLng'].latitude + projectionFactor * dx;
    projectionLongitude = point['NLatLng'].longitude + projectionFactor * dy;
  }

  return {'latitude': projectionLatitude, 'longitude': projectionLongitude};
}

int _getProjectionNodes(
  List<Map<String, dynamic>> route,
  double currentLatitude,
  double currentLongitude,
  int lastIndex,
) {
  List<int> closeNodeIndexList = []; //index 쌍 출발점 Index 저장
  int projectionNodeIndex = -1;
  int startIndex = lastIndex;

  if (lastIndex > 2) {
    startIndex -= 2;
  }

  for (int i = startIndex; i < route.length - 1; i++) {
    // 현재 노드 (point)와 그 다음 노드 (nextPoint)
    var point = route[i];
    var nextPoint = route[i + 1];

    NLatLng latLng = point['NLatLng'];
    double pointLatitude = latLng.latitude;
    double pointLongitude = latLng.longitude;

    NLatLng nextLatLng = nextPoint['NLatLng'];
    double nextPointLatitude = nextLatLng.latitude;
    double nextPointLongitude = nextLatLng.longitude;

    // 두 점 사이의 거리 계산
    double distance = calculateDistance(
      currentLatitude,
      currentLongitude,
      pointLatitude,
      pointLongitude,
    );
    double nextDistance = calculateDistance(
      currentLatitude,
      currentLongitude,
      nextPointLatitude,
      nextPointLongitude,
    );

    // 가까운 노드들만 추가 (50미터 이내로)
    if (distance < 10 ||
        (distance < nextDistance && projectionNodeIndex == -1)) {
      closeNodeIndexList.add(i);
    }

    // 3개 이상의 노드가 추가되었고, 현재 노드와 다음 노드의 거리가 다르면 종료 ???
    if (closeNodeIndexList.length > 6 && distance > nextDistance) {
      break;
    }
  }

  double minDistance = 1000000000000;
  double lastNodeDistance = calculateDistance(
    currentLatitude,
    currentLongitude,
    route[lastIndex]['NLatLng'].latitude,
    route[lastIndex]['NLatLng'].longitude,
  );
  double lastNodetoNextDistance = calculateDistance(
    route[lastIndex]['NLatLng'].latitude,
    route[lastIndex]['NLatLng'].longitude,
    route[lastIndex + 1]['NLatLng'].latitude,
    route[lastIndex + 1]['NLatLng'].longitude,
  );

  // 점과 직선 사이의 거리를 계산하여 가장 작은 pair를 선택
  for (int i in closeNodeIndexList) {
    // 점과 직선 사이의 최소 거리 계산 (여기서는 예시로 단순히 거리 계산)
    double projectionDistance = _calculateTriangleDistance(
      currentLatitude,
      currentLongitude,
      route[i]['NLatLng'].latitude,
      route[i]['NLatLng'].longitude,
      route[i + 1]['NLatLng'].latitude,
      route[i + 1]['NLatLng'].longitude,
    );
    if (minDistance > projectionDistance) {
      minDistance = projectionDistance;
      projectionNodeIndex = i;
    }
    // 직선과 점 사이의 거리가 최소일 경우에 projectionNodeList에 추가
  }

  double nextNodeDistance = calculateDistance(
    currentLatitude,
    currentLongitude,
    route[lastIndex + 1]['NLatLng'].latitude,
    route[lastIndex + 1]['NLatLng'].longitude,
  );

  // 이전 노드에 계속 머물러 있지만, 다음 노드와 거리가 가까워져 다음 노드로 이동되는 것 방지
  // minDistance가 5보다 크고 lastIndex 노드와 다음 노드 사이의 거리보다 현 위치에서 last Index Node까지의 거리가 더 작을 경우 lastIndex 반환
  if (nextNodeDistance > 10 && lastNodeDistance < lastNodetoNextDistance + 10) {
    projectionNodeIndex = lastIndex;
  }
  // ProjectionNodeList 반환
  return projectionNodeIndex;
}

Future<Position> _determinePosition() async {
  return await Geolocator.getCurrentPosition();
}

double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  return (450 - 180 / pi * atan2(lat2 - lat1, lon2 - lon1)) % 360;
}

List<int> getRandomIndex(int length) {
  List<int> randomIndex = [];
  while (randomIndex.length < 10) {
    int index = Random().nextInt(length);
    if (!randomIndex.contains(index)) {
      randomIndex.add(index);
    }
  }
  return randomIndex;
}
