import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:wireguard_linux/src/wg_key.dart';

import '../native/native_wireguard_library.dart' as native;

enum DeviceFlags {
  replacePeers(1),
  hasPrivateKey(2),
  hasPublicKey(4),
  hasListenPort(8),
  hasFwmark(16);

  const DeviceFlags(this.val);

  final int val;
}

abstract class Device {
  final Pointer<Pointer<native.wg_device>> _inner;

  String get name => String.fromCharCodes(
      _inner.value.cast<Uint8>().asTypedList(16).takeWhile((b) => b != 0));

  int get idx => _inner.value.ref.ifindex;

  int get flags => _inner.value.ref.flags;

  Uint8List get publicKey => _inner.value
      .cast<Uint8>()
      .elementAt(sizeOf<Char>() * 16 + sizeOf<Uint32>() + sizeOf<Int32>())
      .asTypedList(32);

  Uint8List get privateKey => _inner.value
      .cast<Uint8>()
      .elementAt(sizeOf<Char>() * 16 +
          sizeOf<Uint32>() +
          sizeOf<Int32>() +
          sizeOf<Uint8>() * 32)
      .asTypedList(32);

  int get fwmark => _inner.value.ref.fwmark;

  int get listenPort => _inner.value.ref.listen_port;

  Peer get firstPeer => Peer(_inner.value.ref.first_peer);

  Peer get lastPeer => Peer(_inner.value.ref.last_peer);

  const Device(this._inner);

  static void listDevices() {
    native.list_devices();
  }

  static final NativeFinalizer _finalizer = NativeFinalizer(malloc.nativeFree);

  void free() {
    final Pointer<Uint8> p = malloc.allocate<Uint8>(16);

    for (int i = 0; i < 16; i++) {
      p[i] = _inner.value.cast<Uint8>().elementAt(i).value;
    }
    native.wg_free_device(_inner.value);
    malloc.free(_inner);
    malloc.free(p);

    _finalizer.detach(this);
  }

  static void deleteDevice(String name) {
    final Pointer<Uint8> str = malloc.allocate(name.length);
    for (int i = 0; i < name.length; i++) {
      str[i] = name.codeUnitAt(i);
    }
    if (native.wg_del_device(str.cast()) < 0) {
      throw PathNotFoundException(name, OSError('Device does not exist'));
    }
  }
}

class ClientDevice extends Device {
  ClientDevice(Pointer<Pointer<native.wg_device>> device) : super(device);

  factory ClientDevice.addDevice(String name, PrivateKey private) {
    final Pointer<Uint8> str = malloc.allocate(name.length);
    for (int i = 0; i < name.length; i++) {
      str[i] = name.codeUnitAt(i);
    }
    native.add_client_device(
        str.cast<Char>(), Pointer.fromAddress(private.address));

    final Pointer<Pointer<native.wg_device>> devicePtr =
        malloc.allocate(sizeOf<Pointer<native.wg_device>>());
    native.wg_get_device(devicePtr, str.cast<Char>());
    return ClientDevice(devicePtr);
  }

  void setDevice() {
    if (native.wg_set_device(_inner.value) < 0) {
      throw PathNotFoundException(name, OSError('Unable to set device'));
    }
  }

  void connect(int keyAddr, String ip, int port) {
    final Pointer<Uint8> nameStr = malloc.allocate(name.length);
    for (int i = 0; i < name.length; i++) {
      nameStr[i] = name.codeUnitAt(i);
    }
    final Pointer<Uint8> ipStr = malloc.allocate(ip.length);
    for (int i = 0; i < ip.length; i++) {
      ipStr[i] = ip.codeUnitAt(i);
    }

    native.add_server_peer(nameStr.cast<Char>(), Pointer.fromAddress(keyAddr),
        ipStr.cast<Char>(), port);
  }
}

class ServerDevice extends Device {
  ServerDevice(Pointer<Pointer<native.wg_device>> device) : super(device);

  factory ServerDevice.addDevice(String name, int port, PrivateKey private) {
    final Pointer<Uint8> str = malloc.allocate(name.length);
    for (int i = 0; i < name.length; i++) {
      str[i] = name.codeUnitAt(i);
    }
    native.add_server_device(
        str.cast<Char>(), port, Pointer.fromAddress(private.address));

    final Pointer<Pointer<native.wg_device>> devicePtr =
        malloc.allocate(sizeOf<Pointer<native.wg_device>>());
    native.wg_get_device(devicePtr, str.cast<Char>());
    return ServerDevice(devicePtr);
  }
}

class Peer {
  final Pointer<native.wg_peer> _inner;

  int get flags => _inner.cast<Int32>().value;

  Uint8List get publicKey =>
      _inner.cast<Uint8>().elementAt(sizeOf<Int32>()).asTypedList(32);

  Uint8List get presharedKey => _inner
      .cast<Uint8>()
      .elementAt(sizeOf<Int32>() + sizeOf<Uint8>() * 32)
      .asTypedList(32);

  const Peer(this._inner);
}
