-keepclassmembernames class com.btcc.app2.** { *; }
-keepclassmembernames class sq.flutter.tflite.** {*;}

# tflite_flutter references GpuDelegateFactory$Options, but the GPU API
# artifact is optional and not required when GPU delegates are unused.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# Select TF ops (Flex) — keep JNI entry points used by MainActivity.
-keep class org.tensorflow.lite.flex.** { *; }