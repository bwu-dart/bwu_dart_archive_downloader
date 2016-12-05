library bwu_dart_archive_downloader.src.dart_update;

import 'dart:async' show Future;
import 'dart:convert' show JSON;
import 'dart:io' as io;

import 'package:archive/archive.dart';
import 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:path/path.dart' as path;

export 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';

final _log = new Logger('bwu_dart_archive_downloader.src.dart_update');

// TODO(zoechi) investigate this API
// https://www.googleapis.com/storage/v1/b/dart-archive/o?prefix=channels/stable/release/&delimiter=/
// used by the dartlang.org download page

/// Supported options for the SDK download.
class SdkDownloadOptions {
  /// The directory to store the downloaded file in.
  io.Directory downloadDirectory;

  // String currentVersionFileNameSuffix = 'VERSION_current';
  /// The directory where to extract the downloaded SDK zip archive.
  /// The content of the archive is put directly in this directory omitting the
  /// top-level directory of the archive.
  io.Directory installDirectory;

  /// The directory where the currently installed SDK is moved before the new
  /// one is extracted.
  io.Directory backupDirectory;

  /// The operating system and processor architecture to choose for the
  /// download. If this is null, it is derived from the current system.
  Platform targetPlatform;

  /// Prefer 64 bit download.
  bool use64bitIfAvailable = true;

  /// Choose a download channel for the download.
  DownloadChannel channel = DownloadChannel.stableRelease;

// TODO(zoechi) not (yet?) supported
//  /// The release version of the download.
//  /// If [version] and [versionDirectory] are `null`, `latest` is used as
//  /// [versionDirectory]
//  Version version;
//
//  /// The directory the download is served in. If [version] is provided
//  /// [DartUpdate] tries to discover the [versionDirectory] itself.
//  String versionDirectory;
}

/// Download the SDK, backup the existing installation directory, extract the
/// download to the installation directory.
class DartUpdate {
  final SdkDownloadOptions _options;

  /// For an existing installation
  DartUpdate(this._options) {
    assert(_options != null);
    if (_options.targetPlatform == null) {
      _options.targetPlatform = Platform.getFromSystemPlatform();
    }
  }

  /// Execute the update.
  Future update() async {
    final currentVersion = getCurrentVersionInfo();
    print('Current version: "${currentVersion.toJson()}"');
    final latestVersion = (await downloadLatestVersionInfo());
    if (latestVersion <= currentVersion) {
      print('No newer version found.');
    } else {
      backup(currentVersion);

      versionFile().writeAsStringSync(JSON.encode(latestVersion.toJson()));
      print(
          'write version file: ${versionFile().path}, ${latestVersion.toJson()}');

      final useLatestVersion = latestVersion.withoutRevision();
      final pendingDownloads = <Future<io.File>>[
        downloadFile(useLatestVersion, DownloadArtifact.sdk,
                new SdkFile.dartSdk(_options.targetPlatform))
            .then/*<io.File>*/(
                (f) => installArchive(f, _options.installDirectory)),
        downloadFile(useLatestVersion, DownloadArtifact.dartium,
                new DartiumFile.dartiumZip(_options.targetPlatform))
            .then/*<io.File>*/((f) => installArchive(
                f, _options.installDirectory,
                replaceRootDirectoryName: 'dartium')),
        downloadFile(useLatestVersion, DownloadArtifact.dartium,
                new DartiumFile.contentShellZip(_options.targetPlatform))
            .then/*<io.File>*/((f) => installArchive(
                f, _options.installDirectory,
                replaceRootDirectoryName: 'content_shell')),
        downloadFile(useLatestVersion, DownloadArtifact.dartium,
                new DartiumFile.chromedriverZip(_options.targetPlatform))
            .then/*<io.File>*/((f) => installArchive(
                f, _options.installDirectory,
                replaceRootDirectoryName: 'chromedriver'))
      ];

      final List<io.File> files = await Future.wait(pendingDownloads);
      files.where((f) => f != null).forEach((f) => print(f.path));

      await Future.wait(pendingDownloads);
      _log.info('Downloads finished');
    }
  }

  io.File versionFile() =>
      new io.File(path.join(_options.installDirectory.path, 'VERSION.json'));

  /// Load the `VERSION` file from the currently installed SDK
  VersionInfo getCurrentVersionInfo() {
    final currentVersionFile = versionFile();
    if (currentVersionFile.existsSync()) {
      try {
        return new VersionInfo.fromJson(
            JSON.decode(currentVersionFile.readAsStringSync())
                as Map<String, dynamic>);
      } catch (_) {}
    }
    return new VersionInfo();
  }

