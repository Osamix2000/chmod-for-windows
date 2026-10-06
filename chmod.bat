@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "CHMOD_VERSION=v1.0.0"
set "RECURSIVE=0"
set "VERBOSE=0"
set "CHANGES_ONLY=0"
set "FORCE_QUIET=0"
set "PRESERVE_ROOT=0"
set "FAILURES=0"
set "TARGET_COUNT=0"
set "SUDO_RETRY=0"
set "DENY_WARNED=0"

set "SID_USERS=*S-1-5-32-545"
set "SID_EVERYONE=*S-1-1-0"
set "SID_AUTHENTICATED=*S-1-5-11"
set "SID_ADMINISTRATORS=*S-1-5-32-544"
set "SID_SYSTEM=*S-1-5-18"

for /f "tokens=1,2 delims=," %%A in ('whoami /user /fo csv /nh 2^>nul') do (
	set "ACCOUNT_USER=%%~A"
	set "USER_SID=%%~B"
)
if not defined USER_SID (
	echo chmod: エラー
	echo 現在のユーザーSIDを取得できませんでした。
	exit /b 1
)
set "SID_USER=*%USER_SID%"

for /f "tokens=1,3 delims=," %%A in ('whoami /groups /fo csv /nh 2^>nul') do (
	if /i "%%~B"=="S-1-5-32-545" set "ACCOUNT_USERS=%%~A"
	if /i "%%~B"=="S-1-1-0" set "ACCOUNT_EVERYONE=%%~A"
	if /i "%%~B"=="S-1-5-11" set "ACCOUNT_AUTHENTICATED=%%~A"
)

if "%~1"=="" goto :show_help_error

