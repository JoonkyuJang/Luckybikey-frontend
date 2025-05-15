import "package:flutter/material.dart";

class FeedbackProvider extends ChangeNotifier {
  bool _hasPopped = false;

  bool get hasPopped => _hasPopped;

  void pop() {
    _hasPopped = true;
    notifyListeners();
  }

  void resetPop() {
    _hasPopped = false;
    notifyListeners();
  }
}