  /// Download the `VERSION` file from the selected channel and construct a
  /// [VersionInfo] from the content.
  Future<VersionInfo> downloadLatestVersionInfo() async {
    final downloader = new DartArchiveDownloader(_options.downloadDirectory);

    final newVersionDownloadFile = await downloader
        .downloadFile(_options.channel.getUri(VersionFile.version));
    return new VersionInfo.fromJson(
        JSON.decode(newVersionDownloadFile.readAsStringSync())
            as Map<String, dynamic>);
  }

  /// Execute the download of the SDK.
  Future<io.File> downloadFile(
      VersionInfo version, DownloadArtifact artifact, DownloadFile file) {
    final downloader = new DartArchiveDownloader(_options.downloadDirectory);

    return downloader.downloadFile(_options.channel.getUri(file,
        version: version != null && version.revision != null
            ? version.revision.toString()
            : null));
  }

  /// Execute the backup of the installed SDK.
  void backup(VersionInfo currentVersion) {
    if (_options.backupDirectory == null) {
      return;
    }
    if (!_options.installDirectory.existsSync()) {
      _options.installDirectory.createSync(recursive: true);
    }
    final files = _options.installDirectory.listSync();
    io.Directory backupDirectory;
    if (files.length == 0) {
      return;
    }
    final dateString = new DateTime.now().toIso8601String().replaceAll(':', '');
    final currentVersionName =
        currentVersion != null && currentVersion.revision != null
            ? '${currentVersion.revision}_$dateString'
            : dateString;
    backupDirectory = new io.Directory(
        path.join(_options.backupDirectory.path, currentVersionName));

    if (!backupDirectory.existsSync()) {
      backupDirectory.createSync(recursive: true);
    }
    files.forEach((f) {
      f.rename(path.join(backupDirectory.path, path.basename(f.path)));
    });
  }
}

/// Get the root directory of the Zip [archive] files content.
String getZipRootDirectory(io.File archive) {
  final bytes = archive.readAsBytesSync();
  final files = new ZipDecoder().decodeBytes(bytes);
  return files.first.name;
}

/// Extract the [archive] to [installDirectory] (omitting the top-level
/// directory of the Zip archive)
Future installArchive(io.File archive, io.Directory installDirectory,
    {String replaceRootDirectoryName}) async {
  _log.info(
      'Extract "${archive.absolute.path}" to "${installDirectory.absolute.path}".');
  final io.Process process = await io.Process.start('unzip',
      [archive.absolute.path, '*/*', '-d', installDirectory.absolute.path]);
  process.stdout.listen(io.stdout.add);
  process.stderr.listen(io.stderr.add);
  await process.exitCode;
  if (replaceRootDirectoryName != null) {
    await new io.Directory(
            path.join(installDirectory.path, getZipRootDirectory(archive)))
        .rename(path.join(installDirectory.path, replaceRootDirectoryName));
  }

// TODO(zoechi) this didn't work well (hung on big files), try to find a fix
//  Future installArchiveZipIo(io.File archive, io.Directory installDirectory,
//      {String replaceRootDirectoryName}) async {
//    await for (ZipEntity entity in readZip(archive.path)) {
//      String filename;
//      if (entity is ZipEntry) {
//        if (replaceRootDirectoryName != null) {
//          filename = path.joinAll([replaceRootDirectoryName]
//            ..addAll(path.split((entity as ZipEntryImpl).name).sublist(1)));
//        } else {
//          filename = (entity as ZipEntryImpl).name;
//        }
//        _log.fine(filename);
//
//        if (entity.isDirectory) {
//          final dir =
//              new io.Directory(path.join(installDirectory.path, filename))
//            ..createSync(recursive: true);
//          _log.info('created: ${dir.path}');
//        } else {
//          final newFile =
//              new io.File(path.join(installDirectory.path, filename))
//            ..createSync(recursive: true);
//
//          await newFile.openWrite().addStream((entity as ZipEntry).content());
//          _log.info('created: ${newFile.path}');
//        }
//      } else {
//        _log.fine(entity.runtimeType);
//      }
//    }
////    final archive = loadArchiveContent(sdkArchive);
////    for (ArchiveFile file in archive) {
////      String filename = file.name;
////      if (filename.endsWith('/')) {
////        final dir = new io.Directory(
////            path.join(_options.installDirectory.path, filename))
////          ..createSync(recursive: true);
////        _log.info('created: ${dir.path}');
////      } else {
////        List<int> data = file.content;
////        final newFile =
////            new io.File(path.join(_options.installDirectory.path, filename))
////          ..createSync(recursive: true)
////          ..writeAsBytesSync(data);
////        _log.info('create: ${newFile.path}');
////      }
////    }
//    _log.info('Install "${installDirectory.path}" completed');
//  }
}
