$env:CMAKE_TLS_VERIFY="0"
$env:CMAKE_TLS_CAINFO=""
flutter clean
Remove-Item -Recurse -Force .\build\windows -ErrorAction SilentlyContinue
flutter pub get
cd .\core\medical_core\
cargo build
cd ..\..
flutter bulid windows
Copy-Item -Path "D:\workshop\application\MedicalReader\core\medical_core\target\debug\medical_core.dll" -Destination "D:\workshop\application\MedicalReader\build\windows\x64\runner\Release\"
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "MedicalReader_windows_x64_v1.0.0.zip" -Force
