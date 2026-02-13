# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# libtailscale (Go mobile binding via gomobile)
-keep class libtailscale.** { *; }
-keep interface libtailscale.** { *; }
-dontwarn libtailscale.**

# Go mobile runtime
-keep class go.** { *; }
-dontwarn go.**

# TailscalePlugin & VPN service (implements Go interfaces)
-keep class com.vibeterm.vibeterm.TailscalePlugin { *; }
-keep class com.vibeterm.vibeterm.TailscaleVpnService { *; }
-keep class com.vibeterm.vibeterm.VPNServiceBuilderWrapper { *; }
-keep class com.vibeterm.vibeterm.ParcelFileDescriptorWrapper { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# AndroidX Security (EncryptedSharedPreferences)
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# AndroidX core
-keep class androidx.core.app.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions
