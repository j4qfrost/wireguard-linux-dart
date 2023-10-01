import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:wireguard_linux/src/wg_key.dart';

import '../native/native_wireguard_library.dart' as native;

abstract interface class Device {
  final Pointer<native.wg_device> _inner;

  String get name => String.fromCharCodes(
      _inner.cast<Uint8>().asTypedList(16).takeWhile((b) => b != 0));

  int get idx => _inner.ref.ifindex;

  int get flags => _inner.ref.flags;

  late final PublicKey publicKey;

  late final PrivateKey privateKey;

  int get fwmark => _inner.ref.fwmark;

  int get listenPort => _inner.ref.listen_port;

  Peer? get firstPeer =>
      _inner.ref.first_peer.address == 0 ? null : Peer(_inner.ref.first_peer);
  Peer? get lastPeer =>
      _inner.ref.last_peer.address == 0 ? null : Peer(_inner.ref.last_peer);

  Device(this._inner) {
    privateKey = PrivateKey(_inner
        .cast<Uint8>()
        .elementAt(16 + sizeOf<Uint32>() + sizeOf<Int32>() + 32));

    publicKey = PublicKey(_inner
        .cast<Uint8>()
        .elementAt(16 + sizeOf<Uint32>() + sizeOf<Int32>()));

    if (native.wg_set_device(_inner) < 0) {
      throw 'Unable to set device';
    }
  }

  static final NativeFinalizer _finalizer = NativeFinalizer(calloc.nativeFree);

  void free() {
    final Pointer<Uint8> p = malloc.allocate<Uint8>(16);

    for (int i = 0; i < 16; i++) {
      p[i] = _inner.cast<Uint8>().elementAt(i).value;
    }
    native.wg_free_device(_inner);
    calloc.free(_inner);
    malloc.free(p);

    _finalizer.detach(this);
  }

  static void deleteDevice(String name) {
    final Pointer<Uint8> str = malloc.allocate(name.length);
    for (int i = 0; i < name.length; i++) {
      str[i] = name.codeUnitAt(i);
    }
    if (native.wg_del_device(str.cast()) != 0) {
      malloc.free(str);
      throw PathNotFoundException(name, OSError('Device does not exist'));
    }
    malloc.free(str);
  }
}

class ClientDevice extends Device {
  ClientDevice(Pointer<native.wg_device> device) : super(device);

  factory ClientDevice.addDevice(
    String name,
    PrivateKey private,
    int port, {
    String? addr,
    String? dns,
  }) {
    final Pointer<native.wg_device> device =
        calloc.allocate(sizeOf<native.wg_device>());

    device.ref.flags = native.wg_device_flags.WGDEVICE_HAS_PRIVATE_KEY |
        native.wg_device_flags.WGDEVICE_HAS_FWMARK;
    device.ref.fwmark = port;

    final Pointer<Char> str = malloc.allocate(16);
    for (int i = 0; i < name.length; i++) {
      device.ref.name[i] = str[i] = name.codeUnitAt(i);
    }

    final PublicKey pub = PublicKey.generate(private.pointer);

    for (int i = 0; i < WGKey.length; i++) {
      device.ref.private_key[i] = private.pointer[i];
      device.ref.public_key[i] = pub.pointer[i];
    }

    if (native.wg_add_device(str) < 0) {
      throw 'Unable to add device';
    }

    malloc.free(str);

    if (addr != null) {
      Process.runSync('ip', ['-4', 'a', 'add', addr, 'dev', name]);
    }

    Process.runSync('ip', ['link', 'set', 'mtu', '65455', 'up', 'dev', name]);

    if (dns != null) {
      final Completer c = Completer();
      c.complete(Process.start(
        'resolvconf',
        [
          '-a',
          name,
          '-m0',
          '-x',
        ],
      ).then((Process process) async {
        process.stdin.writeln('nameserver $dns');
        await process.stdin.close();
        return process;
      }));
    }

    return ClientDevice(device);
  }

  factory ClientDevice.getDevice(String name) {
    final Pointer<Uint8> str = calloc.allocate(name.length);
    for (int i = 0; i < name.length; i++) {
      str[i] = name.codeUnitAt(i);
    }
    final Pointer<Pointer<native.wg_device>> devicePtr =
        calloc.allocate(sizeOf<Pointer<native.wg_device>>());
    native.wg_get_device(devicePtr, str.cast<Char>());
    calloc.free(str);
    return ClientDevice(devicePtr.value);
  }

