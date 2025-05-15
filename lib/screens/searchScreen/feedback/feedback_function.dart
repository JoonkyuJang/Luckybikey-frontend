import 'package:cloud_functions/cloud_functions.dart';

void feedback(navState, userGroup, featureIndex) {
  print('node1 : ${navState['Route'][navState['CurrentIndex']]["id"]}');
  print('node2 : ${navState['Route'][navState['CurrentIndex'] + 1]["id"]}');
  print('label : $userGroup');

  List pref = [0, 0, 0, 0, 0, 0, 0, 0];
  pref[featureIndex] = 1;

  FirebaseFunctions.instanceFor(region: 'asia-northeast3').httpsCallable(
    'update_feedback',
    options: HttpsCallableOptions(timeout: Duration(seconds: 600)),
  )({
    "connection": {
      "node1": '${navState['Route'][navState['CurrentIndex']]["id"]}',
      "node1_lat":
          '${navState['Route'][navState['CurrentIndex']]["NLatLng"].latitude}',
      "node1_lon":
          '${navState['Route'][navState['CurrentIndex']]["NLatLng"].longitude}',
      "node2": '${navState['Route'][navState['CurrentIndex'] + 1]["id"]}',
      "node2_lat":
          '${navState['Route'][navState['CurrentIndex'] + 1]["NLatLng"].latitude}',
      "node2_lon":
          '${navState['Route'][navState['CurrentIndex'] + 1]["NLatLng"].longitude}',
    },
    "label": userGroup,
    "pref": pref,
  });
}
