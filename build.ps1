<#
.SYNOPSIS
    Builds (and with -Test, tests) one language profile of Corobs, or all of them.
.EXAMPLE
    ./build.ps1 -Profile Rust -Test
    ./build.ps1 -Profile All
    ./build.ps1 -Profile Vectors     # regenerate conformance/vectors.json from the C# reference
#>
param(
    [ValidateSet('Csharp', 'Python', 'Cpp', 'Java', 'Rust', 'TypeScript', 'Go', 'Swift', 'Julia', 'Vectors', 'All')]
    [string]$Profile = 'All',
    [switch]$Test
)
# Not 'Stop': Windows PowerShell 5.1 turns a tool's stderr progress (cargo, swift) into an error. Exit codes decide.
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

$onWindows = $env:OS -eq 'Windows_NT'

# MSVC, the Windows SDK and VS's bundled CMake live only in a Visual Studio developer environment.
function Use-VsDevEnv {
    if (-not $onWindows -or $env:VSCMD_VER) { return }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vs = & $vswhere -latest -version '[17.0,18.0)' -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'Visual Studio 2022 with the C++ workload is required.' }
    cmd /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
    }
}

# Swift 6.4 on Windows: the default build system drops the UCRT headers, so build natively against the Swift SDK.
function Use-SwiftEnv {
    if (-not $onWindows) { return }
    Use-VsDevEnv
    if (-not $env:SDKROOT) {
        $sdk = Get-ChildItem "$env:LOCALAPPDATA\Programs\Swift\Platforms\*\Windows.platform\Developer\SDKs\Windows.sdk" -Directory | Select-Object -Last 1
        if ($sdk) { $env:SDKROOT = $sdk.FullName + '\' }
    }
}
$swiftFlags = if ($onWindows) { @('--build-system', 'native') } else { @() }

function Step([string]$dir, [scriptblock]$buildCmd, [scriptblock]$testCmd) {
    Push-Location (Join-Path $root $dir)
    try {
        & $buildCmd; if ($LASTEXITCODE) { throw "$dir build failed ($LASTEXITCODE)" }
        if ($Test.IsPresent) { & $testCmd; if ($LASTEXITCODE) { throw "$dir tests failed ($LASTEXITCODE)" } }
    } finally { Pop-Location }
}

$profiles = [ordered]@{
    Vectors    = { Step 'Corobs.Csharp' { dotnet run --project Corobs.TestVectors -- $root } { } }
    Csharp     = { Step 'Corobs.Csharp' { dotnet build Corobs.slnx } { dotnet test Corobs.slnx --no-build } }
    Python     = { Step 'Corobs.Python' { python -m compileall -q src tests } { python -m pytest -q } }
    Cpp        = { Use-VsDevEnv; Step 'Corobs.Cpp' { cmake -S . -B build; if (!$LASTEXITCODE) { cmake --build build --config Release } } { ctest --test-dir build -C Release --output-on-failure } }
    Java       = { Step 'Corobs.Java' { mvn -q -DskipTests package } { mvn -q test } }
    Rust       = { Step 'Corobs.Rust' { cargo build --all-targets } { cargo test } }
    TypeScript = { Step 'Corobs.TypeScript' { npm ci; if (!$LASTEXITCODE) { npm run build } } { npm test } }
    Go         = { Step 'Corobs.Go' { go build ./...; if (!$LASTEXITCODE) { go vet ./... } } { go test ./... } }
    Swift      = { Use-SwiftEnv; Step 'Corobs.Swift' { swift build --build-tests @swiftFlags } { swift test @swiftFlags } }
    Julia      = { Step 'Corobs.Julia' { julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' } { julia --project=. -e 'using Pkg; Pkg.test()' } }
}

$run = if ($Profile -eq 'All') { $profiles.Keys | Where-Object { $_ -ne 'Vectors' } } else { @($Profile) }
foreach ($p in $run) { Write-Host "== $p" -ForegroundColor Cyan; & $profiles[$p] }
