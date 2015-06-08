library bwu_dart_archive_downloader.src.dart_archive_downloader;

import 'dart:async' show Future, Stream;
import 'dart:io' as io;
import 'dart:convert' show JSON;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' show Logger;
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

const baseUri = 'http://gsdview.appspot.com/dart-archive/channels/';
const apiAuthority = 'www.googleapis.com';
const apiPath = '/storage/v1/b/dart-archive/o';

final _log =
    new Logger('bwu_dart_archive_downloader.src.dart_archive_downloader');

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

  Version get semanticVersion {
    return new Version.parse(version);
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
    _log.fine('download "${uri.toString()}" to "${_downloadFile.path}".');

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

  Map<DownloadChannel, List<String>> _versions = {};

  // This uses the Drive api https://developers.google.com/drive/v2/reference/files/list
  // See also https://github.com/dart-lang/www.dartlang.org/blob/master/src/site/googleapis/index.markdown
  /// Load all available versions for the specified [channel].
  /// The returned list is sorted descending with `latest` as first entry.
  /// The value isn't necessarily a semantic version, but might also be a build
  /// number. It seems for newer releases this is actually the semantic version
  /// but as of the time of this writing there was only one entry with a
  /// semantic version all others were build numbers or other artifical numbers
  /// but ascending with newer releases.
  /// Semantic versions are ordered on top of other values when ordered
  /// descending.
  /// Fetching all versions takes some for the bleeding edge channel because
  /// there are about 15000 builds (without any proper ordering), which needs 18
  /// requests (increasing) and the response is very slow.
  Future<List<String>> getVersions(DownloadChannel channel) async {
    if (_versions.containsKey(channel)) {
      return _versions[channel];
    }
    String token;
    bool hasMorePages = true;
    Map query = {'prefix': 'channels/${channel.value}', 'delimiter': '/'};
    List<String> versions = <String>[];
    _log.fine('Fetch versions from ${channel.value}.');
    int currentPage = 1;

    while (hasMorePages) {
      if (token != null) {
        query['pageToken'] = token;
      } else {
        query.remove('pageToken');
      }
      Uri uri = new Uri.https(apiAuthority, apiPath, query);
      _log.fine('  page: ${currentPage++}');
      final response = JSON.decode((await http.get(uri)).body);
      token = response['nextPageToken'];
      if (token == null || token.isEmpty) {
        hasMorePages = false;
      }
      versions
          .addAll(response['prefixes']
              .map((e) =>
                  e.split('/').where((e) => e != null && e.isNotEmpty).last)
              .where(_isNotWeirdOrInvalidVersion));
//      _log.fine('${token}, ${response['prefixes'].first}');
    }

    versions.sort((k, v) => _descendingVersionComparer(k, v) * -1);
    versions.insert(0, 'latest');
    _versions[channel] = versions;
    return versions;
  }

  bool _isNotWeirdOrInvalidVersion(String version) {
    return version.isNotEmpty &&
        !weirdBuildNumberRegExp.hasMatch(
            version) /* ignore a few versions where Dartium was stored in another folder with suffix '.0' */ &&
        !['raw', 'be', '42', 'channels', 'latest',].contains(version.trim());
  }

  Future<String> findVersion(
      DownloadChannel channel, Version semanticVersion) async {
    final versions = await getVersions(channel);
    _log.fine('${versions.length - 2} versions found');
    return _findVersion(
        channel, semanticVersion, versions, 1, versions.length - 1);
  }

  Future<String> _findVersion(DownloadChannel channel, Version semanticVersion,
      List<String> versions, int start, int end) async {
    if (start == end) {
      final VersionInfo versionInfo =
          await _getVersionInfo(channel, versions[start]);
      _log.fine('check pos ${start}: ${versionInfo.semanticVersion}');
      return versions[start];
    }
    final mid = start + ((end - start) ~/ 2);
    final VersionInfo versionInfo =
        await _getVersionInfo(channel, versions[mid]);
    // _log.fine('start: ${start} - end: ${end} - mid: ${mid} - version: ${versionInfo.semanticVersion}');
    _log.fine('check pos ${mid}: ${versionInfo.semanticVersion}');

    if (semanticVersion == versionInfo.semanticVersion) {
      return versions[mid];
    } else if (semanticVersion < versionInfo.semanticVersion) {
      return _findVersion(channel, semanticVersion, versions, mid + 1, end);
    } else {
      return _findVersion(channel, semanticVersion, versions, start, mid - 1);
    }
  }

  Future<VersionInfo> _getVersionInfo(
      DownloadChannel channel, String version) async {
    final content = await downloadContent(
        channel.getUri(VersionFile.version, version: version));
    return new VersionInfo.fromJson(JSON.decode(content));
  }
}

