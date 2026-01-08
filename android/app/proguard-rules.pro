# Keep TensorFlow Lite classes (prevent R8 from stripping them)
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.**
