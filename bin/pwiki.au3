#include <MsgBoxConstants.au3>
#include <FileConstants.au3>

Global $sPROJECT_NAME = "docker-web-wiki"

;~ ---------------------

;~ MsgBox($MB_SYSTEMMODAL, "Title", "This message box will timeout after 10 seconds or select the OK button.", 10)
Local $sWorkingDir = @WorkingDir

;~ ---------------------

Local $result = 0

$result = ShellExecuteWait('WHERE', 'git', "", "open", @SW_HIDE)
If $result = 1 then
	MsgBox($MB_SYSTEMMODAL, "Environment Setting", "Please install GIT.")
	ShellExecute("https://git-scm.com/downloads", "", "open", @SW_HIDE)
	Exit
EndIf

$result = ShellExecuteWait('WHERE', 'docker-compose', "", "open", @SW_HIDE)
If $result = 1 then
	MsgBox($MB_SYSTEMMODAL, "Environment Setting", "Please install Docker Desktop.")
	ShellExecute("https://docs.docker.com/compose/install/", "", "open", @SW_HIDE)
	Exit
EndIf

$result = ShellExecuteWait('docker', 'version', "", "open", @SW_HIDE)
If $result = 1 then
	MsgBox($MB_SYSTEMMODAL, "Environment Setting", "Please start Docker Desktop.")
	Exit
EndIf

;~ ---------------------

