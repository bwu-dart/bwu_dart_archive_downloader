@TestOn('vm')
library bwu_dart_archive_downloader.test.dart_sdk_download;

import 'dart:io' as io;
import 'package:test/test.dart';
import 'package:bwu_dart_archive_downloader/src/dart_update.dart';
import 'package:pub_semver/pub_semver.dart';

main() {
  group('download SDK', () {
    io.Directory tempDir;

    setUp(() {
      tempDir = io.Directory.systemTemp.createTempSync('sdk_download_test-');
    });

    tearDown(() {
      if (tempDir != null) {
        return tempDir.delete(recursive: true);
      }
    });

    test('download be/raw/latest', () async {
      final updater = new DartUpdate(new SdkDownloadOptions()
        ..downloadDirectory = tempDir
        ..channel = DownloadChannel.beRaw
        ..installDirectory = new io.Directory('temp/install')
        ..backupDirectory = new io.Directory('temp/backup'));

      await updater.update();
      print('done');
    },
        skip: 'just for manual testing',
        timeout: const Timeout(const Duration(seconds: 500)));

    test('download version be/raw/131727', () async {
      final channel = DownloadChannel.beRaw;
      final downloader =
          new DartArchiveDownloader(new io.Directory('temp/install'));
      final uri = channel.getUri(new SdkFile.dartSdk(
              Platform.getFromSystemPlatform(prefer64bit: true)),
          version: '131727');
      final io.File file = await downloader.downloadFile(uri);
      expect(file.existsSync(), isTrue);
      print('done');
    },
        skip: 'just for manual testing',
        timeout: const Timeout(const Duration(seconds: 500)));

    test('download version be/raw/ Version 1.2.0-edge.32698', () async {
      final channel = DownloadChannel.beRaw;
      final downloader =
          new DartArchiveDownloader(new io.Directory('temp/install'));
      final version = await downloader.findVersion(
          channel, new Version.parse('1.2.0-edge.32698'));
      expect(version, isNotNull);
      final uri = await channel.getUri(new SdkFile.dartSdk(
          Platform.getFromSystemPlatform(prefer64bit: true)), version: version);
      final io.File file = await downloader.downloadFile(uri);
      expect(file.existsSync(), isTrue);
      print('done');
    },
        skip: 'just for manual testing',
        timeout: const Timeout(const Duration(seconds: 500)));

    test('download version stable/release/ Version 1.2.0', () async {
      final channel = DownloadChannel.stableRelease;
      final downloader =
          new DartArchiveDownloader(new io.Directory('temp/install'));
      final version =
          await downloader.findVersion(channel, new Version.parse('1.2.0'));
      expect(version, isNotNull);
      final uri = await channel.getUri(new SdkFile.dartSdk(
          Platform.getFromSystemPlatform(prefer64bit: true)), version: version);
      final io.File file = await downloader.downloadFile(uri);
      expect(file.existsSync(), isTrue);
      print('done');
    },
        skip: 'just for manual testing',
        timeout: const Timeout(const Duration(seconds: 500)));
  });

  group('fetch available versions', () {
    test('be/raw', () async {
      final downloader = new DartArchiveDownloader(new io.File(''));
      final versions = await downloader.getVersions(DownloadChannel.beRaw);
      expect(versions.first, 'latest');
      expect(versions, contains('27464'));
      expect(versions, contains('45833'));
      expect(versions, contains('131447'));
      expect(versions, contains('131727'));
      expect(versions, isNot(contains('raw')));
    }, timeout: const Timeout(const Duration(seconds: 100)));
  }, skip: true);
}
