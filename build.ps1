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
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Step([string]$dir, [scriptblock]$build, [scriptblock]$test) {
    Push-Location (Join-Path $root $dir)
    try {
        & $build; if ($LASTEXITCODE) { throw "$dir build failed ($LASTEXITCODE)" }
        if ($Test) { & $test; if ($LASTEXITCODE) { throw "$dir tests failed ($LASTEXITCODE)" } }
    } finally { Pop-Location }
}

$profiles = [ordered]@{
    Vectors    = { Step 'Corobs.Csharp' { dotnet run --project Corobs.TestVectors -- $root } { } }
    Csharp     = { Step 'Corobs.Csharp' { dotnet build Corobs.slnx } { dotnet test Corobs.slnx --no-build } }
    Python     = { Step 'Corobs.Python' { python -m compileall -q src tests } { python -m pytest -q } }
    Cpp        = { Step 'Corobs.Cpp' { cmake -S . -B build; if (!$LASTEXITCODE) { cmake --build build --config Release } } { ctest --test-dir build -C Release --output-on-failure } }
    Java       = { Step 'Corobs.Java' { mvn -q -DskipTests package } { mvn -q test } }
    Rust       = { Step 'Corobs.Rust' { cargo build --all-targets } { cargo test } }
    TypeScript = { Step 'Corobs.TypeScript' { npm ci; if (!$LASTEXITCODE) { npm run build } } { npm test } }
    Go         = { Step 'Corobs.Go' { go build ./...; if (!$LASTEXITCODE) { go vet ./... } } { go test ./... } }
    Swift      = { Step 'Corobs.Swift' { swift build --build-tests } { swift test } }
    Julia      = { Step 'Corobs.Julia' { julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' } { julia --project=. -e 'using Pkg; Pkg.test()' } }
}

$run = if ($Profile -eq 'All') { $profiles.Keys | Where-Object { $_ -ne 'Vectors' } } else { @($Profile) }
foreach ($p in $run) { Write-Host "== $p" -ForegroundColor Cyan; & $profiles[$p] }
