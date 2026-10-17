# R8 rules for the HOMIZI release build.
# The Flutter Gradle plugin also merges the engine consumer rules.

# The Flutter embedding references Play Core classes that are optional.
-dontwarn com.google.android.play.core.**

# sentry_flutter is on the classpath. It does not send events unless a DSN
# was compiled in. Keep it so R8 does not strip the init path.
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Stack traces from the Android side stay readable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn javax.annotation.**
