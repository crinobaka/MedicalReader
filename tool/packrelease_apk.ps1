.\tool\build_medical_core_android.ps1
flutter build apk --release

# 重命名并移动（示例仅重命名 arm64）
Copy-Item -Path ".\build\app\outputs\flutter-apk\app-release.apk" -Destination ".\"

Rename-Item -Path ".\app-release.apk" -NewName ".\MedicalReader_android_arm64-v8a_v3.0.0.alpha.apk"