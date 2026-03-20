import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class VoiceCodec {
  static DynamicLibrary? _lib;

  static DynamicLibrary get _instance {
    _lib ??= () {
      if (Platform.isAndroid) {
        return DynamicLibrary.open('libvoice_codec.so');
      } else if (Platform.isIOS) {
        return DynamicLibrary.process();
      } else if (Platform.isWindows) {
        return DynamicLibrary.open('voice_codec.dll');
      } else if (Platform.isLinux) {
        return DynamicLibrary.open('libvoice_codec.so');
      } else if (Platform.isMacOS) {
        return DynamicLibrary.open('libvoice_codec.dylib');
      }
      throw UnsupportedError('Platform non supportée pour VoiceCodec');
    }();
    return _lib!;
  }

  // C fonctions attendues
  static late final int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
  _compressNative = _instance
      .lookup<
        NativeFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32)
        >
      >('compress_audio')
      .asFunction();

  static late final int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
  _decompressNative = _instance
      .lookup<
        NativeFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32)
        >
      >('decompress_audio')
      .asFunction();

  static Uint8List compress(Uint8List input) {
    final outCap = input.length * 2 + 16;
    final inPtr = malloc<Uint8>(input.length);
    final outPtr = malloc<Uint8>(outCap);

    final inList = inPtr.asTypedList(input.length);
    inList.setAll(0, input);

    final compressedLen = _compressNative(inPtr, input.length, outPtr, outCap);

    if (compressedLen <= 0) {
      malloc.free(inPtr);
      malloc.free(outPtr);
      throw Exception('Compression audio échouée');
    }

    final result = outPtr.asTypedList(compressedLen).toList(growable: false);
    malloc.free(inPtr);
    malloc.free(outPtr);
    return Uint8List.fromList(result);
  }

  static Uint8List decompress(Uint8List input) {
    final outCap = input.length * 10 + 256;
    final inPtr = malloc<Uint8>(input.length);
    final outPtr = malloc<Uint8>(outCap);

    final inList = inPtr.asTypedList(input.length);
    inList.setAll(0, input);

    final decompressedLen = _decompressNative(
      inPtr,
      input.length,
      outPtr,
      outCap,
    );

    if (decompressedLen <= 0) {
      malloc.free(inPtr);
      malloc.free(outPtr);
      throw Exception('Décompression audio échouée');
    }

    final result = outPtr.asTypedList(decompressedLen).toList(growable: false);
    malloc.free(inPtr);
    malloc.free(outPtr);
    return Uint8List.fromList(result);
  }

  // Fallback sans C++ si pas chargé
  static Uint8List compressDart(Uint8List input) {
    // RLE simple (pas optimal, mais démontre la gestion)
    final buffer = BytesBuilder();
    for (int i = 0; i < input.length;) {
      int value = input[i];
      int count = 1;
      while (i + count < input.length &&
          input[i + count] == value &&
          count < 255)
        count++;
      buffer.add([count, value]);
      i += count;
    }
    return buffer.toBytes();
  }

  static Uint8List decompressDart(Uint8List input) {
    final buffer = BytesBuilder();
    for (int i = 0; i + 1 < input.length; i += 2) {
      final count = input[i];
      final value = input[i + 1];
      buffer.add(List.filled(count, value));
    }
    return buffer.toBytes();
  }
}
