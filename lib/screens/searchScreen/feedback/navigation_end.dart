import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';



class Navigationend extends StatefulWidget {
  const Navigationend({
    super.key,
    required this.fullDistance,
    required this.tick,
    required this.firestore,
    required this.authentication,
  });

  final double fullDistance;
  final double tick;
  final FirebaseFirestore firestore;
  final FirebaseAuth authentication;

  @override
  NavigationendState createState() => NavigationendState();
}

class NavigationendState extends State<Navigationend> {
  int rating = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('안내 종료'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width*0.9,
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text('목적지에 도착했습니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.lightGreen),),
            Text('총 이동거리: ${widget.fullDistance.round()}m'),
            Text('총 소요시간: ${(widget.tick * 3 / 60).round()}분'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(rating > index ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 30.0),
                  onPressed: () {
                    setState(() {
                      rating = index + 1;
                      print(rating);
                    });
                  },
                );
              }),
            )
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            widget.firestore //TODO: Better Feedback
                .collection('users')
                .doc(widget.authentication.currentUser!.uid)
                .update({
              'rating': rating,
              'totalDistance': FieldValue.increment(
                  widget.fullDistance.round()), //widget에 fulldistance가 현재 0
            });
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}
