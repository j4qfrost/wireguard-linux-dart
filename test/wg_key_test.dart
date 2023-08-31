import 'dart:convert';

import 'package:wireguard_linux/src/wg_key.dart';
import 'package:test/test.dart';

void main() {
  test('Generate keys', () {
    final PrivateKey privateKey = PrivateKey.generate();
    final PublicKey publicKey = PublicKey.generate(privateKey.address);

    expect(privateKey.length, publicKey.length);
    publicKey.free();
    expect(publicKey.length, 0);
    expect(privateKey.toString(), base64Encode(privateKey.data!));
    expect(PrivateKey.fromString(privateKey.toString()).data, privateKey.data!);
    privateKey.free();
  });
}
