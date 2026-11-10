/// Validates teacher-provided links without changing signed query parameters.
class ModuleResourceLink {
  static Uri parse(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !const ['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        'This resource has no valid web link. Ask your teacher to attach the file again.',
      );
    }
    return uri;
  }

  static Uri download(Uri uri) {
    // Do not rewrite signed delivery URLs: doing so invalidates their signature.
    if (uri.host == 'res.cloudinary.com' && uri.query.isEmpty) {
      final segments = uri.pathSegments;
      if (segments.length >= 4 &&
          const ['image', 'video', 'raw'].contains(segments[1]) &&
          segments[2] == 'upload' &&
          !segments.any((s) => s.startsWith('s--')) &&
          !segments.any((s) => s.contains('fl_attachment'))) {
        return uri.replace(
          pathSegments: [
            ...segments.take(3),
            'fl_attachment',
            ...segments.skip(3),
          ],
        );
      }
    }
    return uri;
  }

  static String responseError(Uri uri, int status) {
    if (status == 404 || status == 410) {
      return 'This file is no longer available. Ask your teacher to upload it again.';
    }
    if (status == 401 || status == 403) {
      if (uri.host == 'res.cloudinary.com') {
        return 'The file host has blocked this resource (HTTP $status). Ask your teacher or administrator to check Cloudinary delivery permissions, including PDF delivery, or upload a working resource link.';
      }
      return 'The file provider denied access (HTTP $status). Ask your teacher to check the file sharing permissions.';
    }
    return 'The file provider returned HTTP $status. Please retry, or ask your teacher to check the resource link.';
  }

  static String errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FormatException) {
      return 'The resource link is invalid. Ask your teacher to attach the file again.';
    }
    return 'The resource could not be reached. Check your connection and try Open resource. If it still fails, ask your teacher to check the file link.';
  }
}
