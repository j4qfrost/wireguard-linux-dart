import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import '../native/native_wireguard_library.dart' as native;

interface class WGKey {
  final Pointer<Uint8> pointer;
  static const int length = 32;
  static final int strLength = 44;

  static final NativeFinalizer _finalizer = NativeFinalizer(calloc.nativeFree);

  const WGKey(this.pointer);

  Uint8List get data => pointer.cast<Uint8>().asTypedList(length);

  @override
  String toString() {
    final Pointer<Char> str = malloc.allocate(strLength);
    native.wg_key_to_base64(str, pointer);

    final String res =
        String.fromCharCodes([for (int i = 0; i < strLength; i++) str[i]]);
    malloc.free(str);
    return res;
  }

  factory WGKey.fromString(String dartStr) {
    final Pointer<Char> str = calloc.allocate(strLength);
    for (int i = 0; i < strLength; i++) {
      str[i] = dartStr.codeUnitAt(i);
    }
    final Pointer<Uint8> p = calloc.allocate(length);
    if (p == nullptr) {
      throw OutOfMemoryError();
    }
    native.wg_key_from_base64(p, str);
    calloc.free(str);
    return WGKey(p);
  }

  void free() {
    calloc.free(pointer);
    _finalizer.detach(this);
  }
}

final class PrivateKey extends WGKey {
  const PrivateKey(Pointer<Uint8> pointer) : super(pointer);

  factory PrivateKey.fromString(String str) {
    return PrivateKey(WGKey.fromString(str).pointer);
  }

  factory PrivateKey.generate() {
    final Pointer<Uint8> p = calloc.allocate(sizeOf<Uint8>() * WGKey.length);
    native.wg_generate_private_key(p);
    return PrivateKey(p);
  }
}

final class PublicKey extends WGKey {
  const PublicKey(Pointer<Uint8> pointer) : super(pointer);

  factory PublicKey.fromString(String str) {
    return PublicKey(WGKey.fromString(str).pointer);
  }

  factory PublicKey.generate(Pointer<Uint8> privateKey) {
    final Pointer<Uint8> p = calloc.allocate(sizeOf<Uint8>() * WGKey.length);
    native.wg_generate_public_key(p, privateKey);
    return PublicKey(p);
  }
}
