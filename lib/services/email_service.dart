import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // Replace these with your EmailJS credentials in a real app
  static const String _serviceId = 'service_43xgfz7'; // Get from EmailJS
  static const String _templateId = 'template_qj21c2e'; // Get from EmailJS
  static const String _userId = '4lGaAF0nECYWbfojz'; // Get from EmailJS (Public Key)

  /// Sends a 6-digit OTP to the specified email using EmailJS.
  static Future<bool> sendOTP(String email, String otp) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost', // Required by some EmailJS configs
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _userId,
          'template_params': {
            'to_email': email,
            'otp_code': otp,
            'app_name': 'SkyFit Pro',
          },
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('EmailJS Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}
