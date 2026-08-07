<#
.SYNOPSIS
Windows 配置Git SSH密钥 PowerShell脚本
#>
$gitEmail = "13684522822@163.com"
$sshPath = "$env:USERPROFILE\.ssh"
$keyFile = "$sshPath\id_ed25519"

if (-not (Test-Path $sshPath)) {
    New-Item -ItemType Directory -Path $sshPath | Out-Null
}

if (-not (Test-Path "$keyFile")) {
    ssh-keygen -t ed25519 -C $gitEmail -f $keyFile
}

# 启动ssh agent
Start-Service ssh-agent
ssh-add $keyFile

# 生成config
$configContent = @"
Host github.com
  HostName github.com
  User git
  IdentityFile $keyFile
  IdentitiesOnly yes

Host gitee.com
  HostName gitee.com
  User git
  IdentityFile $keyFile
"@
$configContent | Out-File "$sshPath\config" -Encoding utf8

Write-Host "`n===== Your SSH Public Key ====="
Get-Content "$keyFile.pub"
Write-Host "`nRun: ssh -T git@github.com"

Write-Host "===== Your SSH Public Key ====="
Write-Host "===== Test GitHub SSH Connection ====="
Write-Host "Run: ssh -T git@github.com"