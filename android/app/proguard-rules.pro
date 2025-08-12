# ✅ Razorpay SDK - Keep all classes
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# ✅ Razorpay missing annotation fixes
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }

# ✅ Optional: Prevent Flutter from stripping critical classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