  void addPeer(PublicKey key, String ip, int port) {
    assert(key != publicKey);
    final Peer peer = Peer.create(port, ip, key);

    if (_inner.ref.last_peer.address == 0) {
      _inner.ref.first_peer = peer._inner;
      _inner.ref.last_peer = peer._inner;
    } else {
      _inner.ref.last_peer.ref.next_peer = peer._inner;
      _inner.ref.last_peer = peer._inner;
    }

    final int ret = native.wg_set_device(_inner);

    if (ret != 0) {
      throw ret;
    }
  }

  void connect(String ip, int port, PublicKey key,
      {String? gateway, String? device}) {
    addPeer(key, ip, port);
    if (gateway != null && device != null) {
      Process.runSync('ip', ['route', 'del', 'default']);
      Process.runSync('ip', ['route', 'add', 'default', 'dev', name]);

      final ProcessResult res = Process.runSync(
          'ip', ['route', 'add', ip, 'via', gateway, 'dev', device]);
      if (res.exitCode != 0) {
        throw res.stderr;
      }
    } else {
      route();
    }
  }

  void route([String allowedIp = '0.0.0.0/0']) {
    Process.runSync('ip', [
      '-4',
      'route',
      'add',
      allowedIp,
      'dev',
      name,
    ]);
  }
}

// class ServerDevice extends Device {
//   ServerDevice(Pointer<native.wg_device> device) : super(device);

//   factory ServerDevice.addDevice(String name, int port, PrivateKey private) {
//     final Pointer<Uint8> str = calloc.allocate(name.length);
//     for (int i = 0; i < name.length; i++) {
//       str[i] = name.codeUnitAt(i);
//     }
//     native.add_server_device(str.cast<Char>(), port, private.pointer.cast());

//     final Pointer<Pointer<native.wg_device>> devicePtr =
//         calloc.allocate(sizeOf<Pointer<native.wg_device>>());
//     native.wg_get_device(devicePtr, str.cast<Char>());
//     return ServerDevice(devicePtr.value);
//   }
// }

class Peer {
  final Pointer<native.wg_peer> _inner;
  static final NativeFinalizer _finalizer = NativeFinalizer(calloc.nativeFree);

  int get flags => _inner.ref.flags;
  PublicKey get publicKey =>
      PublicKey(_inner.cast<Uint8>().elementAt(sizeOf<Int32>()));

  PrivateKey get presharedKey =>
      PrivateKey(_inner.cast<Uint8>().elementAt(sizeOf<Int32>() + 32));

  native.wg_endpoint get endpoint => _inner.ref.endpoint;

  Peer get next => Peer(_inner.ref.next_peer);

  int get address => _inner.address;

  const Peer(this._inner);

  void free() {
    calloc.free(_inner);

    _finalizer.detach(this);
  }

  factory Peer.create(int port, String ip, PublicKey pub) {
    final Pointer<native.wg_endpoint> destAddr =
        calloc.allocate(sizeOf<native.wg_endpoint>());

    destAddr.ref.addr4.sin_family = 2; // AF_INET
    destAddr.ref.addr4.sin_port = port << 8 | port >> 8;
    final Uint8List raw = InternetAddress(ip).rawAddress;
    destAddr.ref.addr4.sin_addr.s_addr =
        raw[3] << 24 | raw[2] << 16 | raw[1] << 8 | raw[0];

    final Pointer<native.wg_allowedip> allowedIp =
        calloc.allocate(sizeOf<native.wg_allowedip>());
    allowedIp.ref.family = 2; // AF_INET
    // allowedIp.ref.cidr = 1;

    final Pointer<native.wg_peer> peer =
        calloc.allocate(sizeOf<native.wg_peer>());

    peer.ref.flags = native.wg_peer_flags.WGPEER_HAS_PUBLIC_KEY |
        native.wg_peer_flags.WGPEER_REPLACE_ALLOWEDIPS |
        native.wg_peer_flags.WGPEER_HAS_PERSISTENT_KEEPALIVE_INTERVAL;

    peer.ref.endpoint = destAddr.ref;
    peer.ref.first_allowedip = allowedIp;
    peer.ref.last_allowedip = allowedIp;
    peer.ref.persistent_keepalive_interval = 60;

    for (int i = 0; i < 32; i++) {
      peer.ref.public_key[i] = pub.pointer[i];
    }

    return Peer(peer);
  }
}
