import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Currency formatter for Brazilian Real
class CurrencyFormatter {
  static final NumberFormat _brlFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  static String format(double value) {
    return _brlFormat.format(value);
  }

  static String formatWithSign(double value, {required bool isExpense}) {
    final sign = isExpense ? '-' : '+';
    return '$sign ${_brlFormat.format(value.abs())}';
  }
}

/// Date formatters
class DateFormatter {
  static final DateFormat _dayMonth = DateFormat('dd/MM');
  static final DateFormat _dayMonthYear = DateFormat('dd/MM/yyyy');
  static final DateFormat _fullDate = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'pt_BR');
  static final DateFormat _monthYear = DateFormat('MM/yyyy', 'pt_BR');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _isoDateTime = DateFormat('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

  static String formatDayMonth(DateTime date) => _dayMonth.format(date);
  static String formatDayMonthYear(DateTime date) => _dayMonthYear.format(date);
  static String formatFull(DateTime date) => _fullDate.format(date);
  static String formatMonthYear(DateTime date) => _monthYear.format(date);
  static String formatTime(DateTime date) => _time.format(date);
  static String formatDateTime(DateTime date) => _dateTime.format(date);
  static String formatIsoDate(DateTime date) => _isoDate.format(date);
  static String formatIsoDateTime(DateTime date) => _isoDateTime.format(date);
  
  static DateTime? parseIsoDate(String? value) {
    if (value == null) return null;
    try {
      return _isoDateTime.parse(value);
    } catch (_) {
      try {
        return _isoDate.parse(value);
      } catch (_) {
        return null;
      }
    }
  }
}

/// Number validators
class Validators {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email obrigatório';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Email inválido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Senha obrigatória';
    if (value.length < 6) return 'Senha deve ter pelo menos 6 caracteres';
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value != original) return 'Senhas não conferem';
    return null;
  }

  static String? positiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Valor obrigatório';
    final num? parsed = num.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Número inválido';
    if (parsed <= 0) return 'Valor deve ser maior que zero';
    return null;
  }

  static String? nonNegativeNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Valor obrigatório';
    final num? parsed = num.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Número inválido';
    if (parsed < 0) return 'Valor não pode ser negativo';
    return null;
  }

  static String? minLength(String? value, int min) {
    if (value == null || value.trim().length < min) {
      return 'Mínimo de $min caracteres';
    }
    return null;
  }
}

/// Form helpers
class FormHelper {
  static double parseCurrency(String value) {
    return double.tryParse(value.replaceAll('R\$', '').replaceAll(',', '.').trim()) ?? 0.0;
  }

  static String formatForInput(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// Formats a double as Brazilian currency ("R$ 1.200,00").
  static String formatBRL(double value) => CurrencyFormatter.format(value);

  /// Parses a Brazilian currency string back to a double (cents-based).
  static double parseBRL(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0.0;
    return int.parse(digits) / 100;
  }
}

/// Formats typed digits into Brazilian currency as the user types
/// (e.g. "123456" becomes "R$ 1.234,56").
class BRLTextInputFormatter extends TextInputFormatter {
  static final NumberFormat _format = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final cents = int.tryParse(digits) ?? 0;
    final formatted = _format.format(cents / 100).trim();
    final text = 'R\$ $formatted';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}