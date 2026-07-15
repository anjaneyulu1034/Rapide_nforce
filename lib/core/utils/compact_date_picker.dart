import 'package:flutter/material.dart';

/// Wraps [showDatePicker] with a smaller dialog — the stock Material picker
/// renders quite large (full calendar chrome + input-mode toggle), which
/// feels oversized inside sheets/forms in this app.
Future<DateTime?> showCompactDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(0.85)),
        child: Center(
          child: SizedBox(width: 300, child: child),
        ),
      );
    },
  );
}
