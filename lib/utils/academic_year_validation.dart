class AcademicYearValidation {
  const AcademicYearValidation._();

  static String? startYearError(String value, {int? currentYear}) {
    final text = value.trim();
    final start = int.tryParse(text);
    if (start == null || text.length != 4) {
      return 'Enter a valid four-digit start year.';
    }
    final minimum = currentYear ?? DateTime.now().year;
    if (start < minimum) {
      return 'Start year must be $minimum or later.';
    }
    if (start >= 9999) {
      return 'Start year must be 9998 or earlier.';
    }
    return null;
  }

  static String? schoolYear(String value, {int? currentYear}) {
    if (startYearError(value, currentYear: currentYear) != null) return null;
    final start = int.parse(value.trim());
    return '$start-${start + 1}';
  }
}
