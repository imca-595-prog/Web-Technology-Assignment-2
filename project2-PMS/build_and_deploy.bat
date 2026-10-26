@echo off
setlocal

REM ---------------------------------------------------------------
REM  EDIT THESE THREE PATHS IF YOURS ARE DIFFERENT
REM  GlassFish 7 supports JDK 17 / 21. Do NOT use JDK 22+ (e.g. 25).
REM ---------------------------------------------------------------
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
set "MAVEN_HOME=C:\apache-maven\apache-maven-3.9.9"
set "GLASSFISH_HOME=C:\glassfish7\glassfish7"

set "PATH=%JAVA_HOME%\bin;%MAVEN_HOME%\bin;%PATH%"
set "PROJECT_DIR=%~dp0"

echo =============================================
echo  Patient Management System - Deploy Script
echo =============================================

echo [1/4] Building WAR with Maven...
cd /d "%PROJECT_DIR%"
call mvn clean package -q
if errorlevel 1 ( echo [ERROR] Maven build FAILED & exit /b 1 )
echo [OK] WAR built: %PROJECT_DIR%target\pms.war

echo [2/4] Starting GlassFish domain...
call "%GLASSFISH_HOME%\bin\asadmin" start-domain
echo [OK] GlassFish started

echo [3/4] Undeploying old version (if any)...
call "%GLASSFISH_HOME%\bin\asadmin" undeploy pms >nul 2>&1
echo [OK] Done

echo [4/4] Deploying pms.war...
call "%GLASSFISH_HOME%\bin\asadmin" deploy --name pms --contextroot /pms "%PROJECT_DIR%target\pms.war"
if errorlevel 1 ( echo [ERROR] Deployment FAILED & exit /b 1 )

echo.
echo =============================================
echo  DONE - Open: http://localhost:8080/pms/
echo  (use port 9090 only if you changed GlassFish's HTTP port)
echo =============================================
endlocal
