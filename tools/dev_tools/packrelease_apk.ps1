.\tool\build_medical_core_android.ps1
flutter build apk

# 重命名并移动（示例仅重命名 arm64）
Rename-Item -Path ".\build\app\outputs\flutter-apk\app-release.apk" -NewName "MedicalReader_android_arm64-v8a_v1.0.0.apk"