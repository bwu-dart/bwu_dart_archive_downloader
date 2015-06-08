library bwu_dart_archive_downloader.src.cli;

import 'dart:io' as io;
import 'package:bwu_dart_archive_downloader/bwu_dart_archive_downloader.dart';
import 'package:unscripted/unscripted.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:bwu_dart_archive_downloader/dart_update.dart';

main([List<String> arguments]) =>
    new Script(DownloadCommandModel).execute(arguments);

class DDownScriptModel extends Object with DownloadCommandModel {
  @Command(
      allowTrailingOptions: false,
      help: 'Download a file from the Dart archive.',
      plugins: const [const Completion()])
  DDownScriptModel();
}

class DownloadCommandModel {
  @SubCommand(help: '''
Download a file from the Dart archive (http://gsdview.appspot.com/dart-archive/channels/).
Version and download channel can be selected.''')
  down({@Option(help: '''
The base name of the file to download excluding extensions like "-ia32", ".md5sum", ... .''',
      abbr: 'f') //
//          defaultsTo: defaultStaticFilesSourceDirectory) //
      String filename, //
      @Option(help: '''
The absolute or relative path where the directory should be created.''',
          abbr: 'o',
          defaultsTo: '.') //
      String outputDirectory,
      //
      @Option(help: '''
The version to download.''', abbr: 'v', defaultsTo: 'latest') //
      String version,
      //
      @Option(help: '''
The channel to download from.
  Possible values:
    - stable/raw
    - stable/release
    - stable/signed
    - dev/raw
    - dev/raw
    - dev/signed
    - be/raw
''', //
          abbr: 'c', defaultsTo: 'stable/release') //
      String channel,
      //
      @Option(help: '''
Choose a folder in the archive:
  Possible values:
    - api-docs
    - dartium
    - dartium_android
    - (editor-eclipse-update - not implemented)
    - (editor - not implemented)
    - sdk
    - VERSION
''', abbr: 'a', defaultsTo: 'sdk') //
      String artifact,
      //
      @Option(help: '''
The target operating system and architecture. If omitted it will be derived
from the system.
  Possible values:
    - android-arm
    - linux-ia32
    - linux-x64
    - macos-ia32
    - windows-ia32
''', abbr: 'p') //
//          defaultsTo: 'current system') //
      String platform, @Option(help: '''
Choose an addon-file instead of the main file.
  Possible values:
    - md5sum
    - sha256sum
''', abbr: 's', defaultsTo: '') //
      String fileAddition,
      //
      @Flag(help: '''
If "platform" is omitted and derived from the system, should it download the
64 bit version if available?.''',
          abbr: 'b',
          defaultsTo: true,
          negatable: true) //
      bool prefer64bit, //
      @Flag(help: '''
Get the debug build of the file.''',
//          abbr: 'd',
          defaultsTo: false, negatable: true) //
      bool debugBuild, //
      @Flag(help: '''
Extract the downloaded ZIP archive file.''',
          abbr: 'e',
          defaultsTo: false,
          negatable: true) //
      bool extract, //
      @Option(help: '''
Extracts the ZIP archive top-level directory into the the "extractAs" directory.''',
      abbr: 'd') //
//          defaultsTo: '.') //
      String extractAs, //
      @Option(help: '''
Extracts the ZIP archive top-level directory into the the "extractAs" directory.''',
          abbr: 't',
          defaultsTo: '.') //
      String extractTo}) async {
    final downloader = new DartArchiveDownloader(outputDirectory == '.'
        ? io.Directory.current
        : new io.Directory(outputDirectory));

    final Iterable<DownloadChannel> channels =
        DownloadChannel.values.where((v) => v.value.startsWith(channel));
    if (channels.isEmpty) {
      throw 'Channel "${channel}" isn\'t supported or recognized.';
    } else {
      print('Using channel "${channels.first.value}".');
    }

    String versionDirectory;
    if (version == 'latest') {
      versionDirectory = version;
    } else {
      Version parsedVersion;
      try {
        parsedVersion = new Version.parse(version);
      } catch (e) {
        throw 'Version "${version}" can\'t be parsed.';
      }
      versionDirectory =
          await downloader.findVersion(channels.first, parsedVersion);
    }

    final Iterable<DownloadArtifact> artifacts =
        DownloadArtifact.values.where((v) => v.value.startsWith(artifact));
    if (artifacts.isEmpty) {
      throw 'Artifact "${artifact}" isn\'t supported or recognized.';
    } else {
      print('Using artifact "${artifacts.first.value}".');
    }

    final Iterable<FileAddition> fileAdditions =
        FileAddition.values.where((v) => v.value.startsWith(fileAddition));
    if (fileAdditions.isEmpty) {
      throw 'FileAddition "${fileAddition}" isn\'t supported or recognized.';
    } else {
      print('Using file addition "${fileAdditions.first.value}".');
    }

    Iterable<Platform> platforms;
    if (platform == null || platform.isEmpty) {
      platforms = [Platform.getFromSystemPlatform(prefer64bit: prefer64bit)];
    } else {
      platforms = Platform.values.where((v) => v.value.startsWith(platform));
      if (platforms.isEmpty) {
        throw 'Platform "${platform}" isn\'t supported or recognized.';
      } else {
        print('Using platform "${platforms.first.value}".');
      }
    }

    DownloadFile downloadFile;
    switch (artifacts.first) {
      case DownloadArtifact.apiDocs:
        downloadFile = ApiDocsFile.dartApiDocsZip;
        if (filename != null) {
          print('Ignoring parameter filename ("${filename}").');
        }
        break;
      case DownloadArtifact.dartium:
        final fileConstructors =
            DartiumFile.values.keys.where((v) => v.startsWith(filename));
        if (fileConstructors.isEmpty) {
          throw 'File "${filename}" isn\'t supported or recognized.';
        } else {
          print('Using download file "${fileConstructors.first}".');
        }
        downloadFile = DartiumFile.values[fileConstructors.first](
            platforms.first,
            debug: debugBuild, fileAddition: fileAdditions.first);
        break;
      case DownloadArtifact.dartiumAndroid:
        downloadFile = DartiumAndroidFile.contentShell;
        if (filename != null) {
          print('Ignoring parameter filename ("${filename}").');
        }
        break;
      case DownloadArtifact.eclipseUpdate:
        throw 'Download Eclipse updates isn\'t yet implemented.';
        break;
      case DownloadArtifact.editor:
        throw 'Download DartEditor isn\'t yet implemented.';
        break;
      case DownloadArtifact.sdk:
        downloadFile = new SdkFile.dartSdk(platforms.first,
            debug: debugBuild, fileAddition: fileAdditions.first);
        if (filename != null) {
          print('Ignoring parameter filename ("${filename}").');
        }
        break;
      case DownloadArtifact.version:
        downloadFile = VersionFile.version;
        if (filename != null) {
          print('Ignoring parameter filename ("${filename}").');
        }
        break;
      default:
        // Unsupported artifacts are handled above.
        break;
    }

    final uri = channels.first.getUri(downloadFile, version: versionDirectory);
    io.File archiveFile = await downloader.downloadFile(uri);
    if (extract) {
      installArchive(archiveFile, new io.Directory(extractTo),
          replaceRootDirectoryName: extractAs != null && extractAs.isNotEmpty
              ? extractAs
              : null);
    }
  }
}
