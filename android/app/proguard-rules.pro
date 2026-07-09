# These are optional runtime integrations pulled in transitively by Play
# Services / document-scanner libraries (Huawei Mobile Services fallback,
# Cronet, Conscrypt/BouncyCastle SSL providers). This app never ships HMS or
# Cronet, so R8 can safely ignore them instead of failing the build.
-dontwarn com.huawei.**
-dontwarn com.android.org.conscrypt.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.chromium.net.**
