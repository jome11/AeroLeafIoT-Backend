import 'dart:io';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    final dllPath = Uri.file('${Directory.current.path}\\sqlite3.dll');
    output.addAsset(
      NativeCodeAsset(
        package: 'sqlite3',
        name: 'sqlite3.dll',
        linkMode: DynamicLoadingBundled(),
        os: OS.windows,
        architecture: Architecture.x64,
        file: dllPath,
      ),
    );
  });
}