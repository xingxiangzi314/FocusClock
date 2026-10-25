param(
    [string]$FlutterRoot = $env:FLUTTER_ROOT,
    [string]$SdkRoot = $env:ANDROID_HOME,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$BuildTools = '35.0.0',
    [string]$ReleaseDirectory = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
if (-not $FlutterRoot) { throw '请通过 -FlutterRoot 指定 Flutter SDK 目录。' }
if (-not $SdkRoot) { throw '请通过 -SdkRoot 指定 Android SDK 目录。' }
if (-not $JavaHome) { throw '请通过 -JavaHome 指定 JDK 17 或以上目录。' }
$flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
$java = Join-Path $JavaHome 'bin\java.exe'
$signer = Join-Path $SdkRoot "build-tools\$BuildTools\lib\apksigner.jar"
$zipalign = Join-Path $SdkRoot "build-tools\$BuildTools\zipalign.exe"
$key = Join-Path $PSScriptRoot 'signing\debug.keystore'
foreach ($required in @($flutter,$java,$signer,$zipalign,$key)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "缺少构建文件：$required" }
}
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:FLUTTER_ROOT = $FlutterRoot
$properties = 'flutter.sdk=' + $FlutterRoot.Replace('\','/') + "`nsdk.dir=" + $SdkRoot.Replace('\','/') + "`n"
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'android\local.properties'),$properties,[Text.UTF8Encoding]::new($false))
$versionLine = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pubspec.yaml') | Where-Object { $_ -match '^version:' } | Select-Object -First 1
if ($versionLine -notmatch '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') { throw 'pubspec.yaml 版本格式应为 x.y.z+构建号' }
$versionName = $Matches[1]
$releaseRoot = [IO.Path]::GetFullPath($ReleaseDirectory)
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
$apk = Join-Path $releaseRoot "拾光-$versionName.apk"
function Run-Checked { param([string]$Program,[string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "构建或验证失败，退出码 $LASTEXITCODE" }
}
Push-Location $PSScriptRoot
try {
    Run-Checked $flutter @('pub','get')
    Run-Checked $flutter @('build','apk','--release','--target-platform','android-arm,android-arm64','--no-pub')
    $built = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
    # Sign a fresh aligned build; never generate or replace the existing upgrade key.
    Run-Checked $java @('-jar',$signer,'sign','--ks',$key,'--ks-key-alias','androiddebugkey','--ks-pass','pass:android','--key-pass','pass:android','--v4-signing-enabled','true','--out',$apk,$built)
    Run-Checked $java @('-jar',$signer,'verify','--verbose','--print-certs','--v4-signature-file',($apk + '.idsig'),$apk)
    Run-Checked $zipalign @('-c','-P','16','4',$apk)
    if (-not (Test-Path -LiteralPath ($apk + '.idsig'))) { throw '未生成对应的 idsig，旧文件已保留。' }
    foreach ($old in Get-ChildItem -LiteralPath $releaseRoot -File) {
        if ($old.Name -match '^拾光-\d+\.\d+\.\d+\.apk(\.idsig)?$' -and $old.FullName -ne $apk -and $old.FullName -ne ($apk + '.idsig')) {
            $resolved = [IO.Path]::GetFullPath($old.FullName)
            if ([IO.Path]::GetDirectoryName($resolved) -ne $releaseRoot) { throw '清理文件不在发布目录内' }
            Remove-Item -LiteralPath $resolved
        }
    }
    Write-Output "APK 已生成：$apk"
    Get-FileHash -LiteralPath $apk -Algorithm SHA256
} finally { Pop-Location }
