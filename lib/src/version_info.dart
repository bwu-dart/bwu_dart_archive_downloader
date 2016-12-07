import 'package:quiver/core.dart' show hash3;
import 'package:pub_semver/pub_semver.dart';

/// Contains the information gathered from the `VERSION` file in the download
/// directory.
class VersionInfo {
  final String revision;
  final String version;
  final DateTime date;

  VersionInfo({this.revision: '', this.version: '', DateTime date})
      : this.date = date ?? new DateTime(0);

  factory VersionInfo.fromJson(Map json) {
    final revision = json['revision'] as String;
    final version = json['version'] as String;
    final d = json['date'] as String;
    final year = int.parse(d.substring(0, 4));
    final month = int.parse(d.substring(5, 7));
    final day = int.parse(d.substring(8, 10));
//    final hour = int.parse(d.substring(8, 10)); // removed at 2015-05-30
//    final minute = int.parse(d.substring(10, 12));
    final date = new DateTime(year, month, day /*, hour, minute*/);
    return new VersionInfo(revision: revision, version: version, date: date);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'revision': revision,
      'version': version,
      'date': date.toIso8601String(),
    };
  }

  Version _semanticVersion;
  Version get semanticVersion =>
      _semanticVersion ??= new Version.parse(version);

  /// Strip revision to be used as `latest` for finding download version
  VersionInfo withoutRevision() =>
      new VersionInfo(revision: null, version: version, date: date);

  bool operator >(dynamic other) => compareTo(other as VersionInfo) > 0;
  bool operator <(dynamic other) => compareTo(other as VersionInfo) < 0;
  bool operator <=(dynamic other) => compareTo(other as VersionInfo) <= 0;
  bool operator >=(dynamic other) => compareTo(other as VersionInfo) >= 0;

  @override
  bool operator ==(dynamic other) =>
      other is VersionInfo && compareTo(other) == 0;

  int _hashCode;
  @override
  int get hashCode => _hashCode ??= hash3(revision, version, date);

  int compareTo(VersionInfo other) {
    if (other == null) {
      return 1;
    }
    if (!(semanticVersion.isPreRelease || other.semanticVersion.isPreRelease)) {
      return semanticVersion.compareTo(other.semanticVersion);
    }

    /// bleeding edge pre-release suffix aren't ascending
    if (semanticVersion.major == other.semanticVersion.major &&
        semanticVersion.minor == other.semanticVersion.minor &&
        semanticVersion.patch == other.semanticVersion.patch &&
        semanticVersion.isPreRelease == other.semanticVersion.isPreRelease) {
      if (date != null && other.date != null) {
        return date.compareTo(other.date);
      }
    }
    return semanticVersion.compareTo(other.semanticVersion);
  }
}