int _descendingVersionComparer(String x, String y) {
  bool xIsSemVer = semVerRegExp.hasMatch(x);
  bool yIsSemVer = semVerRegExp.hasMatch(y);
  // sort semantic version values higher than build numbers
  // because newer builds are provided with semantic versions
  if (xIsSemVer && yIsSemVer) {
    return new Version.parse(x).compareTo(new Version.parse(y));
  } else if (xIsSemVer) {
    return -1;
  } else if (yIsSemVer) {
    return 1;
  }
  return x.padLeft(8).compareTo(y.padLeft(8));
}

final semVerRegExp = new RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+{?:[+-].*$');
final weirdBuildNumberRegExp = new RegExp(r'^[0-9]+\.0$');

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

  final String value;
  static const values = const [
    stableRaw,
    stableRelease,
    stableSigned,
    devRaw,
    devRelease,
    devSigned,
    beRaw
  ];

  /// Builds an Uri for an [DownloadArtifact].
  /// [version] is the directory name containing the download file. If you want
  /// to use a Dart release version, use [findVersion] the get the directory
  /// form the Dart release version.
  Uri getUri(DownloadFile file, {String version: 'latest'}) {
    if (version == null) version = 'latest';
    return Uri.parse(
        '${baseUri}${value}${version != null ? version : 'latest' }/${file.artifact.value}${file.value}');
  }
  const DownloadChannel(this.value);
}

/// A list of artifacts to download.
class DownloadArtifact {
  static const apiDocs = const DownloadArtifact('api-docs/', ApiDocsFile);
  static const dartium = const DownloadArtifact('dartium/', DartiumFile);
  static const dartiumAndroid =
      const DownloadArtifact('dartium_android/', DartiumAndroidFile);
  static const eclipseUpdate =
      const DownloadArtifact('editor-eclipse-update/', EditorEclipseUpdateFile);
  @deprecated
  static const editor = const DownloadArtifact('editor/', EditorFile);
  static const sdk = const DownloadArtifact('sdk/', SdkFile);
  static const version = const DownloadArtifact('', VersionFile);

  static const values = const [
    apiDocs,
    dartium,
    dartiumAndroid,
    eclipseUpdate,
    editor,
    sdk,
    version
  ];

  final String value;
  final Type downloadFile;
  const DownloadArtifact(this.value, this.downloadFile);
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

  static final values = {
    'chromedriver': (Platform platform, {bool debug: false,
            FileAddition fileAddition: FileAddition.none}) =>
        new DartiumFile.chromedriverZip(platform,
            debug: debug, fileAddition: fileAddition),
    'content_shell': (Platform platform, {bool debug: false,
            FileAddition fileAddition: FileAddition.none}) =>
        new DartiumFile.contentShellZip(platform,
            debug: debug, fileAddition: fileAddition),
    'dartium': (Platform platform, {bool debug: false,
            FileAddition fileAddition: FileAddition.none}) =>
        new DartiumFile.dartiumZip(platform,
            debug: debug, fileAddition: fileAddition)
  };
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

/// To build a file name for downloading Eclipse plugin updates.
// TODO(zoechi) not yet supported
class EditorEclipseUpdateFile extends DownloadFile {
  static const contentShell = const EditorEclipseUpdateFile('');

  @override
  DownloadArtifact get artifact => DownloadArtifact.eclipseUpdate;

  const EditorEclipseUpdateFile(String value) : super(value);
}

/// To build a file name for downloading Eclipse plugin updates.
// TODO(zoechi) not yet supported
class EditorFile extends DownloadFile {
  static const contentShell = const EditorFile('');

  @override
  DownloadArtifact get artifact => DownloadArtifact.editor;

  const EditorFile(String value) : super(value);
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

  static const values = const [];

  final String value;
  const Platform(this.value);
}

/// List of provided add-on files
class FileAddition {
  static const none = const FileAddition('');
  static const md5sum = const FileAddition('.md5sum');
  static const sha256sum = const FileAddition('.sha256sum');

  static const values = const [none, md5sum, sha256sum];

  final String value;
  const FileAddition(this.value);
}
