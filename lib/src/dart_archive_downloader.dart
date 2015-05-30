library bwu_dart_archive_downloader.src.dart_archive_downloader;

import 'dart:async' show Future, Stream;
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

const baseUri = 'http://gsdview.appspot.com/dart-archive/channels/';

/// Contains the information gathered from the `VERSION` file in the download
/// directory.
class VersionInfo {
  String revision;
  String version;
  DateTime date;

  VersionInfo({this.revision: '', this.version: '', this.date}) {
    if (date == null) date = new DateTime(0);
  }

  VersionInfo.fromJson(Map json) {
    revision = json['revision'];
    version = json['version'];
    final d = json['date'] as String;
    final year = int.parse(d.substring(0, 4));
    final month = int.parse(d.substring(5, 7));
    final day = int.parse(d.substring(8, 10));
//    final hour = int.parse(d.substring(8, 10)); // removed at 2015-05-30
//    final minute = int.parse(d.substring(10, 12));
    date = new DateTime(year, month, day /*, hour, minute*/);
  }

  bool operator >(other) {
    if (other == null || other is! VersionInfo) {
      return true;
    }

    return revision.compareTo((other as VersionInfo).revision) > 0;
  }

  bool operator <(other) {
    if (other == null || other is! VersionInfo) {
      return false;
    }

    return revision.compareTo((other as VersionInfo).revision) < 0;
  }

  bool operator ==(other) {
    if (other == null || other is! VersionInfo) {
      return false;
    }
    return revision == (other as VersionInfo).revision;
  }

  bool operator <=(other) => this < other || this == other;

  bool operator >=(other) => this > other || this == other;
}

/// Downloads an artifact from the Dart archive site.
class DartArchiveDownloader {
  io.Directory _downloadDirectory;
  io.File _downloadFile;

  /// If [downloadDestination] is a [io.Directory] the file is stored there with
  /// it's original name. If [downloadDestination] is a [io.File] the download
  /// is stored in this file. If the destination directory doesn't exist it is
  /// created.
  DartArchiveDownloader(io.FileSystemEntity downloadDestination) {
    assert(downloadDestination != null);
    if (downloadDestination is io.File) {
      _downloadDirectory = downloadDestination.parent;
    } else if (downloadDestination is io.Directory) {
      _downloadDirectory = downloadDestination;
    }
    if (!_downloadDirectory.existsSync()) {
      _downloadDirectory.createSync(recursive: true);
    }
  }

  /// Downloads the file [uri] points to to [downloadDestination].
  /// Returns a [io.File] referencing the downloaded file.
  Future<io.File> downloadFile(Uri uri) async {
    // head request not supported by the pate (for progress information)
    final request = new http.Request('GET', uri);
    if (_downloadFile == null) {
      _downloadFile = new io.File(
          path.join(_downloadDirectory.path, uri.pathSegments.last));
    }
    print('download "${uri.toString()}" to "${_downloadFile.path}".');

    final http.StreamedResponse response = await request.send();
    if (response.statusCode != 200) {
      throw 'Response: ${response.statusCode} - ${response.reasonPhrase}';
    }
    final downloadFileSink = _downloadFile.openWrite();
    int bytesCount = 0;
    int charsCount = 0;
    final subscription = response.stream.listen((data) {
      bytesCount += data.length;
      downloadFileSink.add(data);
      if (bytesCount ~/ 1000000 == 0) {
        //io.stdout.write('=');
        charsCount++;
        if (charsCount >= 80) {
          //io.stdout.writeln();
          charsCount = 0;
        }
      }
    });
    await subscription.asFuture();
    //io.stdout.writeln();
    await downloadFileSink.flush();
    await downloadFileSink.close();
    //await downloadFileSink.addStream(response.stream);
    return _downloadFile;
  }

  /// Downloads the file referenced by [uri] and returns its content.
  Future<String> downloadContent(Uri uri) async {
    return (await http.get(uri)).body;
  }
}

/// Build the Uri for a download file based on [DownloadChannel],
/// [DownloadFile], and version info.
class DownloadChannel {
  static const stableRaw = const DownloadChannel('stable/raw/');
  static const stableRelease = const DownloadChannel('stable/release/');
  static const stableSigned = const DownloadChannel('stable/signed/');
  static const devRaw = const DownloadChannel('dev/raw/');
  static const devRelease = const DownloadChannel('dev/raw/');
  static const devSigned = const DownloadChannel('dev/signed/');
  static const beRaw = const DownloadChannel('be/raw/');

  final String _value;

  /// Builds an Uri for an [DownloadArtifact]
  Uri getUri(DownloadFile file, {String version: 'latest'}) {
    return Uri.parse(
        '${baseUri}${_value}${version != null ? version : 'latest' }/${file.artifact.value}${file.value}');
  }
  const DownloadChannel(this._value);
}

