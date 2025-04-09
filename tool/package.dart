import 'dart:io';
import 'package:archive/archive_io.dart';

void main(List<String> args) async {
  final version = _getVersionFromPubspec() ?? 'v0.0.0';

  // Paths
  final releaseInputDir = Directory(args.elementAt(0));

  // FIX: Resolve extrasInputDir relative to this script's location
  final scriptDir = File.fromUri(Platform.script).parent;
  final extrasInputDir = Directory('${scriptDir.parent.path}/dist/extras'); // root of the project

  final outputBaseDir = Directory(args.elementAt(1));

  final now = DateTime.now();
  final timestamp = '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}-'
      '${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}';

  final outputFolder = Directory('${outputBaseDir.path}/$timestamp/httpd_settings');
  final zipPath = '${outputBaseDir.path}/$timestamp/httpd_settings__${version}__$timestamp.zip';

  // Create output folder
  if (outputFolder.existsSync()) {
    outputFolder.deleteSync(recursive: true);
  }
  outputFolder.createSync(recursive: true);

  // Copy release files, excluding httpd_settings_data
  for (final file in releaseInputDir.listSync(recursive: true)) {
    final relative = file.path.replaceFirst(releaseInputDir.path, '');
    if (relative.contains('httpd_settings_data')) continue;

    final destPath = '${outputFolder.path}/$relative';
    if (file is File) {
      final destFile = File(destPath)..parent.createSync(recursive: true);
      await destFile.writeAsBytes(await file.readAsBytes());
    }
  }

  // Copy extra files (README, LICENSE, etc.)
  final extraFiles = ['README.txt', 'LICENSE.txt', 'CHANGELOG.txt', 'DEVELOPERS.txt'];
  for (final name in extraFiles) {
    final file = File('${extrasInputDir.path}/$name');
    if (file.existsSync()) {
      file.copySync('${outputFolder.path}/$name');
    }
  }

  // Create the ZIP archive
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  encoder.addDirectory(outputFolder);
  encoder.close();

  print('Release package created at: $zipPath');
}

String? _getVersionFromPubspec() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) return null;

  final lines = file.readAsLinesSync();
  for (final line in lines) {
    if (line.trim().startsWith('version:')) {
      final version = line.split(':').last.trim();
      return version;
    }
  }

  return null;
}
