@echo off
REM 设置命令行编码为UTF-8
chcp 65001 > nul  

set "RegKey=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"
set "DumpFolder=C:\CrashDumps"
set "DumpCount=10"
set "DumpType=1"

REM 创建注册表键
reg add "%RegKey%" /f > nul

REM 设置崩溃文件保存路径
reg add "%RegKey%" /v DumpFolder /t REG_EXPAND_SZ /d %DumpFolder% /f /reg:64 > nul

REM 设置最大保存的崩溃文件数量
reg add "%RegKey%" /v DumpCount /t REG_DWORD /d %Dumpcount% /f /reg:64 > nul

REM 设置生成的崩溃文件类型
reg add "%RegKey%" /v DumpType /t REG_DWORD /d %DumpType% /f /reg:64 > nul

echo 崩溃文件配置已经成功添加到注册表