:parse_options
if "%~1"=="" goto :show_help_error
if /i "%~1"=="--sudo-retry" (
	set "SUDO_RETRY=1"
	shift
	goto :parse_options
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/help" goto :show_help
if /i "%~1"=="/?" goto :show_help
if /i "%~1"=="--version" goto :show_version
if /i "%~1"=="/version" goto :show_version
if /i "%~1"=="-R" (
	set "RECURSIVE=1"
	shift
	goto :parse_options
)
if /i "%~1"=="--recursive" (
	set "RECURSIVE=1"
	shift
	goto :parse_options
)
if /i "%~1"=="/R" (
	set "RECURSIVE=1"
	shift
	goto :parse_options
)
if /i "%~1"=="/recursive" (
	set "RECURSIVE=1"
	shift
	goto :parse_options
)
if /i "%~1"=="-v" (
	set "VERBOSE=1"
	set "CHANGES_ONLY=0"
	shift
	goto :parse_options
)
if /i "%~1"=="--verbose" (
	set "VERBOSE=1"
	set "CHANGES_ONLY=0"
	shift
	goto :parse_options
)
if /i "%~1"=="/v" (
	set "VERBOSE=1"
	set "CHANGES_ONLY=0"
	shift
	goto :parse_options
)
if /i "%~1"=="/verbose" (
	set "VERBOSE=1"
	set "CHANGES_ONLY=0"
	shift
	goto :parse_options
)
if /i "%~1"=="-c" (
	set "CHANGES_ONLY=1"
	set "VERBOSE=0"
	shift
	goto :parse_options
)
if /i "%~1"=="--changes" (
	set "CHANGES_ONLY=1"
	set "VERBOSE=0"
	shift
	goto :parse_options
)
if /i "%~1"=="/c" (
	set "CHANGES_ONLY=1"
	set "VERBOSE=0"
	shift
	goto :parse_options
)
if /i "%~1"=="/changes" (
	set "CHANGES_ONLY=1"
	set "VERBOSE=0"
	shift
	goto :parse_options
)
if /i "%~1"=="-f" (
	set "FORCE_QUIET=1"
	shift
	goto :parse_options
)
if /i "%~1"=="--silent" (
	set "FORCE_QUIET=1"
	shift
	goto :parse_options
)
if /i "%~1"=="--quiet" (
	set "FORCE_QUIET=1"
	shift
	goto :parse_options
)
if /i "%~1"=="/f" (
	set "FORCE_QUIET=1"
	shift
	goto :parse_options
)
if /i "%~1"=="/quiet" (
	set "FORCE_QUIET=1"
	shift
	goto :parse_options
)
if /i "%~1"=="/silent" (
	set "FORCE_QUIET=1"
	shift
	goto :parse_options
)
if /i "%~1"=="--preserve-root" (
	set "PRESERVE_ROOT=1"
	shift
	goto :parse_options
)
if /i "%~1"=="/preserve-root" (
	set "PRESERVE_ROOT=1"
	shift
	goto :parse_options
)
if /i "%~1"=="--no-preserve-root" (
	set "PRESERVE_ROOT=0"
	shift
	goto :parse_options
)
if /i "%~1"=="/no-preserve-root" (
	set "PRESERVE_ROOT=0"
	shift
	goto :parse_options
)
if "%~1"=="--" (
	shift
	goto :read_mode
)

set "OPTION_CHECK=%~1"
if "%OPTION_CHECK:~0,1%"=="-" (
	set "OPTION_SECOND=%OPTION_CHECK:~1,1%"
	if /i "%OPTION_SECOND%"=="r" goto :read_mode
	if /i "%OPTION_SECOND%"=="w" goto :read_mode
	if /i "%OPTION_SECOND%"=="x" goto :read_mode
	if "%OPTION_SECOND%"=="X" goto :read_mode
	if /i "%OPTION_SECOND%"=="s" goto :read_mode
	if /i "%OPTION_SECOND%"=="t" goto :read_mode
	if /i "%OPTION_SECOND%"=="u" goto :read_mode
	if /i "%OPTION_SECOND%"=="g" goto :read_mode
	if /i "%OPTION_SECOND%"=="o" goto :read_mode
	echo chmod: エラー
	echo 不明なオプションです: %~1
	echo 詳細は chmod --help を実行してください。
	exit /b 2
)

:read_mode
if "%~1"=="" goto :show_help_error
set "MODE=%~1"
shift

call :normalize_mode
if errorlevel 1 exit /b 2

if "%~1"=="" (
	echo chmod: エラー
	echo 対象ファイルまたはディレクトリが指定されていません。
	exit /b 2
)

if not "%MODE_TYPE%"=="NUMERIC" goto :mode_ready
set "MODE_U=%MODE:~0,1%"
set "MODE_G=%MODE:~1,1%"
set "MODE_O=%MODE:~2,1%"
set /a "U_NUM=%MODE_U%, G_NUM=%MODE_G%, O_NUM=%MODE_O%" >nul 2>&1
set /a "BAD_G=G_NUM & ~U_NUM, BAD_O=O_NUM & ~G_NUM" >nul 2>&1
if not "%BAD_G%"=="0" call :warn_overlap
if not "%BAD_O%"=="0" call :warn_overlap

:mode_ready

:target_loop
if "%~1"=="" goto :finish

set "RAW_TARGET=%~1"
shift
set /a TARGET_COUNT+=1

call :process_argument
if errorlevel 1 set /a FAILURES+=1
goto :target_loop

:finish
if not "%FAILURES%"=="0" (
	if "%FORCE_QUIET%"=="0" (
		echo chmod: エラー
		echo %TARGET_COUNT% 個の指定のうち %FAILURES% 個でエラーが発生しました。
	)
	exit /b 1
)

if "%VERBOSE%"=="1" (
	echo chmod: 完了
	echo %TARGET_COUNT% 個の指定を処理しました。
)
exit /b 0


:normalize_mode
call :try_normalize_numeric "%MODE%"
set "MODE_RC=%ERRORLEVEL%"
if "%MODE_RC%"=="0" (
	set "MODE_TYPE=NUMERIC"
	set "MODE=%NORMALIZED_NUMERIC%"
	exit /b 0
)
if "%MODE_RC%"=="2" (
	echo chmod: エラー
	echo setuid、setgid、sticky bitに相当する特殊ビットはWindows ACLでは再現できません: %MODE%
	echo 4桁表記を使用する場合、先頭は0にしてください。例: 0755
	exit /b 1
)

call :symbolic_compute "%MODE%" 0 0 0 0 TEST_U TEST_G TEST_O
if errorlevel 1 exit /b 1
set "MODE_TYPE=SYMBOLIC"
exit /b 0


:try_normalize_numeric
setlocal EnableDelayedExpansion
set "TN_ORIGINAL=%~1"
set "TN_REST=%~1"
set /a TN_LEN=0

:tn_loop
if "!TN_REST!"=="" goto :tn_done
set "TN_CH=!TN_REST:~0,1!"
if not "!TN_CH!"=="0" if not "!TN_CH!"=="1" if not "!TN_CH!"=="2" if not "!TN_CH!"=="3" if not "!TN_CH!"=="4" if not "!TN_CH!"=="5" if not "!TN_CH!"=="6" if not "!TN_CH!"=="7" (
	endlocal
	exit /b 1
)
set /a TN_LEN+=1
if !TN_LEN! GTR 4 (
	endlocal
	exit /b 1
)
set "TN_REST=!TN_REST:~1!"
goto :tn_loop

:tn_done
if !TN_LEN! EQU 0 (
	endlocal
	exit /b 1
)
if !TN_LEN! EQU 4 if not "!TN_ORIGINAL:~0,1!"=="0" (
	endlocal
	exit /b 2
)

set "TN_NORMALIZED=!TN_ORIGINAL!"
if !TN_LEN! EQU 1 set "TN_NORMALIZED=00!TN_ORIGINAL!"
if !TN_LEN! EQU 2 set "TN_NORMALIZED=0!TN_ORIGINAL!"
if !TN_LEN! EQU 4 set "TN_NORMALIZED=!TN_ORIGINAL:~1,3!"

endlocal & set "NORMALIZED_NUMERIC=%TN_NORMALIZED%"
exit /b 0


:symbolic_compute
setlocal EnableDelayedExpansion
set "SM_EXPR=%~1"
set /a SM_U=%~2, SM_G=%~3, SM_O=%~4
set "SM_ISDIR=%~5"

if "!SM_EXPR!"=="" goto :sm_invalid
if "!SM_EXPR:~0,1!"=="," goto :sm_invalid
if "!SM_EXPR:~-1!"=="," goto :sm_invalid
if not "!SM_EXPR:,,=!"=="!SM_EXPR!" goto :sm_invalid

:sm_clause_loop
if "!SM_EXPR!"=="" goto :sm_done
for /f "tokens=1* delims=," %%A in ("!SM_EXPR!") do (
	set "SM_CLAUSE=%%A"
	set "SM_EXPR=%%B"
)

set "SM_WHO_U=0"
set "SM_WHO_G=0"
set "SM_WHO_O=0"
set "SM_WHO_SEEN=0"

:sm_who_loop
if "!SM_CLAUSE!"=="" goto :sm_invalid
set "SM_CH=!SM_CLAUSE:~0,1!"
if /i "!SM_CH!"=="u" (
	set "SM_WHO_U=1"
	set "SM_WHO_SEEN=1"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_who_loop
)
if /i "!SM_CH!"=="g" (
	set "SM_WHO_G=1"
	set "SM_WHO_SEEN=1"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_who_loop
)
if /i "!SM_CH!"=="o" (
	set "SM_WHO_O=1"
	set "SM_WHO_SEEN=1"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_who_loop
)
if /i "!SM_CH!"=="a" (
	set "SM_WHO_U=1"
	set "SM_WHO_G=1"
	set "SM_WHO_O=1"
	set "SM_WHO_SEEN=1"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_who_loop
)

if "!SM_WHO_SEEN!"=="0" (
	rem WindowsにはPOSIX umaskがないため、who省略時はaとして扱う。
	set "SM_WHO_U=1"
	set "SM_WHO_G=1"
	set "SM_WHO_O=1"
)

:sm_operation_loop
if "!SM_CLAUSE!"=="" goto :sm_invalid
set "SM_OP=!SM_CLAUSE:~0,1!"
if not "!SM_OP!"=="+" if not "!SM_OP!"=="-" if not "!SM_OP!"=="=" goto :sm_invalid
set "SM_CLAUSE=!SM_CLAUSE:~1!"
set /a SM_MASK=0

:sm_permission_loop
if "!SM_CLAUSE!"=="" goto :sm_apply_operation
set "SM_CH=!SM_CLAUSE:~0,1!"
if "!SM_CH!"=="+" goto :sm_apply_operation
if "!SM_CH!"=="-" goto :sm_apply_operation
if "!SM_CH!"=="=" goto :sm_apply_operation

if /i "!SM_CH!"=="r" (
	set /a "SM_MASK|=4"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_permission_loop
)
if /i "!SM_CH!"=="w" (
	set /a "SM_MASK|=2"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_permission_loop
)
if "!SM_CH!"=="x" (
	set /a "SM_MASK|=1"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_permission_loop
)
if "!SM_CH!"=="X" (
	set /a "SM_ANY_X=(SM_U|SM_G|SM_O)&1"
	if "!SM_ISDIR!"=="1" set /a "SM_MASK|=1"
	if not "!SM_ANY_X!"=="0" set /a "SM_MASK|=1"
	set "SM_CLAUSE=!SM_CLAUSE:~1!"
	goto :sm_permission_loop
)
if /i "!SM_CH!"=="s" goto :sm_special_unsupported
if /i "!SM_CH!"=="t" goto :sm_special_unsupported
if /i "!SM_CH!"=="u" goto :sm_copy_unsupported
if /i "!SM_CH!"=="g" goto :sm_copy_unsupported
if /i "!SM_CH!"=="o" goto :sm_copy_unsupported
goto :sm_invalid

:sm_apply_operation
if "!SM_OP!"=="+" (
	if "!SM_WHO_U!"=="1" set /a "SM_U|=SM_MASK"
	if "!SM_WHO_G!"=="1" set /a "SM_G|=SM_MASK"
	if "!SM_WHO_O!"=="1" set /a "SM_O|=SM_MASK"
)
if "!SM_OP!"=="-" (
	set /a "SM_KEEP=7-SM_MASK"
	if "!SM_WHO_U!"=="1" set /a "SM_U&=SM_KEEP"
	if "!SM_WHO_G!"=="1" set /a "SM_G&=SM_KEEP"
	if "!SM_WHO_O!"=="1" set /a "SM_O&=SM_KEEP"
)
if "!SM_OP!"=="=" (
	if "!SM_WHO_U!"=="1" set /a SM_U=SM_MASK
	if "!SM_WHO_G!"=="1" set /a SM_G=SM_MASK
	if "!SM_WHO_O!"=="1" set /a SM_O=SM_MASK
)

if not "!SM_CLAUSE!"=="" goto :sm_operation_loop
goto :sm_clause_loop

:sm_done
endlocal & set "%~6=%SM_U%" & set "%~7=%SM_G%" & set "%~8=%SM_O%"
exit /b 0

:sm_special_unsupported
endlocal
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo setuid、setgid、sticky bitに相当するs/t指定はWindows ACLでは再現できません: %MODE%
)
exit /b 1

