import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../utils/providers/route_selector_provider.dart';

class RouteSelector extends StatefulWidget {
  const RouteSelector({super.key, this.ct});

  final NaverMapController? ct;

  @override
  State<RouteSelector> createState() => _RouteSelectorState();
}

class _RouteSelectorState extends State<RouteSelector> {
  final List<String> _routeInfo = [
    '취향 추천 길',
    '가장 빠른 길',
    '풍경 좋은 길',
    '가장 안전한 길',
    '자전거 길 우선',
  ];

  @override
  Widget build(BuildContext context) {
    final RouteSelectorProvider routeSelectorProvider =
        Provider.of<RouteSelectorProvider>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 130,
      child: ListView.builder(
        itemCount: routeSelectorProvider.resultRoute.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          return routeSelectorProvider.resultRoute[index].isEmpty
              ? Container(
                width: MediaQuery.of(context).size.width * 0.35,
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 55 - MediaQuery.of(context).size.width * 0.055,
                    horizontal: MediaQuery.of(context).size.width * 0.12,
                  ),
                  child: const CircularProgressIndicator(),
                ),
              )
              : GestureDetector(
                onTap: () {
                  final bikepath =
                      routeSelectorProvider.resultRoute[index]['route'];
                  widget.ct?.addOverlay(
                    NPathOverlay(
                      id: 'routePath',
                      coords: List<NLatLng>.from(
                        bikepath.map((e) => e["NLatLng"]),
                      ), // NLatLng로 변환된 좌표 리스트
                      color: Colors.lightGreen,
                      width: 3,
                    ),
                  );
                  widget.ct?.updateCamera(
                    NCameraUpdate.fitBounds(
                      NLatLngBounds.from(
                        List<NLatLng>.from(bikepath.map((e) => e["NLatLng"])),
                      ),
                      padding: const EdgeInsets.all(50),
                    ),
                  );
                  routeSelectorProvider.setSelectedIndex(index);
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.35,
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          (routeSelectorProvider.selectedIndex == index)
                              ? Colors.blueAccent
                              : Colors.transparent,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _routeInfo[index],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '총 거리: ${routeSelectorProvider.resultRoute[index]["full_distance"].round()} m',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '소요 시간: ${(routeSelectorProvider.resultRoute[index]["full_distance"] / 1000 * 4).round()} 분',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
        },
      ),
    );
  }
}
