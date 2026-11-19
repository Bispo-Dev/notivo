# -Release: gera os APKs assinados em app\build\release\ (notivo.apk arm64 e notivo-32bits.apk, com .sha256) sem instalar.
param([switch]$Release)
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
    if ($Release) {
        if (!(Test-Path -LiteralPath (Join-Path $notivoRoot 'app\android\key.properties'))) {
            throw 'Sem app\android\key.properties: o APK sairia assinado com a chave de debug.'
        }
        $notivoOut = New-Item -ItemType Directory -Force (Join-Path $notivoRoot 'app\build\release')
        # One APK per build instead of --split-per-abi, which would rewrite versionCode per ABI.
        # notivo.apk (arm64) is what the site links; notivo-32bits.apk is only for old 32-bit phones.
        foreach ($notivoTarget in @(@('android-arm64', 'notivo.apk'), @('android-arm', 'notivo-32bits.apk'))) {
            & $notivoFlutter build apk --release --target-platform $notivoTarget[0]
            if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar o APK ($($notivoTarget[0]))." }
            $notivoRelease = Join-Path $notivoOut $notivoTarget[1]
            Copy-Item (Join-Path $notivoRoot 'app\build\app\outputs\flutter-apk\app-release.apk') $notivoRelease -Force
            $notivoHash = (Get-FileHash $notivoRelease -Algorithm SHA256).Hash.ToLower()
            Set-Content -Encoding ascii "$notivoRelease.sha256" "$notivoHash  $($notivoTarget[1])"
            Write-Host "Pronto: $notivoRelease ($([math]::Round((Get-Item $notivoRelease).Length / 1MB, 1)) MB)"
        }
        return
    }
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
