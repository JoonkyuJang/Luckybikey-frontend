import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final _firestore = FirebaseFirestore.instance;
final _authentication = FirebaseAuth.instance;

class PreferenceProvider with ChangeNotifier {
  List<String> _likes = [];
  List<String> _dislikes = [];

  List<String> get likes => _likes;
  List<String> get dislikes => _dislikes;

  Map<String, int> _determineAttributes() {
    final results = _likes + _dislikes;
    final attributes = {
      "scenery": 0,
      "safety": 0,
      "traffic": 0,
      "fast": 0,
      "signal": 0,
      "uphill": 0,
      "bigRoad": 0,
      "bikePath": 0,
    };
    if (results.contains("풍경")) {
      attributes["scenery"] = 1;
    } else {
      attributes["scenery"] = -1;
    }
    if (results.contains("안전")) {
      attributes["safety"] = 1;
    } else {
      attributes["safety"] = -1;
    }
    if (results.contains("통행량")) {
      attributes["traffic"] = -1;
    } else {
      attributes["traffic"] = 1;
    }
    if (results.contains("속도")) {
      attributes["fast"] = 1;
    } else {
      attributes["fast"] = -1;
    }
    if (results.contains("신호")) {
      attributes["signal"] = -1;
    } else {
      attributes["signal"] = 1;
    }
    if (results.contains("오르막")) {
      attributes["uphill"] = -1;
    } else {
      attributes["uphill"] = 1;
    }
    return attributes;
  }

  // Method to update firestore
  void updateFirestore() {
    final attributes = _determineAttributes();
    _firestore
        .collection('users')
        .doc(_authentication.currentUser?.uid)
        .update({
      'attributes': attributes,
    });
  }

  void getPreferences() {
    _likes = [];
    _dislikes = [];
    _firestore
        .collection('users')
        .doc(_authentication.currentUser?.uid)
        .get()
        .then((value) {
      final data = value.data();
      if (data != null) {
        if (data['attributes']['scenery'] == 1) {
          _likes.add('풍경');
        }
        if (data['attributes']['safety'] == 1) {
          _likes.add('안전');
        }
        if (data['attributes']['traffic'] == -1) {
          _dislikes.add('통행량');
        }
        if (data['attributes']['fast'] == 1) {
          _likes.add('속도');
        }
        if (data['attributes']['signal'] == -1) {
          _dislikes.add('신호');
        }
        if (data['attributes']['uphill'] == -1) {
          _dislikes.add('오르막');
        }
        notifyListeners();
      }
    });
  }

  // Method to set likes
  void setLikes(List<String> likes) {
    _likes = likes;
    updateFirestore();
    notifyListeners();
  }

  // Method to set dislikes
  void setDislikes(List<String> dislikes) {
    _dislikes = dislikes;
    updateFirestore();
    notifyListeners();
  }

  // Method to add a single like
  void addLike(String like) {
    if (!_likes.contains(like)) {
      _likes.add(like);
      updateFirestore();
      notifyListeners();
    }
  }

  // Method to remove a single like
  void removeLike(String like) {
    _likes.remove(like);
    updateFirestore();
    notifyListeners();
  }

  // Method to add a single dislike
  void addDislike(String dislike) {
    if (!_dislikes.contains(dislike)) {
      _dislikes.add(dislike);
      updateFirestore();
      notifyListeners();
    }
  }

  // Method to remove a single dislike
  void removeDislike(String dislike) {
    _dislikes.remove(dislike);
    updateFirestore();
    notifyListeners();
  }
}
