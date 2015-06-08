BWU Dart Archive Downloader
======

[![Star this Repo](https://img.shields.io/github/stars/bwu-dart/bwu_dart_archive_downloader.svg?style=flat)](https://github.com/bwu-dart/bwu_dart_archive_downloader)
[![Pub Package](https://img.shields.io/pub/v/bwu_dart_archive_downloader.svg?style=flat)](https://pub.dartlang.org/packages/bwu_dart_archive_downloader)
[![Build Status](https://travis-ci.org/bwu-dart/bwu_dart_archive_downloader.svg?branch=travis)](https://travis-ci.org/bwu-dart/bwu_dart_archive_downloader)
[![Coverage Status](https://coveralls.io/repos/bwu-dart/bwu_dart_archive_downloader/badge.svg)](https://coveralls.io/r/bwu-dart/bwu_dart_archive_downloader)

BWU Dart Archive Downloader makes it easy to download files like API docs,
Dartium or content-shell, Dartium for Android APK, Dart Eclipse plugin, or the 
Dart SDK from http://gsdview.appspot.com/dart-archive/channels/  
Its main purpose is to make maintenance tasks and automatic setup for continuous
integration (CI) as easy as possible.

## Activate the command line tool
To activate the command line tool globally use this command:
 
```sh
pub global activate bwu_dart_archive_downloader
```
Now you can call the command line tool using 

```sh
pub global run bwu_dart_archive_downloader:darc ...
```

or if you have added the `~/.pub-cache/bin` directory to the `PATH` environment
variable just:
               
```sh
darc
```

## Example 1 
Download Dart SDK 1.5.2 from the command line:

```sh
darc down -v1.5.2
```
downloads `dartsdk-linux-x64-release.zip` to the curent working directory.
`Linux x64` is derived from my operating system, but can also be specified by 
a parameter.  
If you omit the `-v...` parameter the latest version is downloaded.


## Example 2 
Download chromedriver 1.5.2 from the command line:

```sh
darc down -adartium -fchromedriver -o_output -v1.5.2 -cstable/release  -e -dxxx -t_extract
```

This results in two subdirectories in the current working directory
- `_output`
- `_extract`    

`_output` is the directory where the downloaded file 
`chromedriver-linux-x64-release.zip` is stored because of the `-o` parameter.      
`_extract` is where the content of the ZIP file is extracted to as specified by 
the `-t` parameter.   
Because we passed `-dxxx`, the content (`chromedriver-lucid64-full-stable-37942.0`
from `chromedriver-linux-x64-release.zip`) was extracted as `_extract/xxx` which 
now contains the file `chromedriver`.    
`-cstable/release` can be omitted because it is the default, but it shows how to
select a specific channel.


## Example 3
Download a file from `latest` using the API:

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

## Example 4
Download a file from a specific release using the API:

```Dart
final channel = DownloadChannel.stableRelease;
final downloader =
    new DartArchiveDownloader(new io.Directory('temp/install'));
final version =
    await downloader.findVersion(channel, new Version.parse('1.2.0'));
final uri = await channel.getUri(new SdkFile.dartSdk(
    Platform.getFromSystemPlatform(prefer64bit: true)), version: version);
final file = await downloader.downloadFile(uri);
```      

The `dart_update` library provides functions to extract the downloaded archive.
