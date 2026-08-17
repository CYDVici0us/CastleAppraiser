import 'dart:ffi';
import 'dart:io';

import 'package:btcc/src/app/app_identity.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter/src/bindings/tensorflow_lite_bindings_generated.dart';

/// Flex (Select TF ops) delegate owned by Android Java / MainActivity.
///
/// Our scoring model contains FlexMul etc. The old app linked
/// `tensorflow-lite-select-tf-ops`; tflite_flutter's C API does not load Flex
/// automatically, so we borrow the native handle from [FlexDelegate].
class BorrowedFlexDelegate implements Delegate {
  BorrowedFlexDelegate(int nativeHandle)
      : base = Pointer<TfLiteDelegate>.fromAddress(nativeHandle);

  @override
  final Pointer<TfLiteDelegate> base;

  @override
  void delete() {
    // Lifetime owned by MainActivity's FlexDelegate instance.
  }
}

const _channel = MethodChannel(AppIdentity.tfliteChannel);

/// Returns a Flex delegate on Android, or null on other platforms / failure.
Future<Delegate?> acquireAndroidFlexDelegate() async {
  if (!Platform.isAndroid) return null;
  try {
    final handle = await _channel.invokeMethod<int>('getFlexDelegateHandle');
    if (handle == null || handle == 0) return null;
    return BorrowedFlexDelegate(handle);
  } catch (_) {
    return null;
  }
}
