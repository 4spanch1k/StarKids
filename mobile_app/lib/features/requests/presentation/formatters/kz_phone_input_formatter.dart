import 'package:flutter/services.dart';

class KzPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDisplay(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String normalizeForSubmit(String value) {
    var digits = _digitsOnly(value);

    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (!digits.startsWith('7')) {
      digits = '7$digits';
    }

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    return '+$digits';
  }

  static bool isValid(String? value) {
    final normalized = normalizeForSubmit(value ?? '');
    return RegExp(r'^\+7\d{10}$').hasMatch(normalized);
  }

  static String formatDisplay(String value) {
    var digits = _digitsOnly(value);

    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (!digits.startsWith('7')) {
      digits = '7$digits';
    }

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    final buffer = StringBuffer('+${digits[0]}');

    if (digits.length > 1) {
      buffer.write(' ');
      buffer.write(digits.substring(1, digits.length.clamp(1, 4)));
    }

    if (digits.length > 4) {
      buffer.write(' ');
      buffer.write(digits.substring(4, digits.length.clamp(4, 7)));
    }

    if (digits.length > 7) {
      buffer.write(' ');
      buffer.write(digits.substring(7, digits.length.clamp(7, 9)));
    }

    if (digits.length > 9) {
      buffer.write(' ');
      buffer.write(digits.substring(9, digits.length.clamp(9, 11)));
    }

    return buffer.toString();
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}
