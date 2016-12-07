@TestOn('vm')
library bwu_dart_archive_downloader.test.dart_archive_downloader;

import 'package:bwu_dart_archive_downloader/src/version_info.dart'
    show VersionInfo;
import 'package:test/test.dart';

void main() {
  group('operator', () {
    test('<', () {
      expect(
          new VersionInfo(version: '1.0.0') < new VersionInfo(version: '2.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '2.0.0') < new VersionInfo(version: '1.0.0'),
          isFalse);
      expect(new VersionInfo(version: '1.0.0') < null, isFalse);
    });

    test('>', () {
      expect(
          new VersionInfo(version: '2.0.0') > new VersionInfo(version: '1.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '1.0.0') > new VersionInfo(version: '2.0.0'),
          isFalse);
      expect(new VersionInfo(version: '1.0.0') > null, isTrue);
    });

    test('==', () {
      expect(
          new VersionInfo(version: '1.0.0') ==
              new VersionInfo(version: '1.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '1.0.0') ==
              new VersionInfo(version: '2.0.0'),
          isFalse);
      expect(new VersionInfo(version: '1.0.0') == null, isFalse);
    });

    test('<=', () {
      expect(
          new VersionInfo(version: '1.0.0') <=
              new VersionInfo(version: '2.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '2.0.0') <=
              new VersionInfo(version: '1.0.0'),
          isFalse);
      expect(new VersionInfo(version: '1.0.0') <= null, isFalse);

      expect(
          new VersionInfo(version: '1.0.0') <=
              new VersionInfo(version: '1.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '1.0.0') <=
              new VersionInfo(version: '2.0.0'),
          isTrue);
      expect(new VersionInfo(version: '1.0.0') <= null, isFalse);
    });

    test('>=', () {
      expect(
          new VersionInfo(version: '2.0.0') >=
              new VersionInfo(version: '1.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '1.0.0') >=
              new VersionInfo(version: '2.0.0'),
          isFalse);
      expect(new VersionInfo(version: '1.0.0') >= null, isTrue);

      expect(
          new VersionInfo(version: '1.0.0') >=
              new VersionInfo(version: '1.0.0'),
          isTrue);
      expect(
          new VersionInfo(version: '1.0.0') >=
              new VersionInfo(version: '2.0.0'),
          isFalse);
      expect(new VersionInfo(version: '1.0.0') >= null, isTrue);
    });

    test('bleeding edge versions', () {
      final current = new VersionInfo(
          revision: 'bb92055c477f8ddcf4b6be07eef6f3d6d9c0ac03',
          version: '1.21.0-edge.bb92055c477f8ddcf4b6be07eef6f3d6d9c0ac03',
          date: DateTime.parse('2016-12-05'));
      final latest = new VersionInfo(
          revision: '0631ed9187ae35c09744df5665d0477e3f090288',
          version: '1.21.0-edge.0631ed9187ae35c09744df5665d0477e3f090288',
          date: DateTime.parse('2016-12-06'));
      expect(current < latest, isTrue, reason: '<');
      expect(current == latest, isFalse, reason: '==');
      expect(current > latest, isFalse, reason: '>');

      expect(latest < current, isFalse, reason: '<');
      expect(latest == current, isFalse, reason: '==');
      expect(latest > current, isTrue, reason: '>');
    });
  });
}
