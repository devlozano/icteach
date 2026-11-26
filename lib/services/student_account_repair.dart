import 'dart:convert';

import 'package:crypto/crypto.dart';

String studentAccountRepairId(String email) =>
    sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
