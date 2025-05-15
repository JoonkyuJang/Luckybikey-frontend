import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'navigation_utils.dart';
import '../feedback/tap_widget.dart';
import '../feedback/navigation_end.dart';
import '../../../utils/providers/feedback_provider.dart';

class Navigation extends StatefulWidget {
  const Navigation({
    super.key,
    required this.routeInfo,
    required this.tts,
    required this.firestore,
    required this.authentication,
  });

  final Map<String, dynamic> routeInfo;
  final FlutterTts tts;
  final FirebaseFirestore firestore;
  final FirebaseAuth authentication;

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  final Key _mapKey = UniqueKey();
  Map<String, dynamic> navState = {};
  NaverMapController? ct;
  Timer? timer;
  FeedbackProvider? feedbackProvider;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    navState = {
      'Route': widget.routeInfo['route'],
      "Start": widget.routeInfo['route'][0],
      "End": widget.routeInfo['route'][widget.routeInfo['route'].length - 1],
      "CurrentPosition": {
        "latitude": widget.routeInfo['route'][0]["NLatLng"].latitude,
        "longitude": widget.routeInfo['route'][0]["NLatLng"].longitude,
      },
      "CurrentIndex": 0,
      "ProjectedPosition": {},
      "Angle": 0,
      "ttsFlag": [false, false, false],
      "finishFlag": false,
      "toggleFeedback": false,
      "toggleTime": 0,
      "time": 0,
    };

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      print('timer: ${t.tick}');

      setState(() {
        navState = updateNavState(navState, t.tick.toDouble(), ct, widget.tts);
        if (navState['toggleFeedback']) {
          feedbackProvider?.resetPop();
          showFeedbackDialogue(context, feedbackProvider!);
          navState['toggleFeedback'] = false;
        }

        NMarker marker1 = NMarker(
          id: 'test1',
          position: NLatLng(
            navState['ProjectedPosition']['latitude'],
            navState['ProjectedPosition']['longitude'],
          ),
          anchor: const NPoint(0.5, 0.5),
          size: const Size(40, 40),
          //iconTintColor: const Color.fromARGB(255, 214, 0, 0),
          icon: const NOverlayImage.fromAssetImage('assets/images/arrow.png'),
        );
        // NMarker marker2 = NMarker(
        //   id: 'test2',
        //   position: NLatLng(
        //     navState['CurrentPosition']['latitude'],
        //     navState['CurrentPosition']['longitude'],
        //   ),
        // );
        // NMarker marker3 = NMarker(
        //   id: 'test3',
        //   position: NLatLng(
        //     navState['Route'][navState['CurrentIndex']]['NLatLng'].latitude,
        //     navState['Route'][navState['CurrentIndex']]['NLatLng'].longitude,
        //   ),
        // );
        ct?.addOverlayAll({marker1});
        ct?.updateCamera(
          NCameraUpdate.withParams(
            target: NLatLng(
              navState['ProjectedPosition']['latitude'],
              navState['ProjectedPosition']['longitude'],
            ),
            zoom: 17,
            bearing: navState['Angle'],
            tilt: 45,
          ),
        );
      });
      // print("navState['Angle']: ${navState['Angle']}");
      // print("navState['CurrentPosition']: ${navState['CurrentPosition']}");
      // print("navState['CurrentIndex']: ${navState['CurrentIndex']}");

      if (navState['finishFlag']) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Navigationend(
              fullDistance: widget.routeInfo['full_distance'],
              tick: t.tick.toDouble(),
              firestore: widget.firestore,
              authentication: widget.authentication,
            );
          },
        );
        timer?.cancel();
      }
    });
  }

  void showFeedbackDialogue(
    BuildContext context,
    FeedbackProvider feedbackProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Future.delayed(const Duration(seconds: 8), () {
          if (!feedbackProvider.hasPopped) Navigator.of(context).pop();
        });

        return tapWidget(
          navState: navState,
          firestore: widget.firestore,
          authentication: widget.authentication,
          tts: widget.tts,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Completer<NaverMapController> mapControllerCompleter = Completer();
    feedbackProvider = Provider.of<FeedbackProvider>(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: <Widget>[
          NaverMap(
            key: _mapKey,
            options: NaverMapViewOptions(
              mapType: NMapType.navi,
              initialCameraPosition: NCameraPosition(
                target:
                    widget
                        .routeInfo['route'][0]['NLatLng'], // NLatLng로 변환된 출발지 좌표
                zoom: 17,
                bearing: calculateBearing(
                  widget.routeInfo['route'][0]['NLatLng'].latitude,
                  widget.routeInfo['route'][0]['NLatLng'].longitude,
                  widget.routeInfo['route'][1]['NLatLng'].latitude,
                  widget.routeInfo['route'][1]['NLatLng'].longitude,
                ),
                tilt: 45,
              ),
              locationButtonEnable: true,
              contentPadding: const EdgeInsets.all(10),
            ),
            forceGesture: true,
            // onMapTapped: (point, latLng) {
            //   setState(() {
            //     navState['CurrentPosition'] = {
            //       'latitude': latLng.latitude,
            //       'longitude': latLng.longitude,
            //     };
            //   });
            // },
            onMapReady: (controller) {
              mapControllerCompleter.complete(controller);
              setState(() {
                ct = controller;
              });
              // ct?.setLocationTrackingMode(NLocationTrackingMode.follow);
              final path1 = NPathOverlay(
                id: 'route',
                coords: List<NLatLng>.from(
                  widget.routeInfo['route'].map((e) => e["NLatLng"]),
                ), // NLatLng로 변환된 좌표 리스트
                color: const Color.fromARGB(255, 119, 201, 27),
                width: 5,
              );
              controller.addOverlay(path1);
            },
          ),
          Positioned(
            top: 10,
            right: 10,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ),
          if (navState['toggleFeedback'])
            Positioned(
              top: 80,
              left: MediaQuery.of(context).size.width * 0.05,
              right: MediaQuery.of(context).size.width * 0.05,
              child: tapWidget(
                navState: navState,
                firestore: widget.firestore,
                authentication: widget.authentication,
                tts: widget.tts,
              ),
            ),
        ],
      ),
    );
  }
}
