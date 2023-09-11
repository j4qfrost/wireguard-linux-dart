import 'dart:io';

import 'package:wireguard_linux/src/device.dart';
import 'package:test/test.dart';
import 'package:wireguard_linux/src/wg_key.dart';
import 'package:http/http.dart' as http;

void main() {
  const List<String> deviceNames = ['foobar', 'foobar1'];

  tearDownAll(() {
    for (String name in deviceNames) {
      try {
        Device.deleteDevice(name);
      } on PathNotFoundException catch (e) {
        print(e);
      }
    }
  });

  test('Connect to server', () async {
    final String name = deviceNames[1];
    final PrivateKey privateKey = PrivateKey.fromString('');
    final PublicKey publicKey = PublicKey.fromString('');
    const String dns = '';
    const String addr = '';
    final ClientDevice device =
        ClientDevice.addDevice(name, privateKey, 51820, addr: addr, dns: dns);

    final String before =
        (await http.get(Uri.parse('https://api.ipify.org'))).body;
    device.connect('', 51820, publicKey, gateway: '172.17.0.1', device: 'eth0');

    final String after =
        (await http.get(Uri.parse('https://api.ipify.org'))).body;

    expect(after, isNot(before));
  });
}
