import 'dart:io';
import 'package:dio/dio.dart';

const String telegramBotToken =
    "8058845401:AAEkniKqV-igAYNhueo3zp-YHgEDBD5967M";
const String telegramChatId = "457782794";

class TelegramLogger {
  static final Dio dio = Dio();
  static DateTime? _lastRequestTime;
  static const int _minRequestInterval =
      1000; // 1 second between requests (Telegram's limit is ~30 messages/sec)

  static Future<void> sendLog(String message) async {
    try {
      // Rate limiting check
      if (_lastRequestTime != null &&
          DateTime.now().difference(_lastRequestTime!).inMilliseconds <
              _minRequestInterval) {
        print('⚠️ Too many requests to Telegram API. Delaying...');
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      const String url =
          "https://api.telegram.org/bot$telegramBotToken/sendMessage";

      final response = await dio.post(
        url,
        data: {
          "chat_id": telegramChatId,
          "text": message.length > 4096
              ? message.substring(0, 4096)
              : message, // Telegram has 4096 char limit
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      _lastRequestTime = DateTime.now();

      if (response.statusCode == 200) {
        print("✅ Log sent to Telegram");
      } else {
        print("❌ Telegram API error: ${response.statusCode} ${response.data}");
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final retryAfter = e.response?.headers.value('retry-after') ?? '5';
        print('⚠️ Rate limited. Retrying after $retryAfter seconds...');
        await Future.delayed(Duration(seconds: int.parse(retryAfter)));
        return sendLog(message); // Retry
      }
      print("❌ Telegram error: ${e.message}");
    } catch (e) {
      print("❌ Unexpected error: $e");
    }
  }

  static Future<bool> sendFile(File file,
      {Function(double)? onProgress}) async {
    try {
      final fileName = file.path.split('/').last;
      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;

      // First send a message announcing the file
      await sendLog(
          "📎 Uploading log file: $fileName (${_formatFileSize(fileSize)})");

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

      await sendLog("✅ Log file uploaded successfully: $fileName");
      return true;
    } catch (e) {
      print("❌ Error uploading file: $e");
      await sendLog("❌ Failed to upload log file: $e");
      return false;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
