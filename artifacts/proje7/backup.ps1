param(
    [string]$DbName = "dvdrental",
    [string]$HostName = "localhost",
    [int]$Port = 55432,
    [string]$UserName = "postgres",
    [string]$BackupLevel = "daily",
    [int]$RetentionDays = 7,
    [int]$MinSizeBytes = 1024,
    [string]$Root = "C:\Users\yildi\projects_db\blm4522\artifacts\proje7"
)

$ErrorActionPreference = "Stop"

$pgBin = "C:\Program Files\PostgreSQL\18\bin"
$env:Path = "$pgBin;$env:Path"

$backupDir = Join-Path $Root "backups"
$logDir = Join-Path $Root "logs"
$alertDir = Join-Path $Root "alerts"
$logFile = Join-Path $logDir "pg_backup.log"

New-Item -ItemType Directory -Force -Path $backupDir, $logDir, $alertDir | Out-Null

$startedAt = Get-Date
$stamp = $startedAt.ToString("yyyyMMdd_HHmmss")
$backupFile = Join-Path $backupDir "$DbName`_$BackupLevel`_$stamp.dump"

function Write-BackupLog {
    param([string]$Status, [string]$Message)
    $line = "[{0}] {1} | db={2} | level={3} | file={4} | {5}" -f `
        (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Status, $DbName, $BackupLevel, $backupFile, $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

try {
    Write-BackupLog "START" "backup started"
    & pg_dump -U $UserName -h $HostName -p $Port -d $DbName -F c --no-owner --no-privileges -f $backupFile
    $exitCode = $LASTEXITCODE

    $size = 0
    if (Test-Path $backupFile) {
        $size = (Get-Item $backupFile).Length
    }

    if ($exitCode -eq 0 -and $size -gt $MinSizeBytes) {
        $duration = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
        Write-BackupLog "OK" "size_bytes=$size | duration_sec=$duration"
    }
    else {
        throw "pg_dump failed or backup is too small. exit=$exitCode size_bytes=$size"
    }

    $deleted = Get-ChildItem $backupDir -Filter "*.dump" |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

    foreach ($file in $deleted) {
        Remove-Item -LiteralPath $file.FullName -Force
        Write-BackupLog "RETENTION" "deleted_old_backup=$($file.Name)"
    }
}
catch {
    $message = $_.Exception.Message
    Write-BackupLog "FAIL" $message

    $alertFile = Join-Path $alertDir "mail_$stamp.txt"
    @"
TO: admin@example.com
SUBJECT: PG Backup FAIL
TIME: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
DATABASE: $DbName
MESSAGE: $message

This file simulates an e-mail/webhook alert for the course demo.
"@ | Set-Content -Path $alertFile -Encoding UTF8

    Write-Host "Alert file created: $alertFile"
    exit 1
}
