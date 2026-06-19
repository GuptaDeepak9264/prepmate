# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Firestore / gRPC
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Dio / OkHttp (used by Cloudinary service)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Cloudinary / Dio
-keep class com.squareup.** { *; }

# Keep all data classes (Entities) — needed for Firestore deserialization
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName *;
}
-keep class * implements java.io.Serializable { *; }

# Prevent stripping of Dart entry points
-keep class com.example.prepmate_ai.** { *; }

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**