:sm_copy_unsupported
endlocal
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo u/g/oからの権限コピー指定は現在未対応です: %MODE%
)
exit /b 1

:sm_invalid
endlocal
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo シンボリックMODEの形式が正しくありません: %MODE%
	echo 例: +x、u+x、go-rwx、u=rw,go=r、a+rX
)
exit /b 1


:warn_overlap
if defined OVERLAP_WARNED exit /b 0
set "OVERLAP_WARNED=1"
if "%FORCE_QUIET%"=="1" exit /b 0

echo chmod: 警告
echo Windows ACLではowner/group/otherが排他的ではありません。
echo 指定モード %MODE% は完全には再現できないため、ACLの権限和として近似します。
echo 一般的な600、640、644、700、750、755等はこの問題の影響を受けません。
exit /b 0


:process_argument
set "NORMALIZED_TARGET=%RAW_TARGET:/=\%"
set "HOME_DIR=%USERPROFILE%"
if not defined HOME_DIR set "HOME_DIR=%HOMEDRIVE%%HOMEPATH%"

if "%NORMALIZED_TARGET%"=="~" (
	if not defined HOME_DIR (
		if "%FORCE_QUIET%"=="0" (
			echo chmod: エラー
			echo ~を展開するホームディレクトリを取得できませんでした。
		)
		exit /b 1
	)
	set "NORMALIZED_TARGET=%HOME_DIR%"
) else if "%NORMALIZED_TARGET:~0,2%"=="~\" (
	if not defined HOME_DIR (
		if "%FORCE_QUIET%"=="0" (
			echo chmod: エラー
			echo ~を展開するホームディレクトリを取得できませんでした。
		)
		exit /b 1
	)
	set "NORMALIZED_TARGET=%HOME_DIR%\%NORMALIZED_TARGET:~2%"
)

