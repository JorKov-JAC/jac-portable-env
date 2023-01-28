@echo off
:: Sets up a portable developer environment intended for usb drives.
:: Copyright (C) Jordan Kovacs
::
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.
::
:: This program is distributed in the hope that it will be useful,
:: but WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
:: GNU General Public License for more details.
::
:: You should have received a copy of the GNU General Public License
:: along with this program.  If not, see <https://www.gnu.org/licenses/>.

:: Why batch and not powershell?
:: Because I don't want users to deal with execution policy.
:: Do I regret this choice?
:: Deeply.
:: This whole script is underdocumented and full of repetition and laziness (some
:: of which is even batch's fault). Have fun! - Jordan

:: TODO
:: - Output instructions to a .txt file so you don't need the setup script to see them.
:: - Allow multiple versions of .NET to be installed at once.
::   See readme.md FAQ for a workaround.


setlocal ENABLEDELAYEDEXPANSION

echo.%~n0 version 1.1.0  Copyright (C) Jordan Kovacs
echo.This program comes with ABSOLUTELY NO WARRANT.
echo.This is free software, and you are welcome to redistribute it
echo.under certain conditions; see ^<https://www.gnu.org/licenses/gpl-3.0.en.html^>.
echo.
echo.To stop this script at any time, type Ctrl-C.
echo.Would you like to setup a new portable environment? (1)
echo.Or view help on how to use an already-setup environment? (2)
:: Sore tomo... wa~ta~shi?
choice /c 12
echo.
if !ERRORLEVEL!==2 goto envHelp

:newEnv
:newEnv_getPath
set s_rawOut=
set /p "s_rawOut=Enter path of folder to install to (ideally a drive's root): "
call :getFullPath s_rawOut "!s_rawOut!\"
echo.Selected path: !s_rawOut!
if exist "!s_rawOut!" (
	:: Path is an existing folder
	choice /m "WARNING This folder already exists and will be filled with files, continue?"
	if !ERRORLEVEL!==2 goto newEnv_getPath
) else if exist "!s_rawOut:~0,-1!" (
	:: Not a folder but still exists, must be a file
	echo.ERROR Path points to an existing file (not a folder^).
	goto newEnv_getPath
)

if not defined s_username set "s_username=P"
if not defined s_homename set "s_homename=HOME"

echo.
choice /m "Setup .NET? (C#)"
set s_dotnet=!ERRORLEVEL!
if !s_dotnet!==1 (
	set serverError=0
	:: Get latest versions from server
	for /f %%G IN ('powershell -Command Invoke-WebRequest https://dotnetcli.azureedge.net/dotnet/Sdk/7.0/latest.version ^^^| %% {$_.Content}') DO set "s_dotnet7Ver=%%G"
	if "!s_dotnet7Ver!"=="+" set serverError=1
	for /f %%G IN ('powershell -Command Invoke-WebRequest https://dotnetcli.azureedge.net/dotnet/Sdk/6.0/latest.version ^^^| %% {$_.Content}') DO set "s_dotnet6Ver=%%G"
	if "!s_dotnet6Ver!"=="+" set serverError=1
	for /f %%G IN ('powershell -Command Invoke-WebRequest https://dotnetcli.azureedge.net/dotnet/Sdk/5.0/latest.version ^^^| %% {$_.Content}') DO set "s_dotnet5Ver=%%G"
	if "!s_dotnet5Ver!"=="+" set serverError=1
	for /f %%G IN ('powershell -Command Invoke-WebRequest https://dotnetcli.azureedge.net/dotnet/Sdk/3.1/latest.version ^^^| %% {$_.Content}') DO set "s_dotnet3Ver=%%G"
	if "!s_dotnet3Ver!"=="+" set serverError=1

	if !serverError!==0 (
		echo.Which .NET version?
		echo.[7] (!s_dotnet7Ver!^), [6] (!s_dotnet6Ver!^), [5] (!s_dotnet5Ver!^), [3] (!s_dotnet3Ver!^), or [C]ustom?

		set choices=7653C
		choice /c !choices! /m "(probably want 7, 6, or 3)"
		set /a choiceIdx=!ERRORLEVEL!-1
		call :eval $ "^!choices:~%%choiceIdx%%^,1^!"
		if !$!==7 ( set "s_dotnetVer=!s_dotnet7Ver!"
		) else if !$!==6 ( set "s_dotnetVer=!s_dotnet6Ver!"
		) else if !$!==5 ( set "s_dotnetVer=!s_dotnet5Ver!"
		) else if !$!==3 ( set "s_dotnetVer=!s_dotnet3Ver!"
		) else call :readCustomVer s_dotnetVer

		echo.Chosen version: !s_dotnetVer!
	) else (
		echo.Could not get version info from server.
		call :readCustomVer s_dotnetVer
	)

	set "s_dotnetCantMulti=1"
	if "!s_dotnetVer:~,1!" LSS "7" ( if "!s_dotnetVer:~1,1!" == "." (
		set "s_dotnetCantMulti=2"
		echo.Should this portable version of .NET override ones installed on the computer
		choice /m "even if the computer's installation is more up-to-date? (probably want N)"
		set "s_dotnetNoMulti=!ERRORLEVEL!"
	)) else (
		echo.Notice: Since .NET 7, this portable version of .NET will override ones installed
		echo.on the computer even if the computer's installation is more up-to-date.
	)
)

echo.
choice /m "Setup Git? (probably want Y)"
set s_git=!ERRORLEVEL!
if !s_git!==1 (
	:: Get latest version from server. Avoids API because of rate limit
	for /f %%G IN ('powershell -Command Invoke-WebRequest https://github.com/git-for-windows/git/releases/latest -MaximumRedirection 0 -ErrorAction Ignore ^^^| %% {$_.Headers.Location -replace ^'.*/v(\d+\.\d+\.\d+\.windows\.\d+^)$^'^, ^'$1^'}') DO set "s_gitVer=%%G"

	if not "!s_gitVer!"=="+" (
		choice /m "Y to install newest version (!s_gitVer!^), N to specify custom version."
		if !ERRORLEVEL!==2 call :readCustomVer s_gitVer
	) else (
		echo.Could not get version info from server.
		call :readCustomVer s_gitVer
	)
)

echo.
choice /m "Setup Node.js? (probably want Y)"
set s_node=!ERRORLEVEL!
if !s_node!==1 (
	:: Get latest LTS version from server
	for /f %%G IN ('powershell -Command Invoke-WebRequest https://nodejs.org/dist/index.json ^^^| %% {$_.Content} ^^^| ConvertFrom-Json ^^^| %% {$_} ^^^| ? {$_.lts -ne $False} ^^^| select @{l^=^'ver^'^; e^={[version] $_.version.substring(1^)}} ^^^| Measure ver -Maximum ^^^| %% {$_.Maximum.ToString(^)}') DO set "s_nodeVer=%%G"

	if not "!s_nodeVer!"=="+" (
		choice /m "Y to install newest LTS version (!s_nodeVer!^), N to specify custom version."
		if !ERRORLEVEL!==2 call :readCustomVer s_nodeVer
	) else (
		echo.Could not get version info from server.
		call :readCustomVer s_nodeVer
	)
)

echo.
choice /m "Setup Visual Studio Code?"
set s_vsc=!ERRORLEVEL!

call :getPathOnly s_envOut "!s_rawOut!"
set "s_envCmdPath=!s_rawOut!env.cmd"
set s_env=1
if exist "!s_envCmdPath!" (
	echo.
	choice /m "Overwrite env.cmd? (almost always want Y unless preserving the current env.cmd)"
	set s_env=!ERRORLEVEL!
)

echo.
choice /m "Give full file/folder control to any account? (NTFS only, probably want Y)"
set s_publicControl=!ERRORLEVEL!

mkdir !s_rawOut:/=\!

if defined s_envOnly goto createEnv

:: curl -LsS "https://www.7-zip.org/a/7zr.exe" -o "!s_rawOut!7zr.exe"

echo.
echo.Setting up...

echo.- Linux home
set "linuxUsrDir=!s_rawOut!!s_homename!\"
mkdir "!linuxUsrDir!.config"
mkdir "!linuxUsrDir!.local\share"
mkdir "!linuxUsrDir!.local\state"

echo.- Windows home
set "winUserDir=!s_rawOut!Users\!s_username!\"
mkdir "!winUserDir!AppData\Roaming"
mkdir "!winUserDir!AppData\Local"
:: VSCode wants a desktop directory, might as well add the rest out of precaution
mkdir "!winUserDir!Desktop"
mkdir "!winUserDir!Documents"
mkdir "!winUserDir!Downloads"
mkdir "!winUserDir!Music"
mkdir "!winUserDir!Pictures"
mkdir "!winUserDir!Videos"

:: Install Git at the beginning because it requires user interaction
if !s_git!==1 (
	echo.- Git

	mkdir "!s_rawOut!git"

	set "$=PortableGit-!s_gitVer:.windows=!"
	if "!$:~-2!"==".1" set "$=!$:~0,-2!"
	set "$=!$!-64-bit.7z.exe"
	:: curl -L "https://github.com/git-for-windows/git/releases/download/v!s_gitVer!/!$!" -o "!s_rawOut!git\!$!"
	powershell -Command Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v!s_gitVer!/!$!" -OutFile "!s_rawOut!git\!$!"

	echo.^>^>^>^> Just press OK (extract files to their default location^) ^<^<^<^<
	!s_rawOut!git\!$!

	call :moveFolderContents "!s_rawOut!git\PortableGit" "!s_rawOut!git"
	rmdir "!s_rawOut!git\PortableGit\"

	:: Fix portable git referring to the credential manager with abs path
	set "$=!linuxUsrDir!.gitconfig"
	if not exist "!$!" (
		echo.[credential "helperselector"]
		echo.	selected = manager
		echo.[credential]
		echo.	helper = ""
		echo.	helper = manager.exe
	)>>"!$!"
)

if !s_dotnet!==1 (
	echo.- .NET

	mkdir "!s_rawOut!dotnet\data"

	:: curl -L "https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1" -o "!s_rawOut!dotnet-install.ps1"
	powershell -Command Invoke-WebRequest "https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1" -OutFile "!s_rawOut!dotnet-install.ps1"

	echo.This may take a while, but the program isn't frozen (probably...^)
	powershell -ExecutionPolicy RemoteSigned -File "!s_rawOut!dotnet-install.ps1" -InstallDir "!s_rawOut!dotnet" -Version !s_dotnetVer!

	:: Cannot delete immediately for some reason
	timeout 2 /NOBREAK >nul
	del "!s_rawOut!dotnet-install.ps1"
)

if !s_node!==1 (
	echo.- Node.js

	mkdir "!s_rawOut!node"

	set "$=node-v!s_nodeVer!-win-x64.zip"
	:: curl -L "https://nodejs.org/dist/v!s_nodeVer!/!$!" -o "!s_rawOut!node\!$!"
	powershell -Command Invoke-WebRequest "https://nodejs.org/dist/v!s_nodeVer!/!$!" -OutFile "!s_rawOut!node\!$!"

	powershell -Command Expand-Archive "!s_rawOut!node\!$!" -DestinationPath "!s_rawOut!node" -Force
)

if !s_vsc!==1 (
	echo.- VSCode

	mkdir "!s_rawOut!VSC\data"

	set "$=!s_rawOut!VSC\vsc.zip"
	:: curl -L "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive" -o "!$!"
	powershell -Command Invoke-WebRequest "'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive'" -OutFile "!$!"

	powershell -Command Expand-Archive "!$!" -DestinationPath "!s_rawOut!VSC" -Force
)

:createEnv
if !s_env!==1 (
	echo.- env.cmd
	(
		echo.@echo off
		echo.setlocal ENABLEDELAYEDEXPANSION
		echo.
		echo.:: -- Linux home -- ::
		echo.:: For programs like bash, git, ssh, vim, etc...
		echo.set "HOME=%%~d0!s_envOut:\=/!!s_homename!"
		echo.set "XDG_CONFIG_HOME=^!HOME^!/.config"
		echo.set "XDG_DATA_HOME=^!HOME^!/.local/share"
		echo.set "XDG_STATE_HOME=^!HOME^!/.local/state"
		echo.
		echo.:: -- Windows home -- ::
		echo.:: Change username to whatever you want:
		echo.set "USERNAME=!s_username!"
		echo.set "HOMEDRIVE=%%~d0"
		echo.set "HOMEPATH=!s_envOut!Users\^!USERNAME^!"
		echo.set "USERPROFILE=^!HOMEDRIVE^!^!HOMEPATH^!"
		echo.set "APPDATA=^!USERPROFILE^!\AppData\Roaming"
		echo.set "LOCALAPPDATA=^!USERPROFILE^!\AppData\Local"

		if !s_dotnet!==1 (
			echo.
			echo.:: -- .NET -- ::
			echo.set "DOTNET_ROOT=%%~d0!s_envOut!dotnet"
			echo.set "DOTNET_CLI_HOME=^!DOTNET_ROOT^!\data"
			echo.set "path=^!DOTNET_ROOT^!;^!DOTNET_CLI_HOME^!\.dotnet\tools;^!path^!"
			echo.:: Opt out of sending telemetry data to Microsoft (comment out if you don't mind^):
			echo.set "DOTNET_CLI_TELEMETRY_OPTOUT=1"

			if NOT "!s_dotnetCantMulti!"=="1" (
				set "$=:: "
				if "!s_dotnetNoMulti!"=="1" set $=
				echo.:: Make portable version of .NET override local installation:
				echo.!$!set "DOTNET_MULTILEVEL_LOOKUP=0"
			)
		)

		if !s_git!==1 (
			echo.
			echo.:: -- Git -- ::
			echo.:: Programs also need this for integration with Git
			echo.set "gitdir=%%~d0!s_envOut!git"
			echo.set "path=^!gitdir^!\bin;^!gitdir^!\cmd;^!path^!"
		)

		if !s_node!==1 (
			echo.
			echo.:: -- Node -- ::
			echo.set "path=%%~d0!s_envOut!node\node-v!s_nodeVer!-win-x64;^!path^!"
		)

		if !s_vsc!==1 (
			echo.
			echo.:: -- VSC -- ::
			echo.set "path=%%~d0!s_envOut!VSC\bin;^!path^!"
		)

		echo.
		echo.cmd
	)>!s_envCmdPath!
)

if !s_publicControl!==1 (
	echo.- Changing Permissions
	icacls !s_rawOut! /grant:r "Authenticated Users":(OI^)(CI^)F
)

echo.
echo.===============
echo.Setup complete!
echo.===============
echo.
goto envHelp


:envHelp
if not defined s_rawOut (
	:envHelp_getExistingInstallationPath
	set s_rawOut=
	set /p "s_rawOut=Enter path to your portable installation: "
	set "s_rawOut=!s_rawOut!\"
	if not exist "!s_rawOut!" goto envHelp_getExistingInstallationPath
	echo.
)

echo.
echo.__________________________________IMPORTANT___________________________________
echo.      Whenever you want to use your portable environment, you need to run
echo.    the env.cmd script and launch all of your portable programs from there.
if exist "!s_rawOut!dotnet" (
	echo.
	echo.
	echo..NET:
	echo.-----
	echo.To create a new console project in the current directory (see 'dotnet new console --help'^):
	echo.	dotnet new console
	echo.	dotnet new sln
	echo.	dotnet sln add .
	echo.To run your program:
	echo.	dotnet run
	echo.To run tests (won't work for all testing frameworks^^^!^):
	echo.	dotnet test
)
if exist "!s_rawOut!git" (
	echo.
	echo.
	echo.Git:
	echo.----
	echo.To set up git:
	echo.	git config --global user.name "Your Name Comes Here"
	echo.	git config --global user.email you@yourdomain.example.com
	echo.To create a new repo:
	echo.	git init
	echo.To clone a repo:
	echo.	git clone "Url"
	echo.To stage, commit, and push:
	echo.	git add .
	echo.	git commit -m "Message"
	echo.	git push
	echo.To amend a commit (before it has been pushed^^^!^):
	echo.	git commit --amend --reset-author -m "New message"
	echo.To see a history of commits:
	echo.	git log
	echo.	git log --graph --oneline
)
if exist "!s_rawOut!node" (
	echo.
	echo.
	echo.Node.js:
	echo.--------
	echo.To use node:
	echo.	node
	echo.To create a new project:
	echo.	npm init
	echo.To download a project's dependencies:
	echo.	npm install
	echo.To install typescript globally:
	echo.	npm install -g typescript
	echo.To create a new typescript project:
	echo.	tsc --init
	echo.To build a typescript project:
	echo.	tsc
)
if exist "!s_rawOut!VSC" (
	echo.
	echo.
	echo.Visual Studio Code:
	echo.-------------------
	echo.To launch VSCode:
	echo.	code
	echo.To install a Vim emulation plugin from the command line:
	echo.	code --install-extension vscodevim.vim
)
echo.
echo.
pause
goto exit


:eval
:: Helper for when you need to use nested delayed expansion (ex. inside a block)
:: Usage example: call :eval c "^!a:~%%b%%^,1^!"
set "%1=%~2"
exit /b

:getFullPath
:: For folders, it is recommended to append \ to the argument
set "%1=%~f2"
exit /b

:getPathOnly
:: For folders, it is recommended to append \ to the argument
set "%1=%~p2"
exit /b

:moveFolderContents
:: Moves all contents in %1 to %2
for /D %%G in ("%~1\*") do move "%%G" "%~2\%%~nG"
for %%G in ("%~1\*.*") do move "%%G" "%~2\%%~nxG"
exit /b

:readCustomVer
set "%1="
set /p "%1=Enter custom version number: "
choice /m "Confirm choice?"
if !ERRORLEVEL!==2 goto readCustomVer
exit /b

:exit
endlocal
exit /b
