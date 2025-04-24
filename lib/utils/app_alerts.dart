import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'app_colors.dart';

class AppAlerts {
  // Toast with string message
  static appToast({
    required String message,
    Color bgColor = Colors.black, // Default background color
    Color textColor = Colors.white, // Default text color

  }) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: bgColor,
      textColor: textColor,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      fontSize: 16.0,
    );
  }

  // Dialog with an "Okay" button
  static Future<void> showOkayDialog({
    required BuildContext context,
    bool barrierDismissible = true,
    required String title,
    required String content,
    required VoidCallback onOkayPressed,
    String okayText = "Okay",
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                onOkayPressed();
              },
              child: Text(okayText),
            ),
          ],
        );
      },
    );
  }

  // Dialog with "Yes" and "No" buttons
  static Future<void> showYesNoDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onYesPressed,
    required VoidCallback onNoPressed,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onNoPressed();
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onYesPressed();
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // Custom Continue Anyway Dialog with dynamic title and content
  static Future<void> showContinueAnywayDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onContinuePressed,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            content,
            style: TextStyle(
              color: AppColors.appThemeColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onContinuePressed();
              },
              child: Text("Continue anyway"),
            ),
          ],
        );
      },
    );
  }

  // Method to determine text style based on background color
  static TextStyle getStyle(Color color) {
    if (color == Colors.red || color == Colors.green || color == Colors.blueGrey[900]) {
      return const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
    } else if (color == Colors.yellow) {
      return const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
    } else {
      return const TextStyle(
        color: Colors.grey,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
    }
  }
}
