import 'dart:async';
import 'package:flutter/material.dart';

class SessionManager extends ChangeNotifier {
  Timer? _timer;
  final int _timeoutInSeconds = 5 * 60; // 5 minutes
  final VoidCallback onLogout;

  SessionManager({required this.onLogout});

  void startTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: _timeoutInSeconds), () {
      print("Inactivity timeout reached. Logging out.");
      onLogout();
    });
  }

  void resetTimer() {
    print("User interaction detected. Resetting session timer.");
    startTimer();
  }

  void stopTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
