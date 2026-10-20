import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/utils/student_email_csv_parser.dart';

void main() {
  StudentEmailCsv parse(String csv) =>
      StudentEmailCsvParser.parseBytes(utf8.encode(csv));
  test(
    'Gmail upload accepts UTF-8 BOM, reordered headers, quoted names and duplicates',
    () {
      final result = parse(
        '\uFEFFLast Name,Gmail,First Name\r\n"Santos, Jr.", LEARNER@gmail.com ,José\r\nOther,learner@gmail.com,Duplicate\r\n',
      );
      expect(result.records, hasLength(1));
      expect(result.duplicates, 1);
      expect(result.records.single.email, 'learner@gmail.com');
      expect(result.records.single.displayName, 'José Santos, Jr.');
      expect(result.records.single.row, 2);
    },
  );
  test(
    'supports school addresses and one-column lists with or without headers',
    () {
      expect(
        parse('learner@school.edu.ph\r\nother+class@gmail.com').records,
        hasLength(2),
      );
      expect(
        parse('Email\nlearner@example.com').records.single.firstName,
        isEmpty,
      );
      expect(
        parse(
          'Gmail,First Name,Last Name\nlearner@gmail.com,,',
        ).records.single.lastName,
        isEmpty,
      );
    },
  );
  for (final csv in [
    '',
    'Gmail,First Name,Last Name\n',
    'Gmail\nnot-an-email',
    'Gmail\nname@@gmail.com',
    'Gmail\n.name@gmail.com',
    'Gmail\nna..me@gmail.com',
    'Gmail\nname@gmail',
    'Gmail\nname@-gmail.com',
    'Gmail,Email\na@gmail.com,b@gmail.com',
    'Gmail,Password\na@gmail.com,secret',
    'Gmail,First Name\na@gmail.com',
    'Gmail\n"a@gmail.com',
    'Gmail,First Name\na@gmail.com,"name"junk',
    'LRN,First Name,Last Name\n123456789012,First,Last',
  ]) {
    test(
      'rejects malformed file before sending: ${csv.replaceAll('\n', ' ')}',
      () {
        expect(() => parse(csv), throwsFormatException);
      },
    );
  }
  test('limits bytes, row count, and names; invalid UTF-8 is rejected', () {
    expect(
      () => StudentEmailCsvParser.parseBytes([0xff]),
      throwsFormatException,
    );
    expect(
      () => StudentEmailCsvParser.parseBytes(
        List.filled(StudentEmailCsvParser.maxBytes + 1, 32),
      ),
      throwsFormatException,
    );
    expect(
      () => parse(
        'Gmail\n${List.generate(101, (i) => 'student$i@example.com').join('\n')}',
      ),
      throwsFormatException,
    );
    expect(
      () => parse('Gmail,First Name\na@gmail.com,${'a' * 81}'),
      throwsFormatException,
    );
    expect(
      parse(
        'Gmail\n${List.generate(100, (i) => 'student$i@example.com').join('\n')}',
      ).records,
      hasLength(100),
    );
  });
  test('template has no real recipients and cannot send until filled', () {
    expect(() => parse(StudentEmailCsvParser.template), throwsFormatException);
  });
}
