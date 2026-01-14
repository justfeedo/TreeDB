@echo off
echo ==========================================
echo MySQL TreeDB - Local Verification Script
echo ==========================================
echo.
echo Please ensure MySQL Server 8.0+ / 9.5 is running and 'mysql' is in your PATH.
echo.

:: Fix for missing PATH
set "PATH=%PATH%;C:\Program Files\MySQL\MySQL Server 9.5\bin"

set /p MYSQL_USER=Enter MySQL Username (default: root): 
if "%MYSQL_USER%"=="" set MYSQL_USER=root

set /p MYSQL_DB=Enter Database Name to Create/Use (default: treedb_test): 
if "%MYSQL_DB%"=="" set MYSQL_DB=treedb_test

echo.
echo Connecting as user '%MYSQL_USER%'...
echo (You will be prompted for the password)
echo.

:: 1. Create Database
echo [1/4] Creating Database '%MYSQL_DB%'...
mysql -u %MYSQL_USER% -p -e "CREATE DATABASE IF NOT EXISTS %MYSQL_DB%;"
if %errorlevel% neq 0 goto error

:: 2. Import Schema
echo [2/4] Importing Schema (schema.sql)...
mysql -u %MYSQL_USER% -p %MYSQL_DB% < schema.sql
if %errorlevel% neq 0 goto error

:: 3. Import Procedures
echo [3/4] Importing Procedures (procedures.sql)...
mysql -u %MYSQL_USER% -p %MYSQL_DB% < procedures.sql
if %errorlevel% neq 0 goto error

:: 4. Run Test Script
echo [4/4] Running Verification Script (test_script.sql)...
mysql -u %MYSQL_USER% -p %MYSQL_DB% < test_script.sql
if %errorlevel% neq 0 goto error

echo.
echo ==========================================
echo VERIFICATION SUCCESSFUL
echo ==========================================
echo.
pause
exit /b 0

:error
echo.
echo ==========================================
echo ERROR OCCURRED
echo ==========================================
pause
exit /b 1