set "ARG_FAILED=0"
set "ARG_MATCHED=0"

for %%I in ("%NORMALIZED_TARGET%") do (
	set "ROOT=%%~fI"
	call :process_root
	if errorlevel 1 set "ARG_FAILED=1"
	set "ARG_MATCHED=1"
)

if "%ARG_MATCHED%"=="0" (
	if "%FORCE_QUIET%"=="0" (
		echo chmod: エラー
		echo 対象を解決できませんでした: %RAW_TARGET%
	)
	exit /b 1
)

if "%ARG_FAILED%"=="1" exit /b 1
exit /b 0


:process_root
if not exist "%ROOT%" (
	if "%FORCE_QUIET%"=="0" (
		echo chmod: エラー
		echo 対象が存在しません: %ROOT%
	)
	exit /b 1
)

for %%I in ("%ROOT%") do (
	set "ROOT_PARENT=%%~dpI"
	set "ROOT_ATTR=%%~aI"
)

set "ROOT_IS_DIR=0"
if "%ROOT_ATTR:~0,1%"=="d" set "ROOT_IS_DIR=1"

if "%RECURSIVE%"=="1" if "%PRESERVE_ROOT%"=="1" (
	call :is_root_path "%ROOT%"
	if not errorlevel 1 (
		if "%FORCE_QUIET%"=="0" (
			echo chmod: エラー
			echo --preserve-rootによりルートへの再帰処理を拒否しました: %ROOT%
			echo 明示的に許可する場合は --no-preserve-root を指定してください。
		)
		exit /b 1
	)
)

set "ACL_BACKUP=%TEMP%\chmod-acl-%RANDOM%-%RANDOM%.txt"

if "%RECURSIVE%"=="1" goto :backup_recursive_check

"%SystemRoot%\System32\icacls.exe" "%ROOT%" /save "%ACL_BACKUP%" /Q >nul 2>&1
goto :backup_complete

:backup_recursive_check
if "%ROOT_IS_DIR%"=="1" (
	"%SystemRoot%\System32\icacls.exe" "%ROOT%" /save "%ACL_BACKUP%" /T /C /Q >nul 2>&1
) else (
	"%SystemRoot%\System32\icacls.exe" "%ROOT%" /save "%ACL_BACKUP%" /Q >nul 2>&1
)

