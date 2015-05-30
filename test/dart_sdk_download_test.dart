@TestOn('vm')
library bwu_dart_archive_downloader.test.dart_sdk_download;

import 'dart:io' as io;
import 'package:test/test.dart';
import 'package:bwu_dart_archive_downloader/src/dart_update.dart';

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
    test('download', () async {
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
  });
}
