import 'package:flutter/material.dart';

class RouteSelectorProvider with ChangeNotifier {
  List<Map<String, dynamic>> resultRoute = [{}, {}, {}, {}, {}];
  int selectedIndex = -1;

  void setRoute(Map<String, dynamic> route, int index) {
    resultRoute[index] = route;
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }
}
