$env:JAVA_HOME = "C:\java17"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:PATH = "C:\java17\bin;$env:PATH"

Set-Location -Path "C:\Users\ephiewae\iswara_app"
& "C:\Users\ephiewae\flutter\bin\flutter.bat" build apk --release
