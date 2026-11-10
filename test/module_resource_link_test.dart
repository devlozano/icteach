import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/module_resource_link.dart';

void main() {
  test('validates resource URLs and trims pasted whitespace', () {
    expect(
      ModuleResourceLink.parse('  https://example.org/lesson.pdf  ').host,
      'example.org',
    );
    for (final link in [
      null,
      '',
      '/file.pdf',
      'https:',
      'javascript:alert(1)',
      'file:///tmp/test',
      'https://user:pass@example.org/file',
    ]) {
      expect(() => ModuleResourceLink.parse(link), throwsStateError);
    }
  });

  test('Cloudinary images, documents and raw files use attachment delivery', () {
    for (final type in ['image', 'raw', 'video']) {
      final original = Uri.parse(
        'https://res.cloudinary.com/demo/$type/upload/v123/folder/lesson%20one.pdf',
      );
      final download = ModuleResourceLink.download(original);
      expect(
        download.path,
        '/demo/$type/upload/fl_attachment/v123/folder/lesson%20one.pdf',
      );
      expect(ModuleResourceLink.download(download), download);
    }
  });

  test('signed and third party URLs retain their exact tokens and paths', () {
    for (final link in [
      'https://res.cloudinary.com/demo/image/upload/s--signature--/v1/file.pdf',
      'https://res.cloudinary.com/demo/image/upload/v1/file.pdf?token=abc%2B123',
      'https://firebasestorage.googleapis.com/v0/b/bucket/o/folder%2Ffile.pdf?alt=media&token=123',
      'https://drive.google.com/file/d/file-id/view?usp=sharing',
      'https://res.cloudinary.com.evil.example/demo/image/upload/file.pdf',
    ]) {
      final uri = ModuleResourceLink.parse(link);
      expect(ModuleResourceLink.download(uri).toString(), link);
    }
  });

  test('host rejection explains permissions or missing files', () {
    final uri = Uri.parse(
      'https://res.cloudinary.com/demo/image/upload/file.pdf',
    );
    expect(ModuleResourceLink.responseError(uri, 401), contains('Cloudinary'));
    expect(
      ModuleResourceLink.responseError(uri, 403),
      contains('PDF delivery'),
    );
    expect(
      ModuleResourceLink.responseError(uri, 404),
      contains('upload it again'),
    );
    expect(
      ModuleResourceLink.responseError(
        Uri.parse('https://example.org/file'),
        403,
      ),
      contains('sharing permissions'),
    );
    expect(ModuleResourceLink.responseError(uri, 503), contains('503'));
  });
  test('resource errors do not expose Dart Bad state prefixes', () {
    expect(
      ModuleResourceLink.errorMessage(StateError('Please sign in.')),
      'Please sign in.',
    );
    expect(
      ModuleResourceLink.errorMessage(const FormatException()),
      contains('invalid'),
    );
    expect(
      ModuleResourceLink.errorMessage(Exception('internal details')),
      isNot(contains('internal details')),
    );
  });
}
