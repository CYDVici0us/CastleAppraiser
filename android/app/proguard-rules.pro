-keepclassmembernames class com.btcc.app.** { *; }
-keepclassmembernames class sq.flutter.tflite.** {*;}

# tflite_flutter references GpuDelegateFactory$Options, but the GPU API
# artifact is optional and not required when GPU delegates are unused.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options