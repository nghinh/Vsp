# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in the Android SDK tools proguard-defaults.txt file.

# Keep line numbers and file names for better crash reports
-keepattributes SourceFile,LineNumberTable

# Keep generic signatures for Kotlin
-keepattributes Signature

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
