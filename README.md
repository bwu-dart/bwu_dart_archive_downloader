BWU Dart Archive Downloader
======

BWU Dart Archive Downloader makes it easy to download files like API docs,
Dartium, Dartium for Android APK, Dart Eclipse plugin, or the Dart SDK from 
http://gsdview.appspot.com/dart-archive/channels/
Its main purpose is to make maintenance tasks and automatic setup for continuous
integration (CI) as easy as possible.

## Example 1
Download a file from `latest`:

```Dart
import 'dart:io' as io;
import 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';

main() async {
  // create an instance of the downloader and specify the download directory.
  final downloader = new DartArchiveDownloader(new io.Directory('temp'));

  // specify the file to download
  final file = new DartiumFile.contentShellZip(
      Platform.getFromSystemPlatform(prefer64bit: true));

  // build the uri for the download file.
  final uri =
      DownloadChannel.stableRelease.getUri(file);

  // start the download
  await downloader.downloadFile(uri);
}

```

## Example 2
Download a file from a specific release:

```Dart
final channel = DownloadChannel.stableRelease;
final downloader =
    new DartArchiveDownloader(new io.Directory('temp/install'));
final version =
    await downloader.findVersion(channel, new Version.parse('1.2.0'));
expect(version, isNotNull);
final uri = await channel.getUri(new SdkFile.dartSdk(
    Platform.getFromSystemPlatform(prefer64bit: true)), version: version);
final file = await downloader.downloadFile(uri);
```      
