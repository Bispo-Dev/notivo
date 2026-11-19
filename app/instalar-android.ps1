$ErrorActionPreference = 'Stop'
# The script lives in app/; the local toolchain (.tooling) stays at the repo root.
$notivoRoot = Split-Path -Parent $PSScriptRoot
$notivoTooling = Join-Path $notivoRoot '.tooling'
$env:JAVA_HOME = Join-Path $notivoTooling 'jdk'
$env:ANDROID_HOME = Join-Path $notivoTooling 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $notivoTooling 'android-user'
$env:GRADLE_USER_HOME = Join-Path $notivoTooling 'gradle-cache'
$env:PUB_CACHE = Join-Path $notivoTooling 'pub-cache'
$env:APPDATA = Join-Path $notivoTooling 'local-appdata\Roaming'
$env:LOCALAPPDATA = Join-Path $notivoTooling 'local-appdata'
$env:JAVA_TOOL_OPTIONS = "-Duser.home=$env:ANDROID_USER_HOME"
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"
New-Item -ItemType Directory -Force $env:ANDROID_USER_HOME,$env:APPDATA | Out-Null
foreach ($notivoProxy in 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY') {
    if ([Environment]::GetEnvironmentVariable($notivoProxy) -eq 'http://127.0.0.1:9') {
        Remove-Item "Env:$notivoProxy"
    }
}
$notivoFlutter = Join-Path $notivoTooling 'flutter\bin\flutter.bat'
$notivoAdb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
foreach ($notivoTool in $notivoFlutter,$notivoAdb) {
    if (!(Test-Path -LiteralPath $notivoTool)) { throw "Ferramenta ausente: $notivoTool" }
}
Push-Location (Join-Path $notivoRoot 'app')
try {
    & $notivoFlutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao resolver dependências.' }
    & $notivoFlutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o APK.' }
    $notivoApk = Join-Path $notivoRoot 'app\build\app\outputs\flutter-apk\app-debug.apk'
    if (!(Test-Path -LiteralPath $notivoApk)) { throw "APK não encontrado: $notivoApk" }
    & $notivoAdb -s RQCX408NK7H install -r $notivoApk
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar no celular.' }
    & $notivoAdb -s RQCX408NK7H shell am start -n com.notivo.app/.MainActivity
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao abrir o Notivo.' }
} finally {
    Pop-Location
}
