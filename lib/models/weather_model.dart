class WeatherModel {
  final double temperature;
  final int humidity;
  final String condition;
  final String cityName;

  WeatherModel({
    required this.temperature,
    required this.humidity,
    required this.condition,
    required this.cityName,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      temperature: (json['main']['temp'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      condition: json['weather'][0]['main'] as String,
      cityName: json['name'] as String,
    );
  }
}