:backup_complete
if errorlevel 1 (
	if exist "%ACL_BACKUP%" del /q "%ACL_BACKUP%" >nul 2>&1
	if "%FORCE_QUIET%"=="0" (
		echo chmod: エラー
		echo ACLのバックアップを作成できませんでした: %ROOT%
	)
	call :try_sudo_retry
	exit /b %ERRORLEVEL%
)

if "%RECURSIVE%"=="1" if "%ROOT_IS_DIR%"=="1" goto :process_recursive_root

set "CURRENT=%ROOT%"
call :apply_current
if errorlevel 1 goto :root_failed
goto :root_success


:process_recursive_root
for /f "usebackq delims=" %%P in (`dir /b /s /a-d "%ROOT%\*" 2^>nul`) do (
	set "CURRENT=%%P"
	call :apply_current
	if errorlevel 1 goto :root_failed
)

for /f "usebackq delims=" %%P in (`dir /b /s /ad "%ROOT%\*" 2^>nul ^| "%SystemRoot%\System32\sort.exe" /R`) do (
	set "CURRENT=%%P"
	call :apply_current
	if errorlevel 1 goto :root_failed
)

set "CURRENT=%ROOT%"
call :apply_current
if errorlevel 1 goto :root_failed
goto :root_success


:root_failed
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo ACL変更に失敗したため、可能な範囲で元のACLへ戻します: %ROOT%
)

"%SystemRoot%\System32\icacls.exe" "%ROOT_PARENT%" /restore "%ACL_BACKUP%" /C /Q >nul 2>&1
if errorlevel 1 (
	if "%FORCE_QUIET%"=="0" (
		echo chmod: エラー
		echo ACLの自動復元にも失敗しました。
		echo 次のバックアップを使用して管理者権限で復元してください:
		echo   %ACL_BACKUP%
		echo ACLの状態が不確定なため、sudoによる自動再実行は行いません。
		echo 管理者としてコマンド プロンプトを開き、ACLを確認してから復元してください。
	)
	exit /b 1
)

del /q "%ACL_BACKUP%" >nul 2>&1
if "%FORCE_QUIET%"=="0" echo 元のACLへ復元しました。
call :try_sudo_retry
exit /b %ERRORLEVEL%


:root_success
del /q "%ACL_BACKUP%" >nul 2>&1
exit /b 0


:apply_current
if not exist "%CURRENT%" exit /b 1

for %%I in ("%CURRENT%") do set "CURRENT_ATTR=%%~aI"
set "IS_DIR=0"
if "%CURRENT_ATTR:~0,1%"=="d" set "IS_DIR=1"

set "HAVE_OLD_MODE=0"
call :get_pseudo_mode
if not errorlevel 1 (
	set "HAVE_OLD_MODE=1"
	set "OLD_MODE=%CUR_U%%CUR_G%%CUR_O%"
)

if "%MODE_TYPE%"=="SYMBOLIC" (
	if "%HAVE_OLD_MODE%"=="0" (
		if "%FORCE_QUIET%"=="0" (
			echo chmod: エラー
			echo 現在のACLを読み取れないため、相対的なシンボリックMODEを適用できません: %CURRENT%
		)
		exit /b 1
	)
	if "%PSEUDO_AMBIGUOUS%"=="1" if "%DENY_WARNED%"=="0" if "%FORCE_QUIET%"=="0" (
		echo chmod: 警告
		echo 明示的なDENY ACLを検出したため、許可ACEを基準にシンボリックMODEを近似します。
		set "DENY_WARNED=1"
	)
	call :symbolic_compute "%MODE%" "%CUR_U%" "%CUR_G%" "%CUR_O%" "%IS_DIR%" NEW_U NEW_G NEW_O
	if errorlevel 1 exit /b 1
) else (
	set "NEW_U=%MODE_U%"
	set "NEW_G=%MODE_G%"
	set "NEW_O=%MODE_O%"
)

set "NEW_MODE=%NEW_U%%NEW_G%%NEW_O%"
set "PSEUDO_CHANGED=1"
if "%HAVE_OLD_MODE%"=="1" if "%OLD_MODE%"=="%NEW_MODE%" set "PSEUDO_CHANGED=0"

rem シンボリックMODEが実質no-opならWindows ACLそのものを触らない。
if "%MODE_TYPE%"=="SYMBOLIC" if "%PSEUDO_CHANGED%"=="0" (
	if "%VERBOSE%"=="1" echo mode of "%CURRENT%" retained as 0%NEW_MODE%
	exit /b 0
)

rem 数値MODEはSSH鍵用途などでACL正規化自体に意味があるため、
rem 擬似MODEが同じでも既存の追加ACEを整理する目的で適用する。
call :permission_from_digit "%NEW_U%" PERM_U "%IS_DIR%"
call :permission_from_digit "%NEW_G%" PERM_G "%IS_DIR%"
call :permission_from_digit "%NEW_O%" PERM_O "%IS_DIR%"

