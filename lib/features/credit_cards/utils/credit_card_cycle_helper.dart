/// Helper utilities for credit card invoice billing cycles and installment calculations.
class CreditCardCycleHelper {
  const CreditCardCycleHelper._();

  /// Clamps the card's [closingDay] to the actual number of days in the specified [year] and [month].
  static int effectiveClosingDay(int year, int month, int closingDay) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return closingDay.clamp(1, daysInMonth);
  }

  /// Calculates which invoice month (normalized to the 1st of that month) a transaction belongs to.
  ///
  /// If the transaction's [date.day] is strictly after the card's closing day in that month,
  /// the transaction falls into the NEXT month's invoice.
  /// Otherwise, it falls into the current month's invoice.
  static DateTime invoiceMonthForDate(DateTime date, int closingDay) {
    final closing = effectiveClosingDay(date.year, date.month, closingDay);
    if (date.day > closing) {
      return DateTime(date.year, date.month + 1, 1);
    }
    return DateTime(date.year, date.month, 1);
  }

  /// Calculates the exact start and end [DateTime] range for an invoice billing cycle.
  ///
  /// A billing cycle for [invoiceMonth] runs from:
  /// `(closingDay of previous month) + 1` at 00:00:00.000
  /// to
  /// `closingDay of invoiceMonth` at 23:59:59.999
  static ({DateTime start, DateTime end}) invoiceDateRange({
    required DateTime invoiceMonth,
    required int closingDay,
  }) {
    final prevMonth = DateTime(invoiceMonth.year, invoiceMonth.month - 1, 1);
    final prevClosing =
        effectiveClosingDay(prevMonth.year, prevMonth.month, closingDay);
    final start = DateTime(
      prevMonth.year,
      prevMonth.month,
      prevClosing + 1,
      0,
      0,
      0,
      0,
    );

    final thisClosing =
        effectiveClosingDay(invoiceMonth.year, invoiceMonth.month, closingDay);
    final end = DateTime(
      invoiceMonth.year,
      invoiceMonth.month,
      thisClosing,
      23,
      59,
      59,
      999,
    );

    return (start: start, end: end);
  }

  /// Best purchase day is the day immediately following the invoice closing day.
  /// Purchases on this day have the maximum time before payment is due (~30-40 days).
  static int bestDayToBuy(int closingDay) {
    return closingDay >= 31 ? 1 : closingDay + 1;
  }

  /// Computes a safe transaction date for installment [installmentIndex] (0-indexed)
  /// ensuring it falls into the target invoice cycle `M_0 + installmentIndex`.
  static DateTime installmentDateForCycle({
    required DateTime baseDate,
    required int installmentIndex,
    required int closingDay,
  }) {
    if (installmentIndex == 0) return baseDate;

    final firstInvoiceMonth = invoiceMonthForDate(baseDate, closingDay);
    final targetInvoiceMonth = DateTime(
      firstInvoiceMonth.year,
      firstInvoiceMonth.month + installmentIndex,
      1,
    );
    final range = invoiceDateRange(
      invoiceMonth: targetInvoiceMonth,
      closingDay: closingDay,
    );

    // Attempt to keep the same calendar day as the initial purchase
    final candidateDaysInMonth =
        DateTime(baseDate.year, baseDate.month + installmentIndex + 1, 0).day;
    final targetDay = baseDate.day > candidateDaysInMonth
        ? candidateDaysInMonth
        : baseDate.day;
    final candidate = DateTime(
      baseDate.year,
      baseDate.month + installmentIndex,
      targetDay,
      baseDate.hour,
      baseDate.minute,
    );

    // If candidate falls within the target cycle range, use it
    if (!candidate.isBefore(range.start) && !candidate.isAfter(range.end)) {
      return candidate;
    }

    // Fallback: place it on the closing day of that invoice cycle
    return DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      baseDate.hour,
      baseDate.minute,
    );
  }
}
