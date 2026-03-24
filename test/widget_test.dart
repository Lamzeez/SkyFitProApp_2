import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:skyfit_pro/main.dart';
import 'package:skyfit_pro/viewmodels/auth_viewmodel.dart';
import 'package:skyfit_pro/viewmodels/user_viewmodel.dart';
import 'package:skyfit_pro/viewmodels/weather_viewmodel.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          ChangeNotifierProvider(create: (_) => UserViewModel()),
          ChangeNotifierProvider(create: (_) => WeatherViewModel()),
        ],
        child: const SkyFitProApp(),
      ),
    );

    // Verify that the login screen title exists
    expect(find.text('SkyFit Pro'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
