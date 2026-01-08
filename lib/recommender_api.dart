import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://YOUR-RENDER-URL.onrender.com";

  static Future<double?> getPrediction({
    required int age,
    required double height,
    required double weight,
    required double bmi,
  }) async {
    final url = Uri.parse("$baseUrl/predict");

    final body = {
      "Age": age,
      "Height_cm": height,
      "Weight_kg": weight,
      "BMI": bmi
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["prediction"]; // adjust key based on your FastAPI response
      } else {
        print("Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("API Error: $e");
      return null;
    }
  }
}