;Local $sProjectFolder = @TempDir & "\" & $sPROJECT_NAME
Local $sProjectFolder = @HomeDrive & @HomePath & "\docker-app\" & $sPROJECT_NAME
;~ MsgBox($MB_SYSTEMMODAL, FileExists($sProjectFolder), $sProjectFolder)
If Not FileExists($sProjectFolder) Then
	FileChangeDir(@HomeDrive & @HomePath & "\docker-app\")
	ShellExecuteWait("git", "clone https://github.com/pulipulichen/" & $sPROJECT_NAME & ".git")
	FileChangeDir($sProjectFolder)
Else
	FileChangeDir($sProjectFolder)
	ShellExecuteWait("git", "reset --hard", "", "open", @SW_HIDE)
	ShellExecuteWait("git", "pull --force", "", "open", @SW_HIDE)
EndIf

;~ ---------------------

Local $sProjectFolderCache = $sProjectFolder & ".cache"
If Not FileExists($sProjectFolderCache) Then
	DirCreate($sProjectFolderCache)
EndIf

$result = ShellExecuteWait("fc", '"' & $sProjectFolder & "\Dockerfile" & '" "' & $sProjectFolderCache & "\Dockerfile" & '"', "", "open", @SW_HIDE)
If $result = 1 then
	ShellExecuteWait("docker-compose", "build")
	FileCopy($sProjectFolder & "\Dockerfile", $sProjectFolderCache & "\Dockerfile", $FC_OVERWRITE)
EndIf

$result = ShellExecuteWait("fc", '"' & $sProjectFolder & "\package.json" & '" "' & $sProjectFolderCache & "\package.json" & '"', "", "open", @SW_HIDE)
If $result = 1 then
	ShellExecuteWait("docker-compose", "build")
EndIf

FileCopy($sProjectFolder & "\Dockerfile", $sProjectFolderCache & "\Dockerfile", $FC_OVERWRITE)
FileCopy($sProjectFolder & "\package.json", $sProjectFolderCache & "\package.json", $FC_OVERWRITE)

;~ =================================================================
;~ 從docker-compose-template.yml來判斷參數

Local $INPUT_FILE = 0

If FileExists($sProjectFolder & "\docker-compose-template.yml") Then
  Local $fileContent = FileRead($sProjectFolder "\docker-compose-template.yml")
  If StringInStr($fileContent, "[INPUT]") Then
    $INPUT_FILE = 1
  EndIf
EndIf

;~ ---------------------

Local $PUBLIC_PORT = 0

Local $DOCKER_COMPOSE_FILE = $sProjectFolder &  "\docker-compose.yml"
If Not FileExists($DOCKER_COMPOSE_FILE) Then
  $DOCKER_COMPOSE_FILE = $sProjectFolder & "\docker-compose-template.yml"
EndIf

If FileExists($DOCKER_COMPOSE_FILE) Then
  Local $fileContent = FileRead($DOCKER_COMPOSE_FILE)
  Local $pattern = "ports:"
  Local $lines = StringSplit($fileContent, @CRLF)

  Local $flag = False
  For $i = 1 To $lines[0]
      If StringInStr($lines[$i], $pattern) Then
          $flag = True
      EndIf

      If $flag Then
        Local $portMatch = StringRegExp($lines[$i], '"[0-9]+:[0-9]+"', 3)
        If IsArray($portMatch) Then
          Local $portSplit = StringSplit(StringTrimRight(StringTrimLeft($portMatch[0], 1), 1), ':')
          $PUBLIC_PORT = $portSplit[1]
          ExitLoop
        EndIf
      EndIf
  Next
EndIf

;~ ---------------------
;~ 選取檔案

Global $sFILE_EXT = "* (*.*)"

Local $sUseParams = true
Local $sFiles[]
If $INPUT_FILE = 1 Then
	If $CmdLine[0] = 0 Then
		$sUseParams = false
		Local $sMessage = "Select File"
		Local $sFileOpenDialog = FileOpenDialog($sMessage, @DesktopDir & "\", $sFILE_EXT , $FD_FILEMUSTEXIST + $FD_MULTISELECT)
		$sFiles = StringSplit($sFileOpenDialog, "|")
	EndIf
EndIf

;~ =================================================================
;~ 宣告函數

Func getCloudflarePublicURL()
    Local $dirname = @ScriptDir

    Local $cloudflare_file = $dirname & "\" & $PROJECT_NAME & "\.cloudflare.url"

    While Not FileExists($cloudflare_file)
        Sleep(1000) ; Check every 1 second
    WEnd

    Local $fileContent = FileRead($cloudflare_file)
    Return $fileContent
EndFunc

;~ ----------------------------------------------------------------

Func setDockerComposeYML($file)
    Local $dirname = StringLeft($file, StringInStr($file, "\", 0, -1) - 1)
    Local $filename = StringMid($file, StringInStr($file, "\", 0, -1) + 1)

    Local $template = FileRead($sProjectFolder & "\docker-compose-template.yml")
    $template = StringReplace($template, "[SOURCE]", $dirname)
    $template = StringReplace($template, "[INPUT]", $filename)

    FileWrite($sProjectFolder & "\docker-compose.yml", $template)
EndFunc

;~ ----------------------------------------------------------------

Func waitForConnection($port)
    Sleep(3000) ; Wait for 3 seconds

    While True
        $curlOutput = Run(@ComSpec & ' /c curl -sSf "http://127.0.0.1:' & $port & '" > nul 2>&1', @SystemDir, @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD)

        If $curlOutput = 0 Then
            ConsoleWrite("Connection successful." & @CRLF)
            ExitLoop
        Else
            ; ConsoleWrite("Connection failed. Retrying in 5 seconds..." & @CRLF)
            Sleep(5000)
        EndIf
    WEnd
EndFunc

;~ ----------------------------------------------------------------

Func runDockerCompose()
	If $PUBLIC_PORT = 0 then
		docker-compose up --build
		Exit(1)
	Else
		sudo docker-compose up --build -d
	EndIf

	waitForConnection($PUBLIC_PORT)
	Local $cloudflare_url=getCloudflarePublicURL()

	Sleep(10000)

	ConsoleWrite("================================================================" & @CRLF)
	ConsoleWrite("You can link the website via following URL:" & @CRLF)
	ConsoleWrite(@CRLF)

	ConsoleWrite($cloudflare_url & @CRLF)
	ConsoleWrite("http://127.0.0.1:" & $PUBLIC_PORT & @CRLF)

	ConsoleWrite(@CRLF)
	ConsoleWrite("Press Ctrl+C to stop the Docker container and exit." & @CRLF)
	ConsoleWrite("================================================================" & @CRLF)
	
	While True
    Sleep(5000) ; Sleep for 1 second (1000 milliseconds)
	WEnd
EndFunc

;~ ---------------------

If $INPUT_FILE = 1 Then 
	If $sUseParams = true Then
		For $i = 1 To $CmdLine[0]
			If Not FileExists($CmdLine[$i]) Then
				If Not FileExists($sWorkingDir & "/" & $CmdLine[$i]) Then
					MsgBox($MB_SYSTEMMODAL, $sPROJECT_NAME, "File not found: " & $CmdLine[$i])
				Else
					; ShellExecuteWait("node", $sProjectFolder & "\index.js" & ' "' & $sWorkingDir & "/" & $CmdLine[$i] & '"')	
					setDockerComposeYML('"' & $sWorkingDir & "/" & $CmdLine[$i] & '"')
					runDockerCompose()
				EndIf
			Else
				; ShellExecuteWait("node", $sProjectFolder & "\index.js" & ' "' & $CmdLine[$i] & '"')
				setDockerComposeYML('"' & $CmdLine[$i] & '"')
				runDockerCompose()
			EndIf
		Next
	Else
		For $i = 1 To $sFiles[0]
			FileChangeDir($sProjectFolder)
			; ShellExecuteWait("node", $sProjectFolder & "\index.js" & ' "' & $sFiles[$i] & '"')
			setDockerComposeYML('"' & $sFiles[$i] & '"')
			runDockerCompose()
		Next
	EndIf
Else
	FileChangeDir($sProjectFolder)
	setDockerComposeYML('"' & @ScriptDir & '"')
	runDockerCompose()
EndIf