/// A list of artifacts to download.
class DownloadArtifact {
  static const apiDocs = const DownloadArtifact('api-docs/');
  static const dartium = const DownloadArtifact('dartium/');
  static const dartiumAndroid = const DownloadArtifact('dartium_android/');
  static const eclipseUpdate = const DownloadArtifact('editor-eclipse-update/');
  @deprecated
  static const editor = const DownloadArtifact('editor/');
  static const sdk = const DownloadArtifact('sdk/');
  static const version = const DownloadArtifact('');

  final String value;
  const DownloadArtifact(this.value);
}

/// Base class for helper classes for specific download files.
abstract class DownloadFile {
  final String value;
  DownloadArtifact get artifact;
  const DownloadFile(this.value);
}

/// To build a file name for downloading a `VERSION` file.
class VersionFile extends DownloadFile {
  static const version = const VersionFile('VERSION');

  @override
  DownloadArtifact get artifact => DownloadArtifact.version;

  const VersionFile(String value) : super(value);
}

/// To build a file name for downloading an API-Docs file.
class ApiDocsFile extends DownloadFile {
  static const dartApiDocsZip = const ApiDocsFile('dart-api-docs.zip');

  @override
  DownloadArtifact get artifact => DownloadArtifact.apiDocs;

  const ApiDocsFile(String value) : super(value);
}

/// Builds a filename from the passed parts.
/// [filenameBase] the describing part of the file name.
/// [platform] the name part specifying the target platform (operating system,
///   and processor architecture)
/// [debug] if `true` the download containing debug information will be choosen.
/// [fileAddition] so select file add-ons like MD5 or SHA checksum files
String buildFilename(String filenameBase, Platform platform,
        {bool debug: false, FileAddition fileAddition: FileAddition.none}) =>
    '${filenameBase}-${platform.value}-${debug ? 'debug' : 'release'}.zip${fileAddition.value}';

/// To build a file name for downloading Dartium.
class DartiumFile extends DownloadFile {
  factory DartiumFile.chromedriverZip(Platform platform,
          {bool debug: false, FileAddition fileAddition: FileAddition.none}) =>
      new DartiumFile(buildFilename('chromedriver', platform,
          debug: debug, fileAddition: fileAddition));
  factory DartiumFile.contentShellZip(Platform platform,
          {bool debug: false, FileAddition fileAddition: FileAddition.none}) =>
      new DartiumFile(buildFilename('content_shell', platform,
          debug: debug, fileAddition: fileAddition));
  factory DartiumFile.dartiumZip(Platform platform,
          {bool debug: false, FileAddition fileAddition: FileAddition.none}) =>
      new DartiumFile(buildFilename('dartium', platform,
          debug: debug, fileAddition: fileAddition));

  @override
  DownloadArtifact get artifact => DownloadArtifact.dartium;

  DartiumFile(String value) : super(value);
}

/// To build a file name for downloading Dartium for Android.
class DartiumAndroidFile extends DownloadFile {
  static const contentShell =
      const DartiumAndroidFile('content_shell-android-arm-release.apk');

  @override
  DownloadArtifact get artifact => DownloadArtifact.dartiumAndroid;

  const DartiumAndroidFile(String value) : super(value);
}

/// To build a file name for downloading the Dart SDK.
class SdkFile extends DownloadFile {
  SdkFile._(String value) : super(value);

  @override
  DownloadArtifact get artifact => DownloadArtifact.sdk;

  factory SdkFile.dartSdk(Platform platform,
          {bool debug: false, FileAddition fileAddition: FileAddition.none}) =>
      new SdkFile._(buildFilename('dartsdk', platform,
          debug: debug, fileAddition: fileAddition));
}

/// List of provided platforms (operating system and processor architecture)
/// If there is a distinction between ia32 or x64 for one platform [prefer64bit]
/// decides which one to choose.
class Platform {
  static Platform getFromSystemPlatform({bool prefer64bit: true}) {
    assert(prefer64bit != null);
    if (io.Platform.isLinux) {
      if (prefer64bit) {
        return linuxX64;
      } else {
        return linuxIa32;
      }
    } else if (io.Platform.isMacOS) {
      return macosIa32;
    } else if (io.Platform.isWindows) {
      return windowsIa32;
    } else if (io.Platform.isAndroid) {
      return androidArm;
    }
    return null;
  }
  static const androidArm = const Platform('android-arm');
  static const linuxIa32 = const Platform('linux-ia32');
  static const linuxX64 = const Platform('linux-x64');
  static const macosIa32 = const Platform('macos-ia32');
  static const windowsIa32 = const Platform('windows-ia32');

  final String value;
  const Platform(this.value);
}

/// List of provided add-on files
class FileAddition {
  static const none = const FileAddition('');
  static const md5sum = const FileAddition('.md5sum');
  static const sha256sum = const FileAddition('.sha256sum');

  final String value;
  const FileAddition(this.value);
}
