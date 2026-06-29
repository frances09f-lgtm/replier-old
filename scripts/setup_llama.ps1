$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$LlamaDir = Join-Path $ProjectRoot "android\app\src\main\jni\llama.cpp"
$ZipPath = Join-Path $env:TEMP "llama.cpp-b4629.zip"
$Tag = "b4629"

Write-Host "Setting up llama.cpp source ($Tag)..." -ForegroundColor Cyan

if (Test-Path (Join-Path $LlamaDir "llama.h")) {
    Write-Host "llama.cpp already downloaded. Skipping." -ForegroundColor Green
    exit 0
}

Write-Host "Downloading from GitHub..." -ForegroundColor Yellow
$Url = "https://github.com/ggml-org/llama.cpp/archive/refs/tags/$Tag.zip"

try {
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
    Write-Host "Downloaded $((Get-Item $ZipPath).Length / 1MB) MB" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download: $_"
    exit 1
}

Write-Host "Extracting..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $ZipPath -DestinationPath $env:TEMP -Force
    $Extracted = Join-Path $env:TEMP "llama.cpp-$Tag"
    if (Test-Path $Extracted) {
        # Remove old if exists
        if (Test-Path $LlamaDir) {
            Remove-Item -Path $LlamaDir -Recurse -Force
        }
        Move-Item -Path $Extracted -Destination $LlamaDir -Force
        Write-Host "Extracted to $LlamaDir" -ForegroundColor Green
    } else {
        Write-Error "Extraction failed: $Extracted not found"
        exit 1
    }
}
catch {
    Write-Error "Failed to extract: $_"
    exit 1
}
finally {
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
}

Write-Host "llama.cpp setup complete!" -ForegroundColor Green