rem 操作中に自分自身を締め出さないため、一時的に現在ユーザーへFull Controlを付与する。
"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /grant:r "%SID_USER%:F" /Q >nul 2>&1
if errorlevel 1 exit /b 1

rem Linux chmodに近づけるため、親から継承したACLを切り離して削除する。
"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /inheritance:r /Q >nul 2>&1
if errorlevel 1 exit /b 1

rem Windowsで広く使われる既定主体を一旦除去し、u/g/oとして再構成する。
"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /remove "%SID_USERS%" "%SID_EVERYONE%" "%SID_AUTHENTICATED%" "%SID_ADMINISTRATORS%" "%SID_SYSTEM%" /Q >nul 2>&1
if errorlevel 1 exit /b 1

if defined PERM_O (
	"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /grant:r "%SID_EVERYONE%:%PERM_O%" /Q >nul 2>&1
	if errorlevel 1 exit /b 1
)

if defined PERM_G (
	"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /grant:r "%SID_USERS%:%PERM_G%" /Q >nul 2>&1
	if errorlevel 1 exit /b 1
)

if defined PERM_U (
	"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /grant:r "%SID_USER%:%PERM_U%" /Q >nul 2>&1
	if errorlevel 1 exit /b 1
) else (
	"%SystemRoot%\System32\icacls.exe" "%CURRENT%" /remove "%SID_USER%" /Q >nul 2>&1
	if errorlevel 1 exit /b 1
)

if "%VERBOSE%"=="1" goto :report_result
if "%CHANGES_ONLY%"=="1" if "%PSEUDO_CHANGED%"=="1" goto :report_result
exit /b 0

:report_result
if "%HAVE_OLD_MODE%"=="1" if "%PSEUDO_CHANGED%"=="0" (
	echo mode of "%CURRENT%" retained as 0%NEW_MODE%
	exit /b 0
)
if "%HAVE_OLD_MODE%"=="1" (
	echo mode of "%CURRENT%" changed from 0%OLD_MODE% to 0%NEW_MODE%
) else (
	echo mode of "%CURRENT%" changed to 0%NEW_MODE%
)
exit /b 0


:get_pseudo_mode
set "PSEUDO_AMBIGUOUS=0"
set "CUR_U=0"
set "CUR_G=0"
set "CUR_O=0"
set "ACL_DUMP=%TEMP%\chmod-current-%RANDOM%-%RANDOM%.txt"

"%SystemRoot%\System32\icacls.exe" "%CURRENT%" > "%ACL_DUMP%" 2>nul
if errorlevel 1 (
	del /q "%ACL_DUMP%" >nul 2>&1
	exit /b 1
)

call :extract_acl_digit "%ACL_DUMP%" "%ACCOUNT_USER%" CUR_U USER_DENY
if errorlevel 1 (
	del /q "%ACL_DUMP%" >nul 2>&1
	exit /b 1
)

set "G_USERS=0"
set "G_AUTH=0"
set "G_USERS_DENY=0"
set "G_AUTH_DENY=0"
set "O_DENY=0"

if defined ACCOUNT_USERS call :extract_acl_digit "%ACL_DUMP%" "%ACCOUNT_USERS%" G_USERS G_USERS_DENY
if defined ACCOUNT_AUTHENTICATED call :extract_acl_digit "%ACL_DUMP%" "%ACCOUNT_AUTHENTICATED%" G_AUTH G_AUTH_DENY
if defined ACCOUNT_EVERYONE call :extract_acl_digit "%ACL_DUMP%" "%ACCOUNT_EVERYONE%" CUR_O O_DENY

set /a "CUR_G=G_USERS|G_AUTH" >nul 2>&1
if "%USER_DENY%"=="1" set "PSEUDO_AMBIGUOUS=1"
if "%G_USERS_DENY%"=="1" set "PSEUDO_AMBIGUOUS=1"
if "%G_AUTH_DENY%"=="1" set "PSEUDO_AMBIGUOUS=1"
if "%O_DENY%"=="1" set "PSEUDO_AMBIGUOUS=1"

del /q "%ACL_DUMP%" >nul 2>&1
exit /b 0


:extract_acl_digit
setlocal EnableDelayedExpansion
set "EA_FILE=%~1"
set "EA_ACCOUNT=%~2"
set /a EA_VALUE=0
set "EA_DENY=0"

if "!EA_ACCOUNT!"=="" (
	endlocal & set "%~3=0" & set "%~4=0"
	exit /b 0
)

