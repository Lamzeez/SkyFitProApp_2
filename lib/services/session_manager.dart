import 'dart:async';
import 'package:flutter/material.dart';

class SessionManager extends ChangeNotifier {
  Timer? _timer;
  Timer? _warningTimer;
  final int _timeoutInSeconds = 5 * 60; // 5 minutes
  final int _warningInSeconds = 30;
  final VoidCallback onLogout;
  final VoidCallback onWarning;

  SessionManager({required this.onLogout, required this.onWarning});

  void startTimer() {
    _timer?.cancel();
    _warningTimer?.cancel();

    _warningTimer = Timer(Duration(seconds: _timeoutInSeconds - _warningInSeconds), () {
      print("Inactivity warning reached.");
      onWarning();
    });

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
    _warningTimer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }
}
