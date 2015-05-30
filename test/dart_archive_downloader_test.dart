library bwu_utils_dev.test.grinder.dart_archive_downloader;

import 'package:test/test.dart';
import 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';

main() {
  group('operator', () {
    test('<', () {
      expect(new VersionInfo(revision: '1') < new VersionInfo(revision: '2'),
          isTrue);
      expect(new VersionInfo(revision: '2') < new VersionInfo(revision: '1'),
          isFalse);
      expect(new VersionInfo(revision: '1') < null, isFalse);
    });

    test('>', () {
      expect(new VersionInfo(revision: '2') > new VersionInfo(revision: '1'),
          isTrue);
      expect(new VersionInfo(revision: '1') > new VersionInfo(revision: '2'),
          isFalse);
      expect(new VersionInfo(revision: '1') > null, isTrue);
    });

    test('==', () {
      expect(new VersionInfo(revision: '1') == new VersionInfo(revision: '1'),
          isTrue);
      expect(new VersionInfo(revision: '1') == new VersionInfo(revision: '2'),
          isFalse);
      expect(new VersionInfo(revision: '1') == null, isFalse);
    });

    test('<=', () {
      expect(new VersionInfo(revision: '1') <= new VersionInfo(revision: '2'),
          isTrue);
      expect(new VersionInfo(revision: '2') <= new VersionInfo(revision: '1'),
          isFalse);
      expect(new VersionInfo(revision: '1') <= null, isFalse);

      expect(new VersionInfo(revision: '1') <= new VersionInfo(revision: '1'),
          isTrue);
      expect(new VersionInfo(revision: '1') <= new VersionInfo(revision: '2'),
          isTrue);
      expect(new VersionInfo(revision: '1') <= null, isFalse);
    });

    test('>=', () {
      expect(new VersionInfo(revision: '2') >= new VersionInfo(revision: '1'),
          isTrue);
      expect(new VersionInfo(revision: '1') >= new VersionInfo(revision: '2'),
          isFalse);
      expect(new VersionInfo(revision: '1') >= null, isTrue);

      expect(new VersionInfo(revision: '1') >= new VersionInfo(revision: '1'),
          isTrue);
      expect(new VersionInfo(revision: '1') >= new VersionInfo(revision: '2'),
          isFalse);
      expect(new VersionInfo(revision: '1') >= null, isTrue);
    });
  });
}
