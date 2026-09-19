@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title LAN Network Full Optimize

REM ===== 0) Ensure administrator privilege =====
if /I not "%~1"=="-elevated" (
    net session >nul 2>&1
    if not "%errorlevel%"=="0" (
        echo [INFO] 正在请求管理员权限...
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '-elevated' -Verb RunAs"
        exit /b
    )
)

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "LOG_FILE=%LOG_DIR%\lan_optimize_%TS%.log"
set "LOG_ENCODING=utf8"

call :log "================ LAN 网络完整优化开始 ================"
call :log "日志文件: %LOG_FILE%"
call :log "脚本路径: %~f0"

REM ===== 1) Collect key runtime values =====
set "WLAN_ALIAS="
set "SSID="
set "GATEWAY="

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$cfg=Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up' } ^| Select-Object -First 1; if($cfg){($cfg.InterfaceAlias).Trim()}"`) do set "WLAN_ALIAS=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$m=(netsh wlan show interfaces ^| Select-String '^\s*SSID\s*:\s*(.+)$' ^| Select-Object -First 1); if($m){($m.Matches[0].Groups[1].Value).Trim()}"`) do set "SSID=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$cfg=Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up' } ^| Select-Object -First 1; if($cfg){($cfg.IPv4DefaultGateway.NextHop).Trim()}"`) do set "GATEWAY=%%i"
if not defined GATEWAY (
    for /f "tokens=3" %%i in ('route print 0.0.0.0 ^| findstr /R "^[ ]*0\.0\.0\.0[ ]*0\.0\.0\.0"') do (
        if not defined GATEWAY set "GATEWAY=%%i"
    )
)
if not defined GATEWAY (
    for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /C:"Default Gateway" /C:"默认网关"') do (
        set "GW_TMP=%%i"
        set "GW_TMP=!GW_TMP: =!"
        if not "!GW_TMP!"=="" if not defined GATEWAY set "GATEWAY=!GW_TMP!"
    )
)

if not defined WLAN_ALIAS set "WLAN_ALIAS=WLAN"
call :log "当前接口: %WLAN_ALIAS%"
if defined SSID (
    call :log "当前SSID: %SSID%"
) else (
    call :log "未识别到SSID，将尝试按接口重连。"
)
if defined GATEWAY (
    call :log "默认网关: %GATEWAY%"
) else (
    call :log "未识别到默认网关，后续会跳过网关 ping。"
)

REM ===== 2) Baseline diagnostics =====
call :log "[步骤] 执行优化前基线检测..."
call :exec "ipconfig /all"
call :exec "powershell -NoProfile -Command ""Get-NetAdapter | Select-Object Name,Status,LinkSpeed | Format-Table -AutoSize"""
call :exec "netsh wlan show interfaces"
if defined GATEWAY (
    call :exec "ping -n 20 %GATEWAY%"
)

REM ===== 3) DNS + DHCP refresh =====
call :log "[步骤] 刷新 DNS 缓存并续租 DHCP..."
call :exec "ipconfig /flushdns"
call :exec "ipconfig /renew"

REM ===== 4) Wireless power strategy =====
call :log "[步骤] 设置无线网卡电源策略为最高性能..."
call :exec "powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0"
call :exec "powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0"
call :exec "powercfg /S scheme_current"

REM ===== 5) Reconnect Wi-Fi =====
call :log "[步骤] 断开并重连 Wi-Fi..."
call :exec "netsh wlan disconnect"
timeout /t 3 /nobreak >nul
if defined SSID (
    call :exec "netsh wlan connect name=""%SSID%"" interface=""%WLAN_ALIAS%"""
) else (
    call :exec "netsh wlan connect interface=""%WLAN_ALIAS%"""
)

REM ===== 6) Full network stack reset =====
call :log "[步骤] 重置网络栈（Winsock / TCPIP / 防火墙）..."
call :exec "netsh winsock reset"
call :exec "netsh int ip reset"
call :exec "netsh advfirewall reset"

REM ===== 7) Post diagnostics =====
call :log "[步骤] 执行优化后复测..."
call :exec "ipconfig /all"
call :exec "powershell -NoProfile -Command ""Get-NetAdapter | Select-Object Name,Status,LinkSpeed | Format-Table -AutoSize"""
call :exec "netsh wlan show interfaces"
if defined GATEWAY (
    call :exec "ping -n 20 %GATEWAY%"
)

call :log "================ LAN 网络完整优化结束 ================"
call :log "提示: netsh winsock/int ip 重置后建议重启电脑生效。"
echo.
echo [完成] 全流程已执行，详细结果见:
echo %LOG_FILE%
echo.

choice /c YN /n /m "是否立即重启电脑以完成网络栈重置? [Y/N]: "
if errorlevel 2 goto :noreboot
if errorlevel 1 goto :reboot

:noreboot
echo 已选择稍后手动重启。
exit /b 0

:reboot
echo 5秒后重启...
shutdown /r /t 5
exit /b 0

:exec
set "CMD_TO_RUN=%~1"
call :log "[CMD] %CMD_TO_RUN%"
set "TMP_RAW=%TEMP%\lan_opt_%RANDOM%_%RANDOM%.tmp"
set "TMP_CMD=%TEMP%\lan_cmd_%RANDOM%_%RANDOM%.cmd"
set "LAN_CMD_TO_RUN=%CMD_TO_RUN%"
powershell -NoProfile -Command "$lines=@('@echo off','chcp 65001>nul',$env:LAN_CMD_TO_RUN); Set-Content -Path '%TMP_CMD%' -Value $lines -Encoding ascii"
cmd /c "%TMP_CMD%" >"%TMP_RAW%" 2>&1
set "RC=%errorlevel%"
if exist "%TMP_RAW%" (
    powershell -NoProfile -Command "Get-Content -Path '%TMP_RAW%' -Encoding utf8 | Out-File -FilePath '%LOG_FILE%' -Append -Encoding %LOG_ENCODING%"
) else (
    call :log "[WARN] 临时输出文件未生成: %TMP_RAW%"
)
set "LAN_CMD_TO_RUN="
del /f /q "%TMP_CMD%" >nul 2>&1
del /f /q "%TMP_RAW%" >nul 2>&1
if not "%RC%"=="0" (
    call :log "[WARN] 命令返回码=%RC%"
)
exit /b 0

:log
set "MSG=%~1"
set "LOG_LINE=[%date% %time%] !MSG!"
echo !LOG_LINE!
set "LAN_LOG_LINE=!LOG_LINE!"
powershell -NoProfile -Command "Add-Content -Path '%LOG_FILE%' -Value $env:LAN_LOG_LINE -Encoding %LOG_ENCODING%"
exit /b 0