for /f "usebackq delims=" %%L in (`"%SystemRoot%\System32\findstr.exe" /l /i /c:"!EA_ACCOUNT!:" "!EA_FILE!" 2^>nul`) do (
	set "EA_LINE=%%L"
	set "EA_TAIL=!EA_LINE!"
	set "EA_IS_DENY=0"
	if not "!EA_TAIL:(DENY)=!"=="!EA_TAIL!" set "EA_IS_DENY=1"
	if "!EA_IS_DENY!"=="1" (
		set "EA_DENY=1"
	) else (
		set "EA_TOKENS=!EA_TAIL:(= !"
		set "EA_TOKENS=!EA_TOKENS:)= !"
		set "EA_TOKENS=!EA_TOKENS:,= !"
		for %%T in (!EA_TOKENS!) do (
			if /i "%%T"=="F" set /a "EA_VALUE|=7"
			if /i "%%T"=="M" set /a "EA_VALUE|=7"
			if /i "%%T"=="GA" set /a "EA_VALUE|=7"
			if /i "%%T"=="RX" set /a "EA_VALUE|=5"
			if /i "%%T"=="R" set /a "EA_VALUE|=4"
			if /i "%%T"=="GR" set /a "EA_VALUE|=4"
			if /i "%%T"=="RD" set /a "EA_VALUE|=4"
			if /i "%%T"=="REA" set /a "EA_VALUE|=4"
			if /i "%%T"=="RA" set /a "EA_VALUE|=4"
			if /i "%%T"=="RC" set /a "EA_VALUE|=4"
			if /i "%%T"=="W" set /a "EA_VALUE|=2"
			if /i "%%T"=="GW" set /a "EA_VALUE|=2"
			if /i "%%T"=="WD" set /a "EA_VALUE|=2"
			if /i "%%T"=="AD" set /a "EA_VALUE|=2"
			if /i "%%T"=="WEA" set /a "EA_VALUE|=2"
			if /i "%%T"=="WA" set /a "EA_VALUE|=2"
			if /i "%%T"=="X" set /a "EA_VALUE|=1"
			if /i "%%T"=="GE" set /a "EA_VALUE|=1"
		)
	)
)

endlocal & set "%~3=%EA_VALUE%" & set "%~4=%EA_DENY%"
exit /b 0


:permission_from_digit
set "%~2="

if "%~1"=="0" exit /b 0
if "%~1"=="1" set "%~2=(GE)"
if "%~1"=="2" set "%~2=(GW)"
if "%~1"=="3" set "%~2=(GW,GE)"
if "%~1"=="4" set "%~2=(GR)"
if "%~1"=="5" set "%~2=(GR,GE)"
if "%~1"=="6" set "%~2=(GR,GW)"
if "%~1"=="7" set "%~2=(GR,GW,GE)"

rem ディレクトリのw+xでは、Linuxの削除・名前変更に近づけるためDelete Childも付与する。
if "%~3"=="1" if "%~1"=="3" set "%~2=(GW,GE,DC)"
if "%~3"=="1" if "%~1"=="7" set "%~2=(GR,GW,GE,DC)"
exit /b 0


:is_root_path
setlocal
set "RP=%~1"
if "%RP:~1,2%"==":\" if "%RP:~3%"=="" (
	endlocal
	exit /b 0
)
if not "%RP:~0,2%"=="\\" (
	endlocal
	exit /b 1
)
set "RP_UNC=%RP:~2%"
for /f "tokens=1,2,* delims=\" %%A in ("%RP_UNC%") do (
	if not "%%~B"=="" if "%%~C"=="" (
		endlocal
		exit /b 0
	)
)
endlocal
exit /b 1


:try_sudo_retry
if "%SUDO_RETRY%"=="1" goto :sudo_already_failed

call :is_elevated
if not errorlevel 1 goto :already_elevated_failed

call :get_sudo_mode
if errorlevel 1 goto :sudo_unavailable

if "%FORCE_QUIET%"=="0" (
	echo chmod: sudo
	echo 権限不足の可能性があるため、Windows sudoで管理者権限として再実行します。
	echo 対象: %ROOT%
	echo.
)

set "SUDO_ARGS="
if "%RECURSIVE%"=="1" set "SUDO_ARGS=%SUDO_ARGS% -R"
if "%VERBOSE%"=="1" set "SUDO_ARGS=%SUDO_ARGS% -v"
if "%CHANGES_ONLY%"=="1" set "SUDO_ARGS=%SUDO_ARGS% -c"
if "%FORCE_QUIET%"=="1" set "SUDO_ARGS=%SUDO_ARGS% -f"
if "%PRESERVE_ROOT%"=="1" set "SUDO_ARGS=%SUDO_ARGS% --preserve-root"

"%SystemRoot%\System32\sudo.exe" "%ComSpec%" /d /c ""%~f0" --sudo-retry%SUDO_ARGS% "%MODE%" "%ROOT%""
if errorlevel 1 goto :sudo_process_failed

if "%VERBOSE%"=="1" (
	echo chmod: sudo
	echo Windows sudoによる再実行が完了しました: %ROOT%
)
exit /b 0


:sudo_already_failed
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo Windows sudoで管理者権限として再実行しましたが、ACL変更に失敗しました。
	echo 対象: %ROOT%
	echo 所有者、明示的なDENY ACL、ファイルシステム、または対象が使用中でないか確認してください。
)
exit /b 1


