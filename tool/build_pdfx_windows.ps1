$env:CMAKE_TLS_VERIFY="0"
$env:CMAKE_TLS_CAINFO=""
flutter clean
Remove-Item -Recurse -Force .\build\windows -ErrorAction SilentlyContinue
flutter pub get
cd .\core\medical_core\
cargo build
cd ..\..
flutter run -d windows