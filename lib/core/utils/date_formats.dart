/// Date formatting shared across features.
///
/// The app ships without `intl`, so these are deliberately English-only and
/// tiny. Move to a localized formatter if VERSED ever ships a second locale.
const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `2026-07-25` -> `July 2026`.
String monthYearLabel(DateTime date) {
  final local = date.toLocal();
  return '${_monthNames[local.month - 1]} ${local.year}';
}

/// `2026-07-25` -> `Joined July 2026`.
String joinedLabel(DateTime date) => 'Joined ${monthYearLabel(date)}';
