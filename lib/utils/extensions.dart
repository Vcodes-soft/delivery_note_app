import 'dart:math';

import 'package:delivery_note_app/utils/app_constants.dart';

extension PrecisonSetting on double {
  String precisedToString() {
    int n = AppConstants.roundingPrecision;
    double value = double.parse(toString());
    double mod = pow(10.0, n.toDouble()).toDouble();
    double result = value * mod;

    switch (AppConstants.roundingRule.trim().isEmpty
        ? 'round'
        : AppConstants.roundingRule) {
      case 'round':
        return (result.roundToDouble() / mod)
            .toStringAsFixed(n)
            .padRight(n, "0");
      case 'floor':
        return (result.floorToDouble() / mod)
            .toStringAsFixed(n)
            .padRight(n, "0");

      case 'ceiling':
        return (result.ceilToDouble() / mod)
            .toStringAsFixed(n)
            .padRight(n, "0");

      default:
        throw ArgumentError('Invalid rounding mode');
    }
  }

  String qtyPrecisedToString() {
    int n = AppConstants.roundingPrecisionForQuantity;
    double value = double.parse(toString());
    double mod = pow(10.0, n.toDouble()).toDouble();
    double result = value * mod;

    switch (AppConstants.roundingRule.trim().isEmpty
        ? 'round'
        : AppConstants.roundingRule) {
      case 'round':
        return (result.roundToDouble() / mod)
            .toStringAsFixed(n)
            .padRight(n, "0");
      case 'floor':
        return (result.floorToDouble() / mod)
            .toStringAsFixed(n)
            .padRight(n, "0");

      case 'ceiling':
        return (result.ceilToDouble() / mod)
            .toStringAsFixed(n)
            .padRight(n, "0");

      default:
        throw ArgumentError('Invalid rounding mode');
    }
  }

  double precised() {
    int n = AppConstants.roundingPrecision; //3;
    double mod = pow(10.0, n.toDouble()).toDouble();
    double result = this * mod;

    switch (AppConstants.roundingRule.trim().isEmpty
        ? 'round'
        : AppConstants.roundingRule) {
      case 'round':
        return parseToDouble(((result.roundToDouble()) / mod), n);
      case 'floor':
        return parseToDouble(((result.floorToDouble()) / mod), n);
      case 'ceiling':
        return parseToDouble(((result.ceilToDouble()) / mod), n);
      default:
        throw ArgumentError('Invalid rounding mode');
    }
  }

  double qtyPrecised() {
    int n = AppConstants.roundingPrecisionForQuantity; //3;
    double mod = pow(10.0, n.toDouble()).toDouble();
    double result = this * mod;

    switch (AppConstants.roundingRule.trim().isEmpty
        ? 'round'
        : AppConstants.roundingRule) {
      case 'round':
        return parseToDouble(((result.roundToDouble()) / mod), n);
      case 'floor':
        return parseToDouble(((result.floorToDouble()) / mod), n);
      case 'ceiling':
        return parseToDouble(((result.ceilToDouble()) / mod), n);
      default:
        throw ArgumentError('Invalid rounding mode');
    }
  }
}

double formatDouble(double value, int decimalPlaces) {
  String formatted = value.toStringAsFixed(decimalPlaces);
  int indexOfDecimal = formatted.indexOf('.');
  int decimalsToAdd = decimalPlaces - (formatted.length - indexOfDecimal - 1);
  if (decimalsToAdd > 0) {
    // Add trailing zeroes if necessary
    formatted += '0' * decimalsToAdd;
  }

  print(formatted);
  return double.parse(formatted);
}

double parseToDouble(double value, int decimalPlaces) {
  double parsedDouble = value;
  String formattedDouble = parsedDouble.toStringAsFixed(decimalPlaces);
  return double.parse(formattedDouble);
}
