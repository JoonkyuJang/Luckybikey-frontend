import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../screens/home.dart';

class register extends StatefulWidget {
  const register({super.key});

  @override
  State<register> createState() => _registerState();
}

class _registerState extends State<register> {
  final _firestore = FirebaseFirestore.instance;
  final _authentication = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  String userFullName = '';
  String userEmail = '';
  String userPassword = '';

  late ScrollController scrollController;

  void _tryValidation() {
    final isValid = _formKey.currentState!.validate();
    if (isValid) {
      _formKey.currentState!.save();
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Center(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Register',
                    style: TextStyle(
                        color: Colors.lightGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 40),
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                  SizedBox(
                    width: 278.0,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // user full name text field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Full Name',
                              ),
                              const SizedBox(
                                height: 5.0,
                              ),
                              Column(
                                children: [
                                  TextFormField(
                                    key: const ValueKey(1),
                                    onTap: () {
                                      scrollAnimate();
                                    },
                                    onSaved: (value) {
                                      userFullName = value!;
                                    },
                                    onChanged: (value) {
                                      userFullName = value;
                                    },
                                    validator: (value) {
                                      if (value!.isEmpty || value.length < 5) {
                                        return 'Please enter at least 5 characters.';
                                      }
                                      return null;
                                    },
                                    scrollPadding: EdgeInsets.only(
                                        bottom: MediaQuery.of(context)
                                            .viewInsets
                                            .bottom),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.all(6.0),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xff415e91),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xff415e91),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 5.0,
                          ),
                          // user email text field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email',
                              ),
                              const SizedBox(
                                height: 5.0,
                              ),
                              Column(
                                children: [
                                  TextFormField(
                                    key: const ValueKey(1),
                                    keyboardType: TextInputType.emailAddress,
                                    onTap: () {
                                      scrollAnimate();
                                    },
                                    onSaved: (value) {
                                      userEmail = value!;
                                    },
                                    onChanged: (value) {
                                      userEmail = value;
                                    },
                                    validator: (value) {
                                      if (value!.isEmpty || value.length < 5) {
                                        return 'Please enter at least 5 characters.';
                                      }
                                      return null;
                                    },
                                    scrollPadding: EdgeInsets.only(
                                        bottom: MediaQuery.of(context)
                                            .viewInsets
                                            .bottom),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.all(6.0),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xff415e91),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xff415e91),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 5.0,
                          ),
                          // user password text field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password',
                              ),
                              const SizedBox(
                                height: 5.0,
                              ),
                              Column(
                                children: [
                                  TextFormField(
                                    key: const ValueKey(3),
                                    obscureText: true,
                                    onTap: () {
                                      scrollAnimate();
                                    },
                                    onSaved: (value) {
                                      userPassword = value!;
                                    },
                                    onChanged: (value) {
                                      userPassword = value;
                                    },
                                    validator: (value) {
                                      if (value!.isEmpty || value.length < 5) {
                                        return 'Please enter at least 5 characters.';
                                      }
                                      return null;
                                    },
                                    scrollPadding: EdgeInsets.only(
                                        bottom: MediaQuery.of(context)
                                            .viewInsets
                                            .bottom),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.all(6.0),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xff415e91),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xff415e91),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(9.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).viewInsets.bottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: Colors.white,
                      ),
                      fixedSize: const Size(129.6, 54.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.3),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () async {
                      try {
                        _tryValidation();

                        final newUser = await _authentication
                            .createUserWithEmailAndPassword(
                          email: userEmail,
                          password: userPassword,
                        );

                        if (newUser.user != null) {
                          await _firestore
                              .collection('users')
                              .doc(newUser.user!.uid)
                              .set({
                            'uid': newUser.user!.uid,
                            'email': newUser.user!
                                .email, // newUser.user!.email 대신 userEmail 사용 가능
                            'fullname': userFullName,
                            'createdAt': FieldValue.serverTimestamp(),
                            'totalDistance': 0.0,
                            'attributes': {
                              "scenery": 0,
                              "safety": 0,
                              "traffic": 0,
                              "fast": 0,
                              "signal": 0,
                              "uphill": 0,
                              "bigRoad": 0,
                              "bikePath": 0,
                            }
                          });
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) => Home()));
                        }
                      } catch (err) {
                        debugPrint(err.toString());

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please check your email and password.'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Get Registered',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void scrollAnimate() {
    Future.delayed(const Duration(milliseconds: 600), () {
      scrollController.animateTo(
        MediaQuery.of(context).viewInsets.bottom,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
      );
    });
  }
}
