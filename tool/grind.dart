library bwu_dart_archive_downloader.tool.grind;

import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:bwu_grinder_tasks/bwu_grinder_tasks.dart' as tasks;
export 'package:bwu_grinder_tasks/bwu_grinder_tasks.dart' hide main;

main(List<String> args) {
  tasks.getSubProjects = getSubProjectsImpl;
  tasks.main(args);
}

// Like default but excludes `temp` directory
List<io.Directory> getSubProjectsImpl() => io.Directory.current
    .listSync(recursive: true)
    .where((d) => d.path.endsWith('pubspec.yaml') &&
        !d.absolute.path.startsWith(
            path.join(io.Directory.current.absolute.path, 'temp')) &&
        d.parent.absolute.path != io.Directory.current.absolute.path)
    .map((d) => d.parent)
    .toList();
