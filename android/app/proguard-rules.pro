##########################################
# Flutter-specific rules
##########################################
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

##########################################
# Play Core and SplitCompat rules
##########################################
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-keep enum com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep interface com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }

##########################################
# Razorpay SDK rules
##########################################
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }

# Do not warn about missing classes inside Razorpay
-dontwarn com.razorpay.**

##########################################
# Google Pay classes (used by Razorpay)
##########################################
-keep class com.google.android.apps.nbu.paisa.inapp.client.** { *; }
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.**

##########################################
# Keep Proguard annotations
##########################################
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
-keepattributes *Annotation*

##########################################
# General safety rules
##########################################
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.*
-dontwarn kotlin.**

##########################################
# Suppress warnings for Play Core classes from missing_rules.txt
##########################################
-dontwarn com.google.android.play.core.appupdate.AppUpdateInfo
-dontwarn com.google.android.play.core.appupdate.AppUpdateManager
-dontwarn com.google.android.play.core.assetpacks.AssetLocation
-dontwarn com.google.android.play.core.assetpacks.AssetPackLocation
-dontwarn com.google.android.play.core.assetpacks.AssetPackManager
-dontwarn com.google.android.play.core.assetpacks.AssetPackState
-dontwarn com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
-dontwarn com.google.android.play.core.assetpacks.AssetPackStates
-dontwarn com.google.android.play.core.assetpacks.model.AssetPackErrorCode
-dontwarn com.google.android.play.core.assetpacks.model.AssetPackStatus
-dontwarn com.google.android.play.core.assetpacks.model.AssetPackStorageMethod
-dontwarn com.google.android.play.core.common.IntentSenderForResultStarter
-dontwarn com.google.android.play.core.install.InstallException
-dontwarn com.google.android.play.core.install.InstallState
-dontwarn com.google.android.play.core.install.InstallStateUpdatedListener
-dontwarn com.google.android.play.core.install.model.AppUpdateType
-dontwarn com.google.android.play.core.install.model.InstallErrorCode
-dontwarn com.google.android.play.core.install.model.InstallStatus
-dontwarn com.google.android.play.core.review.ReviewInfo
-dontwarn com.google.android.play.core.review.ReviewManager
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.splitinstall.model.SplitInstallErrorCode
-dontwarn com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
