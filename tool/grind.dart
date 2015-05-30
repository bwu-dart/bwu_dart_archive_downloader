library bwu_dart_archive_downloader.tool.grind;

import 'package:grinder/grinder.dart';
import 'package:bwu_utils_dev/grinder.dart';

main(List<String> args) => grind(args);

const existingSourceDirs = const ['lib', 'test', 'tool'];

@Task('Run analyzer')
analyze() => _analyze();

@Task('Runn all tests')
test() => _test();

@Task('Check everything')
@Depends(analyze, checkFormat, lint, test)
@DefaultTask()
check() => _check();

@Task('Check source code format')
checkFormat() => checkFormatTask(['.']);

/// format-all - fix all formatting issues
@Task('Fix all source format issues')
format() => _format();

@Task('Run lint checks')
lint() => _lint();

_analyze() => Pub.global.run('tuneup', arguments: ['check']);

_check() => run('pub', arguments: ['publish', '-n']);

_format() => new PubApp.global('dart_style').run(
    ['-w']..addAll(existingSourceDirs), script: 'format');

_lint() => new PubApp.global('linter')
    .run(['--stats', '-ctool/lintcfg.yaml']..addAll(existingSourceDirs));

_test() => new PubApp.local('test').run(['-pvm']);
