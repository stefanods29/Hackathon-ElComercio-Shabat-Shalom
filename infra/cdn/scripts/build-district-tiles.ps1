$ErrorActionPreference = 'Stop'
& node (Join-Path $PSScriptRoot 'build-district-tiles.mjs')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
