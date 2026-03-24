import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import '../repositories/weather_repository.dart';

class WeatherViewModel extends ChangeNotifier {
  final WeatherRepository _weatherRepository = WeatherRepository();

  WeatherModel? _weather;
  List<ActivityModel> _suggestedActivities = [];
  bool _isLoading = false;
  String? _error;

  WeatherModel? get weather => _weather;
  List<ActivityModel> get suggestedActivities => _suggestedActivities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> updateWeatherAndActivities(String city, UserModel? user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _weather = await _weatherRepository.getWeather(city);
      if (_weather != null && user != null) {
        _suggestedActivities = _generateActivities(_weather!, user);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ActivityModel> _generateActivities(WeatherModel weather, UserModel user) {
    List<ActivityModel> activities = [];
    String condition = weather.condition.toLowerCase();
    double temp = weather.temperature;

    if (temp > 35) {
      // Extreme Heat
      if (user.weight > 80) { // Assuming 80kg+ as overweight placeholder or we could use BMI
        activities.add(ActivityModel(
          title: "Swimming",
          description: "Keep cool and stay hydrated while swimming.",
        ));
        activities.add(ActivityModel(
          title: "Hydrated Light Stretching",
          description: "Gentle movement in a cool environment.",
        ));
      } else {
        activities.add(ActivityModel(
          title: "Indoor Light Cardio",
          description: "Avoid the heat with some indoor movement.",
        ));
      }
    } else if (condition.contains("rain") || condition.contains("snow") || condition.contains("storm")) {
      // Rain/Snow
      activities.add(ActivityModel(
        title: "Indoor Yoga",
        description: "Perfect for a cozy rainy day indoors.",
      ));
      activities.add(ActivityModel(
        title: "Bodyweight Circuit",
        description: "Get your heart rate up without leaving home.",
      ));
    } else if (condition.contains("clear") || condition.contains("cloud")) {
      // Clear/Sunny/Cloudy
      if (user.age < 50) {
        activities.add(ActivityModel(
          title: "Outdoor Running",
          description: "Great weather for a jog in the park!",
        ));
        activities.add(ActivityModel(
          title: "High-Intensity Interval Training",
          description: "Push your limits with an outdoor HIIT session.",
        ));
      } else {
        activities.add(ActivityModel(
          title: "Morning Walk",
          description: "Enjoy the fresh air with a brisk walk.",
        ));
        activities.add(ActivityModel(
          title: "Tai Chi in the Park",
          description: "Focus on balance and breathing in nature.",
        ));
      }
    } else {
      // Default
      activities.add(ActivityModel(
        title: "Daily Stretching",
        description: "Stay flexible and active regardless of the weather.",
      ));
    }

    return activities;
  }
}
