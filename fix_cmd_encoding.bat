@echo off
chcp 65001 >nul

cls
echo. ==================================================
echo.           修复CMD命令提示符乱码问题
echo. ==================================================
echo.

REM 临时设置当前CMD窗口为UTF-8编码
echo 当前CMD窗口已临时设置为UTF-8编码（代码页65001）
echo.

REM 提供永久修改的选项
echo 请选择以下操作：
echo 1. 仅在此窗口临时使用UTF-8（关闭窗口后失效）
echo 2. 永久修改CMD默认编码为UTF-8
echo 3. 退出
echo.

set /p choice=请输入选项 [1-3]: 

if "%choice%" == "1" (
echo.
echo 您选择了临时使用UTF-8编码。
echo 此窗口已设置为UTF-8，您可以继续在此窗口中操作。
echo 注意：关闭窗口后设置将失效。
echo.
echo 按任意键继续...
pause >nul
exit /b 0
)

if "%choice%" == "2" (
echo.
echo 正在永久修改CMD默认编码为UTF-8...

REM 检查是否以管理员身份运行
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
echo 错误：需要管理员权限才能永久修改CMD编码。
echo 请右键点击此脚本，选择"以管理员身份运行"。
echo.
echo 按任意键退出...
pause >nul
exit /b 1
)

REM 修改注册表以设置CMD默认编码为UTF-8
reg add "HKCU\Console" /v "CodePage" /t REG_DWORD /d 65001 /f >nul
echo CMD默认编码已设置为UTF-8。
echo.
echo 同时，我们将为您配置Windows终端的默认编码...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Terminal\Settings" /v "GloballyUniqueId" /t REG_SZ /d "{2c4de342-38b7-51cf-b940-2309a097f518}" /f >nul
echo Windows终端配置已更新。
echo.
echo 操作完成！请关闭所有CMD窗口并重新打开以应用更改。
echo.
echo 按任意键退出...
pause >nul
exit /b 0
)

if "%choice%" == "3" (
exit /b 0
)

REM 无效选项
echo 无效的选项，请重新运行此脚本并选择1-3之间的数字。
echo.
echo 按任意键退出...
pause >nul
exit /b 1