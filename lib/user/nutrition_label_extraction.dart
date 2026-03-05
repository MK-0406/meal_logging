import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class NutritionService {

  Future<String> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    await textRecognizer.close();
    return recognizedText.text;
  }

  Future<Map<String, dynamic>?> analyzeNutrition(String text) async {
    const apiKey = "AIzaSyCvWcAZQsGUsVtFYZeFd3hZwNffE4smCKw";

    final models = [
      "gemini-2.5-flash",
      "gemini-2.5-flash-lite",
      'gemini-robotics-er-1.5-preview',
    ];

    for (final model in models) {
      final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey"
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                  "Extract calories, water_g, protein_g, fat_g, carbohydrates_g, fiber_g, calcium_mg, iron_mg, potassium_mg, sodium_mg, phosphorus_mg, ash_g for 100g/ml."
                      "Return ONLY valid JSON. Make sure all the fields are same as mentioned"
                      "If there is no nutrition label info, please return error message only. Else If there is no 100g/ml return error message only.\n\n$text"
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText =
        data["candidates"][0]["content"]["parts"][0]["text"];

        final cleaned = aiText
            .replaceAll("```json", "")
            .replaceAll("```", "")
            .trim();

        return jsonDecode(cleaned);
      }

      if (response.statusCode == 429) {
        continue;
      }

      break;
    }

    return {"error": "Reached limit for today. Please enter manually."};
  }
}