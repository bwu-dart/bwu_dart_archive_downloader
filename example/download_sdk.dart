library bwu_dart_archive_downloader.example.download_sdk;

import 'dart:io' as io;

import 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';

main() async {
  // create an instance of the downloader and specify the download directory.
  final downloader = new DartArchiveDownloader(new io.Directory('temp'));

  // specify the file to download
  final file = new DartiumFile.contentShellZip(
      Platform.getFromSystemPlatform(prefer64bit: true));

  // build the uri for the download file.
  final uri = DownloadChannel.stableRelease.getUri(file);

  // start the download
  await downloader.downloadFile(uri);
}
