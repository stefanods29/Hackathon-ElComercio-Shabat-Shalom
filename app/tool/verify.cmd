@echo off
rem Verificacion completa de la app en Windows: genera plataformas si faltan, dependencias,
rem localizacion, analisis, pruebas y formato. Deja un log por paso en tool\salida\.
rem Uso (desde la carpeta app\):  tool\verify.cmd
rem Si flutter no esta en el PATH:  set FLUTTER=C:\ruta\flutter\bin\flutter.bat  y  set DART=C:\ruta\flutter\bin\dart.bat
setlocal
cd /d "%~dp0.."
if "%FLUTTER%"=="" set "FLUTTER=flutter"
if "%DART%"=="" set "DART=dart"
if not exist tool\salida mkdir tool\salida
set "RESUMEN=tool\salida\resumen.txt"
echo Verificacion %DATE% %TIME% > "%RESUMEN%"

call "%FLUTTER%" --version > tool\salida\00-version.log 2>&1

if exist android\ goto plataformas_listas
call "%FLUTTER%" create --platforms=android,ios --org pe.shabatshalom --project-name vecinal . > tool\salida\01-create.log 2>&1
echo 01-create: %ERRORLEVEL% >> "%RESUMEN%"
:plataformas_listas

call "%FLUTTER%" pub get > tool\salida\02-pub-get.log 2>&1
echo 02-pub-get: %ERRORLEVEL% >> "%RESUMEN%"

call "%FLUTTER%" gen-l10n > tool\salida\03-gen-l10n.log 2>&1
echo 03-gen-l10n: %ERRORLEVEL% >> "%RESUMEN%"

call "%FLUTTER%" analyze > tool\salida\04-analyze.log 2>&1
echo 04-analyze: %ERRORLEVEL% >> "%RESUMEN%"

call "%FLUTTER%" test > tool\salida\05-test.log 2>&1
echo 05-test: %ERRORLEVEL% >> "%RESUMEN%"

call "%DART%" format --output=none --set-exit-if-changed lib test > tool\salida\06-format.log 2>&1
echo 06-format: %ERRORLEVEL% >> "%RESUMEN%"

echo == FIN >> "%RESUMEN%"
type "%RESUMEN%"
endlocal
