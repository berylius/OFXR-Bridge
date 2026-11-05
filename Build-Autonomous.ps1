param(
    [ValidateSet('new','djules')][string]$TestRoute = 'new',
    [string]$DependencyRoot = '',
    [string]$BuildRoot = '',
    [switch]$RunTests
)
# Native compiler diagnostics on stderr are not PowerShell failures.
# Every configure/build/test exit code is checked explicitly below.
$ErrorActionPreference = 'Continue'
$sourceRoot = $PSScriptRoot
if (-not $DependencyRoot) { $DependencyRoot = [IO.Path]::GetFullPath((Join-Path $sourceRoot '../.local/ofxr-autonomous-deps')) }
if (-not $BuildRoot) { $BuildRoot = [IO.Path]::GetFullPath((Join-Path $sourceRoot "../builds/ofxr-autonomous-$TestRoute")) }
$cmakeCommand = Get-Command cmake.exe -ErrorAction Stop
$cmake = $cmakeCommand.Source
$ctest = Join-Path (Split-Path $cmake) 'ctest.exe'
$cmakeHelp = & $cmake --help
if ($LASTEXITCODE) { throw "CMake generator discovery failed: $LASTEXITCODE" }
$generatorLine = $cmakeHelp | Select-String '^\s*\*?\s*Visual Studio \d+ \d{4}\s*=' | Select-Object -First 1
if (-not $generatorLine) { throw 'No Visual Studio CMake generator is available' }
$generator = [regex]::Match($generatorLine.Line, 'Visual Studio \d+ \d{4}').Value
& $cmake -S $sourceRoot -B $BuildRoot -G $generator -A x64 "-DXRFG_DEPENDENCY_ROOT=$DependencyRoot" "-DXRFG_TEST_NVIDIA_ROUTE=$TestRoute" "-DXRFG_AFW_RUNTIME=$DependencyRoot/runtime/afw-beta6/PDAFWPlugin.dll" -DXRFG_BUILD_TESTS=ON
if ($LASTEXITCODE) { throw "CMake configure failed: $LASTEXITCODE" }
& $cmake --build $BuildRoot --config Release --parallel
if ($LASTEXITCODE) { throw "Release build failed: $LASTEXITCODE" }
if ($RunTests) {
    & $ctest --test-dir $BuildRoot -C Release --output-on-failure --timeout 60
    if ($LASTEXITCODE) { throw "CTest failed: $LASTEXITCODE" }
}
