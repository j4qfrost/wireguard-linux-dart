// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file in
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import 'package:ffigen/ffigen.dart' as ffigen;

const String packageName = 'wireguard_linux';
void main(List<String> args) async {
  final BuildConfig buildConfig = await BuildConfig.fromArgs(args);

  final ffigen.Config ffiConfig = ffigen.Config.fromFile(
      File.fromUri(buildConfig.packageRoot.resolve('ffigen.yaml')));
  final ffigen.Library ffiLib = ffigen.parse(ffiConfig);
  ffiLib.generateFile(File.fromUri(Uri.parse(ffiConfig.output)));

  final BuildOutput buildOutput = BuildOutput();

  final CBuilder cbuilder = CBuilder.library(
    name: packageName,
    assetId: 'package:$packageName/native/native_wireguard_library.dart',
    sources: [
      'src/wireguard.c',
    ],
    pic: Platform.isLinux,
  );
  await cbuilder.run(
    buildConfig: buildConfig,
    buildOutput: buildOutput,
    logger: Logger('')..onRecord.listen((record) => print(record.message)),
  );

  await buildOutput.writeToFile(outDir: buildConfig.outDir);
}
