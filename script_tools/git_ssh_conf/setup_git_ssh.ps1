<#
.SYNOPSIS
Windows 配置Git SSH密钥 PowerShell脚本
#>
$gitEmail = "your_email@example.com"
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

Write-Host "`n===== 你的公钥 ====="
Get-Content "$keyFile.pub"
Write-Host "`n测试命令：ssh -T git@github.com"
