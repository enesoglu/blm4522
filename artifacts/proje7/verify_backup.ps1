param(
    [string]$DbName = "dvdrental",
    [string]$HostName = "localhost",
    [int]$Port = 55432,
    [string]$UserName = "postgres",
    [string]$Root = "C:\Users\yildi\projects_db\blm4522\artifacts\proje7"
)

$ErrorActionPreference = "Stop"

$pgBin = "C:\Program Files\PostgreSQL\18\bin"
$env:Path = "$pgBin;$env:Path"

$backupDir = Join-Path $Root "backups"
$logDir = Join-Path $Root "logs"
$logFile = Join-Path $logDir "pg_backup.log"

New-Item -ItemType Directory -Force -Path $backupDir, $logDir | Out-Null

function Write-VerifyLog {
    param([string]$Status, [string]$Message)
    $line = "[{0}] VERIFY_{1} | db={2} | {3}" -f `
        (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Status, $DbName, $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

$latest = Get-ChildItem $backupDir -Filter "*.dump" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latest) {
    Write-VerifyLog "FAIL" "no backup file found"
    exit 1
}

$verifyDb = "verify_" + (Get-Date -Format "yyyyMMdd_HHmmss")

try {
    Write-VerifyLog "START" "backup=$($latest.FullName)"

    & createdb -U $UserName -h $HostName -p $Port $verifyDb
    if ($LASTEXITCODE -ne 0) { throw "createdb failed" }

    & pg_restore -U $UserName -h $HostName -p $Port -d $verifyDb --no-owner --no-privileges $latest.FullName
    if ($LASTEXITCODE -ne 0) { throw "pg_restore failed" }

    $query = @"
SELECT 'customer' AS table_name, COUNT(*) FROM customer
UNION ALL SELECT 'rental', COUNT(*) FROM rental
UNION ALL SELECT 'payment', COUNT(*) FROM payment
ORDER BY table_name;
"@

    Write-Host "Original database row counts:"
    & psql -U $UserName -h $HostName -p $Port -d $DbName -c $query

    Write-Host "Restored database row counts:"
    & psql -U $UserName -h $HostName -p $Port -d $verifyDb -c $query

    Write-VerifyLog "OK" "restored_database=$verifyDb | backup=$($latest.Name)"
}
catch {
    Write-VerifyLog "FAIL" $_.Exception.Message
    exit 1
}
finally {
    & dropdb -U $UserName -h $HostName -p $Port --if-exists $verifyDb | Out-Null
}
