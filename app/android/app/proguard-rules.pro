# Google ML KMit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Tensorflow Lite
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Amplify
-keep class com.amplifyframework.** { *; }
-dontwarn com.amplifyframework.**

# AWS Sdk
-keep class com.amazonaws.** { *; }
-dontwarn com.amazonaws.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Camera
-keep class io.flutter.plugins.camera.** { *; }

# Flutter plugin constraint
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }