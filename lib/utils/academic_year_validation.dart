class AcademicYearValidation {
  const AcademicYearValidation._();

  static const int schoolYearStartMonth = DateTime.june;

  static int activeStartYear({DateTime? now}) {
    final date = now ?? DateTime.now();
    return date.month >= schoolYearStartMonth ? date.year : date.year - 1;
  }

  static String activeSchoolYear({DateTime? now}) {
    final start = activeStartYear(now: now);
    return '$start-${start + 1}';
  }

  static int? parseStartYear(String? schoolYear) {
    final match = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(schoolYear ?? '');
    if (match == null) return null;
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    return start != null && end == start + 1 ? start : null;
  }

  static bool isBefore(String? schoolYear, String targetSchoolYear) {
    final start = parseStartYear(schoolYear);
    final target = parseStartYear(targetSchoolYear);
    return start != null && target != null && start < target;
  }

  static String? classArchiveError({
    required String? status,
    required String? classSchoolYear,
    required String activeSchoolYear,
  }) {
    if (status == 'archived') return 'This class is already archived.';
    if (status != null && status != 'active') {
      return 'Only an active class can be archived.';
    }
    final classStart = parseStartYear(classSchoolYear);
    if (classStart == null) {
      return 'Set a valid school year on this class before archiving it.';
    }
    final activeStart = parseStartYear(activeSchoolYear);
    if (activeStart == null) {
      return 'Set a valid active school year before archiving classes.';
    }
    if (classStart > activeStart) {
      return 'This class belongs to future school year $classSchoolYear and cannot be archived while $activeSchoolYear is active.';
    }
    return null;
  }

  static String? startYearError(String value, {int? currentYear}) {
    final text = value.trim();
    final start = int.tryParse(text);
    if (start == null || text.length != 4) {
      return 'Enter a valid four-digit start year.';
    }
    final minimum = currentYear ?? activeStartYear();
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
