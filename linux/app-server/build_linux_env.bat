@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Configuration area
set "PROJECT_DIR=%~dp0"
set "REQ_FILE=requirements.txt"
set "PYTHON_VERSION=3.12"
set "ENV_NAME=project_env"
set "TEMP_TAR_FILE=linux_offline_env.tar"
set "FINAL_OUTPUT=linux_offline_env.tar.gz"
set "ALL_FINAL_OUTPUT=app-server.zip"

echo Starting to build Linux (x86_64) Python offline environment...

REM Check requirements.txt
if not exist "%PROJECT_DIR%%REQ_FILE%" (
    echo Error: Cannot find %REQ_FILE%
    exit /b 1
)

REM Check if Docker is running
docker version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running or not installed
    echo Please make sure Docker Desktop is started
    exit /b 1
)

REM Switch to project directory
cd /d "%PROJECT_DIR%"

REM Use Docker to run all steps in one container
set "TEMP_SCRIPT_PROJECT=%PROJECT_DIR%docker_build_temp.sh"

REM Create temporary script file using a simpler method
echo Creating temporary build script...
(
echo set -e
echo echo [1/6] Updating Conda...
echo conda update -n base -c defaults conda -y ^> /dev/null 2^>^&1
echo echo [2/6] Creating Python %PYTHON_VERSION% environment...
echo conda create -n %ENV_NAME% python=%PYTHON_VERSION% -y ^> /dev/null 2^>^&1
echo echo [3/6] Activating environment and installing dependencies...
echo source /opt/conda/bin/activate %ENV_NAME%
echo conda config --add channels conda-forge
echo conda config --set channel_priority strict
echo echo Installing core packages with conda...
echo conda install -n %ENV_NAME% pandas numpy openpyxl pyarrow python-dateutil -y ^> /dev/null 2^>^&1 ^|^| echo "Conda install failed, will try pip for all packages"
echo echo Installing packages with pip...
echo pip install --upgrade pip setuptools wheel
echo pip install -r %REQ_FILE% --index-url https://pypi.tuna.tsinghua.edu.cn/simple ^|^| pip install -r %REQ_FILE% --index-url https://pypi.org/simple
echo echo [4/6] Installing packaging tool...
echo conda install -c conda-forge conda-pack -y ^> /dev/null 2^>^&1
echo echo [5/6] Packing to tar file...
echo conda-pack -n %ENV_NAME% -o %TEMP_TAR_FILE% --format tar --ignore-missing-files
echo echo [6/6] Compressing with gzip...
echo gzip -f %TEMP_TAR_FILE%
echo echo Done.
) > "%TEMP_SCRIPT_PROJECT%"

REM Convert Windows line endings to Unix using PowerShell and remove BOM
powershell -NoProfile -ExecutionPolicy Bypass -Command "$content = Get-Content '%TEMP_SCRIPT_PROJECT%' -Raw; $content = $content -replace \"`r`n\", \"`n\" -replace \"`r\", \"`n\"; $utf8NoBom = New-Object System.Text.UTF8Encoding $false; [System.IO.File]::WriteAllText('%TEMP_SCRIPT_PROJECT%', $content, $utf8NoBom)"

if not exist "%TEMP_SCRIPT_PROJECT%" (
    echo Error: Failed to create temporary script file
    exit /b 1
)

REM Execute Docker command
echo Executing Docker command...
echo Project directory: %PROJECT_DIR%
echo Temp script: %TEMP_SCRIPT_PROJECT%

REM Use PowerShell to execute Docker command
powershell -NoProfile -ExecutionPolicy Bypass -Command "$projectDir = '%PROJECT_DIR%'; $projectDir = $projectDir.TrimEnd('\'); Write-Host 'Docker volume path:' $projectDir; & docker run --rm --platform linux/amd64 -v (\"${projectDir}:/workspace\") -w /workspace continuumio/miniconda3 /bin/bash /workspace/docker_build_temp.sh; exit $LASTEXITCODE"

set "DOCKER_EXIT_CODE=%ERRORLEVEL%"

REM Clean up temporary files
if exist "%TEMP_SCRIPT_PROJECT%" del "%TEMP_SCRIPT_PROJECT%" >nul 2>&1

if %DOCKER_EXIT_CODE% neq 0 (
    echo Build failed.
    exit /b 1
)

echo Container operations completed.

REM Check if final file exists
if not exist "%PROJECT_DIR%%FINAL_OUTPUT%" (
    echo Error: Generated file %FINAL_OUTPUT% not found
    exit /b 1
)

echo ---------------------------------------------
echo Success! Offline package generated: %FINAL_OUTPUT%
echo Linux extract command: tar -xzf %FINAL_OUTPUT% -C ^<target_dir^>
echo ---------------------------------------------

echo Starting to package complete offline package...

REM Check if app-run.sh exists
set "FILES_TO_ZIP=*.py %FINAL_OUTPUT%"
if exist "app-run.sh" (
    set "FILES_TO_ZIP=*.py app-run.sh %FINAL_OUTPUT%"
)

REM Use PowerShell to create zip file
cd /d "%PROJECT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$projectDir = '%PROJECT_DIR%'; $zipPath = Join-Path $projectDir '%ALL_FINAL_OUTPUT%'; if (Test-Path $zipPath) { Remove-Item $zipPath -Force }; $files = @(); Get-ChildItem -Path $projectDir -Filter '*.py' -File | ForEach-Object { $files += $_.FullName }; if (Test-Path (Join-Path $projectDir 'app-run.sh')) { $files += (Join-Path $projectDir 'app-run.sh') }; if (Test-Path (Join-Path $projectDir '%FINAL_OUTPUT%')) { $files += (Join-Path $projectDir '%FINAL_OUTPUT%') }; if ($files.Count -gt 0) { Compress-Archive -Path $files -DestinationPath $zipPath -Force; Write-Host 'ZIP file created' } else { Write-Host 'No files to zip'; exit 1 }"

if errorlevel 1 (
    echo ZIP packaging failed, trying alternative method...
    where 7z >nul 2>&1
    if not errorlevel 1 (
        echo Using 7-Zip to package...
        7z a -tzip "%ALL_FINAL_OUTPUT%" *.py app-run.sh scripts utils "%FINAL_OUTPUT%" 2>nul
        if errorlevel 1 (
            echo 7-Zip packaging also failed
            echo Please manually package the following files to ZIP:
            echo   - *.py
            echo   - app-run.sh (if exists)
            echo   - %FINAL_OUTPUT%
            exit /b 1
        )
    ) else (
        echo Cannot create ZIP file
        echo Please install 7-Zip or manually package the following files:
        echo   - *.py
        echo   - app-run.sh (if exists)
        echo   - %FINAL_OUTPUT%
        exit /b 1
    )
)

if exist "%ALL_FINAL_OUTPUT%" (
    echo Success! Complete offline package: %ALL_FINAL_OUTPUT%
    echo ---------------------------------------------
    echo Linux extract command: unzip %ALL_FINAL_OUTPUT% -d ^<target_dir^>
    
    if exist "%FINAL_OUTPUT%" (
        del "%FINAL_OUTPUT%"
        echo Intermediate files cleaned up
    )
) else (
    echo Warning: ZIP file not generated, but tar.gz file was created
)

echo ---------------------------------------------
echo Build completed!
pause
