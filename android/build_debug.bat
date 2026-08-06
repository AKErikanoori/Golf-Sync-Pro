@echo off
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
echo JAVA_HOME set to: %JAVA_HOME%
echo Building debug APK...
call gradlew.bat assembleDebug
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD SUCCESS!
    echo APK location:
    echo app\build\outputs\apk\debug\app-debug.apk
    echo ========================================
) else (
    echo BUILD FAILED! Exit code: %ERRORLEVEL%
)
