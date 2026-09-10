class LrnIdentity {
  final String lrn, firstName, middleName, lastName, extension;
  const LrnIdentity({
    required this.lrn,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    this.extension = '',
  });
  factory LrnIdentity.fromMaster(String lrn, Map<String, dynamic>? data) {
    if (!RegExp(r'^[0-9]{12}$').hasMatch(lrn) ||
        data == null ||
        data['isRegistered'] != false) {
      throw const FormatException(
        'This LRN is not available for registration. Check with your school.',
      );
    }
    String field(String key) =>
        (data[key] is String ? data[key] as String : '').trim();
    final first = field('firstName'), last = field('lastName');
    if (first.isEmpty || last.isEmpty) {
      throw const FormatException(
        'The school record has an incomplete name. Ask the school to correct it before registering.',
      );
    }
    return LrnIdentity(
      lrn: lrn,
      firstName: first,
      middleName: field('middleName'),
      lastName: last,
      extension: field('extension'),
    );
  }
  String get displayName => [
    firstName,
    middleName,
    lastName,
    extension,
  ].where((p) => p.isNotEmpty).join(' ');
  Map<String, String> get profileFields => {
    'lrn': lrn,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'extension': extension,
    'name': displayName,
    'displayName': displayName,
  };
  bool matchesProfile(Map<String, dynamic> profile) =>
      profileFields.entries.every((e) => profile[e.key] == e.value);
}
