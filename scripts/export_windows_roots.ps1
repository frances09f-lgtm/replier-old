$ErrorActionPreference = 'Stop'

$outDir = 'C:\certs'
$pemPath = Join-Path $outDir 'windows-roots.pem'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path $pemPath) {
    Remove-Item $pemPath -Force
}

$stores = @(
    'Cert:\LocalMachine\Root',
    'Cert:\CurrentUser\Root'
)

foreach ($store in $stores) {
    Get-ChildItem $store | ForEach-Object {
        $bytes = $_.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $b64 = [Convert]::ToBase64String($bytes)
        Add-Content -Path $pemPath -Value '-----BEGIN CERTIFICATE-----'
        for ($i = 0; $i -lt $b64.Length; $i += 64) {
            $len = [Math]::Min(64, $b64.Length - $i)
            Add-Content -Path $pemPath -Value $b64.Substring($i, $len)
        }
        Add-Content -Path $pemPath -Value '-----END CERTIFICATE-----'
    }
}

Write-Output "Wrote $pemPath ($((Get-Item $pemPath).Length) bytes)"