:already_elevated_failed
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo 既に管理者権限で実行されていますが、ACL変更に失敗しました。
	echo 対象: %ROOT%
	echo 所有者、明示的なDENY ACL、ファイルシステム、または対象が使用中でないか確認してください。
)
exit /b 1


:sudo_unavailable
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo Windows sudoが無効、未搭載、または利用できないため自動再実行できません。
	echo 管理者としてコマンド プロンプトを開いて再実行してください。
	echo 対象: %ROOT%
)
exit /b 1


:sudo_process_failed
if "%FORCE_QUIET%"=="0" (
	echo chmod: エラー
	echo Windows sudoによる再実行に失敗しました。
	echo UACがキャンセルされた、sudoを実行できないユーザーである、または管理者権限でもACLを変更できない可能性があります。
	echo 対象: %ROOT%
)
exit /b 1


:is_elevated
"%SystemRoot%\System32\whoami.exe" /groups 2>nul | "%SystemRoot%\System32\findstr.exe" /c:"S-1-16-12288" /c:"S-1-16-16384" >nul
if errorlevel 1 exit /b 1
exit /b 0


:get_sudo_mode
if not exist "%SystemRoot%\System32\sudo.exe" exit /b 1

set "SUDO_MODE="
for /f "tokens=3" %%S in ('"%SystemRoot%\System32\reg.exe" query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" /v Enabled 2^>nul ^| "%SystemRoot%\System32\findstr.exe" /i "Enabled"') do set "SUDO_MODE=%%S"

if not defined SUDO_MODE exit /b 1
set /a "SUDO_MODE_DEC=%SUDO_MODE%" >nul 2>&1
if errorlevel 1 exit /b 1
if "%SUDO_MODE_DEC%"=="0" exit /b 1
if %SUDO_MODE_DEC% LSS 1 exit /b 1
if %SUDO_MODE_DEC% GTR 3 exit /b 1
exit /b 0


:show_version
echo chmod %CHMOD_VERSION%
exit /b 0


:show_help_error
echo chmod: エラー
echo MODEと対象を指定してください。
echo 詳細は chmod --help を実行してください。
exit /b 2


:show_help
echo 【chmod %CHMOD_VERSION% - Windows ACL chmod互換ラッパー】
echo 使用法:
echo   chmod [OPTION] MODE FILE...
echo.
echo MODE:
echo   0～777            1～3桁の8進数MODEに対応
echo   0000～0777        先頭0付き4桁表記にも対応
echo   +x                who省略時はaとして扱い、実行権限を追加
echo   u+x               owner相当へ実行権限を追加
echo   go-rwx            group/other相当からrwxを削除
echo   u=rw,go=r         複数のシンボリックMODEをカンマ区切りで指定
echo   a+rX              ディレクトリまたは既にxがある対象へxを追加
echo.
echo OPTION:
echo   -R, --recursive   ディレクトリ配下を再帰的に変更
echo   -c, --changes     実際にMODEが変化した対象だけ表示
echo   -v, --verbose     変更有無を含め対象ごとに表示
echo   -f, --quiet       ほとんどのエラー、警告、補助表示を抑制
echo       --silent      --quietと同じ
echo       --preserve-root
echo                     -R指定時、ドライブ/UNC共有のルートを拒否
echo       --no-preserve-root
echo                     ルート保護を無効化 ^(既定^)
echo       --version     バージョンを表示
echo       --help        このヘルプを表示
echo.
echo パス:
echo   Windows形式の\とLinux風の/の両方を使用できます。
echo   入力された/は内部で\へ変換されます。
echo   先頭の~は現在ユーザーのホームディレクトリへ展開されます。
echo.
echo 例:
echo   chmod 600 "~/.ssh/id_ed25519"
echo   chmod 600 "~\.ssh\id_ed25519"
echo   chmod 600 "%%userprofile%%/.ssh/id_ed25519"
echo   chmod +x "example.sh"
echo   chmod u=rw,go= "C:/keys/private_key"
echo   chmod -R a+rX "C:/tools"
echo   chmod -c 644 "C:/work/config.txt"
echo   chmod -R --preserve-root 755 "C:/tools/bin"
echo.
echo Windows ACLとの対応:
echo   u = 現在のユーザー
echo   g = BUILTIN\UsersおよびAuthenticated Usersを基準に近似
echo   o = Everyone
echo   whoを省略したシンボリックMODEはWindowsにPOSIX umaskがないためaとして扱います。
echo.
echo 注意:
echo   setuid、setgid、sticky bitにはWindows ACL上の直接対応がないため未対応です。
echo   u/g/oから権限をコピーするg=u等は現在未対応です。
echo   Windows ACLはPOSIX permissionと構造が異なるため、一部のACLは近似になります。
echo   ACL変更前にicaclsでバックアップし、途中失敗時は可能な範囲で自動復元します。
exit /b 0
