library bwu_dart_archive_downloader.src.dart_update;

import 'dart:async' show Future, Stream;
import 'dart:io' as io;
import 'dart:convert' show JSON;
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';
export 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';
//export 'package:bwu_utils_dev/grinder.dart';

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
    final latestVersion = await downloadLatestVersionInfo()..revision = null;
    //if(latestVersion > currentVersion) {
    backup(currentVersion);

    final pendingDownloads = [];
    pendingDownloads.add(downloadFile(latestVersion, DownloadArtifact.sdk,
            new SdkFile.dartSdk(_options.targetPlatform))
        .then((f) => installArchive(f, _options.installDirectory)));

    pendingDownloads.add(downloadFile(latestVersion, DownloadArtifact.dartium,
        new DartiumFile.dartiumZip(_options.targetPlatform)).then(
        (f) => installArchive(f, _options.installDirectory,
            replaceRootDirectoryName: 'dartium')));

    pendingDownloads.add(downloadFile(latestVersion, DownloadArtifact.dartium,
        new DartiumFile.contentShellZip(_options.targetPlatform)).then(
        (f) => installArchive(f, _options.installDirectory,
            replaceRootDirectoryName: 'content_shell')));

    pendingDownloads.add(downloadFile(latestVersion, DownloadArtifact.dartium,
        new DartiumFile.chromedriverZip(_options.targetPlatform)).then(
        (f) => installArchive(f, _options.installDirectory,
            replaceRootDirectoryName: 'chromedriver')));

    final List<io.File> files = await Future.wait(pendingDownloads);
    files.where((f) => f != null).forEach((f) => print(f.path));

    await Future.wait(pendingDownloads);
    print('Downloads finished');
    //}

  }

  /// Load the `VERSION` file from the currently installed SDK
  io.File versionFile(String suffix) => new io.File(path.join(
      _options.downloadDirectory.path,
      '${DownloadArtifact.version.value}_${_options.targetPlatform.value}_VERSION_${suffix}.json'));

  VersionInfo getCurrentVersionInfo() {
    final currentVersionFile = versionFile('current');
    if (currentVersionFile.existsSync()) {
      try {
        return new VersionInfo.fromJson(
            JSON.decode(currentVersionFile.readAsStringSync()));
      } catch (_) {}
    }
    return new VersionInfo();
  }

  /// Download the `VERSION` file from the selected channel and construct a
  /// [VersionInfo] from the content.
  Future<VersionInfo> downloadLatestVersionInfo() async {
    final downloader = new DartArchiveDownloader(_options.downloadDirectory);

    io.File newVersionFile = await downloader
        .downloadFile(_options.channel.getUri(VersionFile.version));
    newVersionFile = newVersionFile.renameSync(versionFile('new').path);
    return new VersionInfo.fromJson(
        JSON.decode(newVersionFile.readAsStringSync()));
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
    var currentVersionName = currentVersion != null &&
            currentVersion.revision != null
        ? '${currentVersion.revision}_${dateString}'
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
  List<int> bytes = archive.readAsBytesSync();
  final files = new ZipDecoder().decodeBytes(bytes);
  return files.first.name;
}

/// Extract the [archive] to [installDirectory] (omitting the top-level
/// directory of the Zip archive)
Future installArchive(io.File archive, io.Directory installDirectory,
    {String replaceRootDirectoryName}) async {
  print(
      'Extract "${archive.absolute.path}" to "${installDirectory.absolute.path}".');
  final io.Process process = await io.Process.start('unzip', [
    archive.absolute.path,
    '*/*',
    '-d',
    installDirectory.absolute.path
  ]);
  io.stdout.addStream(process.stdout);
  io.stderr.addStream(process.stderr);
  await process.exitCode;
  if (replaceRootDirectoryName != null) {
    new io.Directory(
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
//        print(filename);
//
//        if (entity.isDirectory) {
//          final dir =
//              new io.Directory(path.join(installDirectory.path, filename))
//            ..createSync(recursive: true);
//          print('created: ${dir.path}');
//        } else {
//          final newFile =
//              new io.File(path.join(installDirectory.path, filename))
//            ..createSync(recursive: true);
//
//          await newFile.openWrite().addStream((entity as ZipEntry).content());
//          print('created: ${newFile.path}');
//        }
//      } else {
//        print(entity.runtimeType);
//      }
//    }
////    final archive = loadArchiveContent(sdkArchive);
////    for (ArchiveFile file in archive) {
////      String filename = file.name;
////      if (filename.endsWith('/')) {
////        final dir = new io.Directory(
////            path.join(_options.installDirectory.path, filename))
////          ..createSync(recursive: true);
////        print('created: ${dir.path}');
////      } else {
////        List<int> data = file.content;
////        final newFile =
////            new io.File(path.join(_options.installDirectory.path, filename))
////          ..createSync(recursive: true)
////          ..writeAsBytesSync(data);
////        print('create: ${newFile.path}');
////      }
////    }
//    print('Install "${installDirectory.path}" completed');
//  }
}
