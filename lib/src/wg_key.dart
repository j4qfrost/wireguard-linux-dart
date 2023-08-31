import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:typed_data';

import '../native/native_wireguard_library.dart' as native;

class _WGKey {
  int address;
  static const int _length = 32;
  static final int _strLength = (sizeOf<UnsignedChar>() * _length + 2) ~/ 3 * 4;

  final Uint8List _data;
  static final NativeFinalizer _finalizer = NativeFinalizer(malloc.nativeFree);

  int get length => (address == 0) ? 0 : _data.length;
  Uint8List? get data => (address == 0) ? null : _data;

  _WGKey(this.address, this._data);

  @override
  String toString() {
    final Pointer<Char> str = malloc.allocate(_strLength);
    native.key_to_string(Pointer.fromAddress(address), str);

    final String res = String.fromCharCodes(
        [for (int i = 0; i < _strLength; i++) str.elementAt(i).value]);
    malloc.free(str);
    return res;
  }

  factory _WGKey.fromString(String dartStr) {
    Pointer<Char> str = malloc.allocate(_strLength);
    for (int i = 0; i < _strLength; i++) {
      str[i] = dartStr.codeUnitAt(i);
    }
    Pointer<Uint8> p = malloc.allocate(_length);
    if (p == nullptr) {
      throw OutOfMemoryError();
    }
    native.key_from_string(str, p);
    malloc.free(str);
    return _WGKey(p.address, p.asTypedList(_length));
  }

  void free() {
    malloc.free(Pointer.fromAddress(address));
    address = 0;
    _finalizer.detach(this);
  }
}

final class PrivateKey extends _WGKey {
  PrivateKey(int newAddress, Uint8List data) : super(newAddress, data);

  factory PrivateKey.fromString(String str) {
    _WGKey key = _WGKey.fromString(str);
    return PrivateKey(key.address, key.data!);
  }

  factory PrivateKey.generate() {
    final Pointer<UnsignedChar> p =
        malloc.allocate(sizeOf<UnsignedChar>() * _WGKey._length);
    native.generate_private_key(p);

    return PrivateKey(p.address, p.cast<Uint8>().asTypedList(_WGKey._length));
  }
}

final class PublicKey extends _WGKey {
  PublicKey(int newAddress, Uint8List data) : super(newAddress, data);

  factory PublicKey.fromString(String str) {
    _WGKey key = _WGKey.fromString(str);
    return PublicKey(key.address, key.data!);
  }

  factory PublicKey.generate(int address) {
    final Pointer<UnsignedChar> privateKey = Pointer.fromAddress(address);
    final Pointer<UnsignedChar> p =
        malloc.allocate(sizeOf<UnsignedChar>() * _WGKey._length);
    native.generate_public_key(privateKey, p);
    return PublicKey(p.address, p.cast<Uint8>().asTypedList(_WGKey._length));
  }
}
