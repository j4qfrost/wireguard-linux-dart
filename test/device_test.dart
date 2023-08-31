import 'package:wireguard_linux/src/device.dart';
import 'package:test/test.dart';
import 'package:wireguard_linux/src/wg_key.dart';
import 'package:http/http.dart' as http;

void main() {
  const List<String> deviceNames = ['foobar', 'foobar1'];

  tearDownAll(() {
    for (String name in deviceNames) {
      Device.deleteDevice(name);
    }
  });

  test('Add client device', () {
    final String name = deviceNames[0];
    final PrivateKey privateKey = PrivateKey.generate();
    final ClientDevice device = ClientDevice.addDevice(name, privateKey);

    expect(device.name.codeUnits, name.codeUnits);
    expect(device.privateKey, privateKey.data);
  });

  test('Connect to server', () async {
    final String name = deviceNames[1];
    final PrivateKey privateKey = PrivateKey.generate();
    final PublicKey publicKey = PublicKey.generate(privateKey.address);
    final ClientDevice device = ClientDevice.addDevice(name, privateKey);

    final String before =
        (await http.get(Uri.parse('https://api.ipify.org?format=json'))).body;
    device.connect(publicKey.address, '195.181.162.163', 51820);
    // print(device.firstPeer.publicKey);
    // print(device.firstPeer.presharedKey);
    // print(device.lastPeer.publicKey);
    // print(device.lastPeer.presharedKey);
    // expect(device.lastPeer.publicKey, publicKey.data!);
    // device.setDevice();
    Device.listDevices();
    print(device.firstPeer.publicKey);
    final String after =
        (await http.get(Uri.parse('https://api.ipify.org?format=json'))).body;
  });
}
