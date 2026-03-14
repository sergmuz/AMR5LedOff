program LedOffAuto;

{$APPTYPE GUI}

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils;

type
  TCmd3 = packed array[0..2] of Byte;

  {$IF NOT DECLARED(TOKEN_ELEVATION)}
  TOKEN_ELEVATION = record
    TokenIsElevated: DWORD;
  end;
  {$IFEND}

const
  {$IF NOT DECLARED(TokenElevation)}
  TokenElevation = 20;
  {$IFEND}

  DEVICE_PATH = '\\.\inpoutx64';
  IOCTL_CODE  = DWORD($9C402008);
  TASK_NAME   = 'LedOffAuto';

  DEVICE_RETRIES    = 5;
  DEVICE_RETRY_WAIT = 600;

  LedOffCmds: array[0..59] of TCmd3 = (
    ($4E, $00, $2E), ($4F, $00, $11), ($4E, $00, $2F), ($4F, $00, $04),
    ($4E, $00, $2E), ($4F, $00, $10), ($4E, $00, $2F), ($4F, $00, $BD),
    ($4E, $00, $2E), ($4F, $00, $12), ($4E, $00, $2F), ($4F, $00, $01),

    ($4E, $00, $2E), ($4F, $00, $11), ($4E, $00, $2F), ($4F, $00, $04),
    ($4E, $00, $2E), ($4F, $00, $10), ($4E, $00, $2F), ($4F, $00, $BF),
    ($4E, $00, $2E), ($4F, $00, $12), ($4E, $00, $2F), ($4F, $00, $00),

    ($4E, $00, $2E), ($4F, $00, $11), ($4E, $00, $2F), ($4F, $00, $04),
    ($4E, $00, $2E), ($4F, $00, $10), ($4E, $00, $2F), ($4F, $00, $5C),
    ($4E, $00, $2E), ($4F, $00, $12), ($4E, $00, $2F), ($4F, $00, $00),

    ($4E, $00, $2E), ($4F, $00, $11), ($4E, $00, $2F), ($4F, $00, $04),
    ($4E, $00, $2E), ($4F, $00, $10), ($4E, $00, $2F), ($4F, $00, $BE),
    ($4E, $00, $2E), ($4F, $00, $12), ($4E, $00, $2F), ($4F, $00, $07),

    ($4E, $00, $2E), ($4F, $00, $11), ($4E, $00, $2F), ($4F, $00, $04),
    ($4E, $00, $2E), ($4F, $00, $10), ($4E, $00, $2F), ($4F, $00, $BE),
    ($4E, $00, $2E), ($4F, $00, $12), ($4E, $00, $2F), ($4F, $00, $03)
  );

var
  LogFile: string;
  LogStarted: Boolean = False;

procedure WriteLog(const Msg: string);
var
  F: TextFile;
begin
  try
    AssignFile(F, LogFile);
    if not LogStarted then
    begin
      // First write in this session: overwrite old log
      Rewrite(F);
      LogStarted := True;
    end
    else
    begin
      if FileExists(LogFile) then
        Append(F)
      else
        Rewrite(F);
    end;
    WriteLn(F, FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Msg);
    CloseFile(F);
  except
  end;
end;

// ---------------------------------------------------------------------------

function CreateHiddenProcess(const CmdLine: string; out ExitCode: DWORD): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
begin
  Result := False;
  ExitCode := DWORD(-1);

  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  ZeroMemory(@PI, SizeOf(PI));

  Cmd := CmdLine;
  UniqueString(Cmd);

  if not CreateProcess(nil, PChar(Cmd), nil, nil, False,
           CREATE_NO_WINDOW, nil, nil, SI, PI) then
  begin
    WriteLog('CreateProcess FAILED: ' + CmdLine + ' err=' + IntToStr(GetLastError));
    Exit;
  end;

  try
    WaitForSingleObject(PI.hProcess, 10000);
    if not GetExitCodeProcess(PI.hProcess, ExitCode) then
      ExitCode := DWORD(-1);
    Result := True;
    WriteLog('Process done: exitcode=' + IntToStr(ExitCode) + ' cmd=' + CmdLine);
  finally
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end;
end;

function IsRunAsAdmin: Boolean;
var
  TokenHandle: THandle;
  Elev: TOKEN_ELEVATION;
  Size: DWORD;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, TokenHandle) then
  begin
    WriteLog('OpenProcessToken FAILED err=' + IntToStr(GetLastError));
    Exit;
  end;
  try
    Size := 0;
    if GetTokenInformation(TokenHandle,
         TTokenInformationClass(TokenElevation),
         @Elev, SizeOf(Elev), Size) then
      Result := (Elev.TokenIsElevated <> 0);
  finally
    CloseHandle(TokenHandle);
  end;
  WriteLog('IsRunAsAdmin = ' + BoolToStr(Result, True));
end;

function RelaunchAsAdmin: Boolean;
var
  SEI: TShellExecuteInfo;
begin
  WriteLog('RelaunchAsAdmin: requesting UAC...');
  ZeroMemory(@SEI, SizeOf(SEI));
  SEI.cbSize       := SizeOf(SEI);
  SEI.fMask        := SEE_MASK_NOCLOSEPROCESS;
  SEI.lpVerb       := 'runas';
  SEI.lpFile       := PChar(ParamStr(0));
  SEI.lpParameters := '/install';
  SEI.nShow        := SW_HIDE;

  Result := ShellExecuteEx(@SEI);
  if not Result then
  begin
    WriteLog('ShellExecuteEx FAILED err=' + IntToStr(GetLastError));
    Exit;
  end;

  WriteLog('UAC accepted, waiting for elevated process...');
  if SEI.hProcess <> 0 then
  begin
    WaitForSingleObject(SEI.hProcess, 15000);
    CloseHandle(SEI.hProcess);
  end;
  WriteLog('Elevated process finished');
end;

// ---------------------------------------------------------------------------

function TaskExists: Boolean;
var
  ExitCode: DWORD;
begin
  CreateHiddenProcess(
    'schtasks.exe /Query /TN "' + TASK_NAME + '"', ExitCode);
  Result := (ExitCode = 0);
  WriteLog('TaskExists = ' + BoolToStr(Result, True));
end;

function CreateTask: Boolean;
var
  ExePath, Cmd: string;
  ExitCode: DWORD;
begin
  ExePath := ParamStr(0);
  Cmd :=
    'schtasks.exe /Create' +
    ' /TN "' + TASK_NAME + '"' +
    ' /TR "\"' + ExePath + '\""' +
    ' /SC ONLOGON' +
    ' /DELAY 0000:05' +
    ' /RL HIGHEST' +
    ' /F';
  WriteLog('CreateTask: ' + Cmd);
  Result := CreateHiddenProcess(Cmd, ExitCode) and (ExitCode = 0);
  WriteLog('CreateTask result = ' + BoolToStr(Result, True));
end;

// ---------------------------------------------------------------------------

procedure EnsureScheduledTask;
begin
  if TaskExists then
  begin
    WriteLog('Task already exists, skipping');
    Exit;
  end;

  if IsRunAsAdmin then
  begin
    WriteLog('We have admin rights, creating task...');
    CreateTask;
  end
  else
  begin
    WriteLog('No admin rights, relaunching with UAC...');
    RelaunchAsAdmin;
  end;
end;

// ---------------------------------------------------------------------------

function OpenDevice(out H: THandle): Boolean;
var
  Attempt: Integer;
  Err: DWORD;
begin
  H := 0;
  for Attempt := 1 to DEVICE_RETRIES do
  begin
    H := CreateFile(PChar(DEVICE_PATH), GENERIC_WRITE, 0, nil,
           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if H <> INVALID_HANDLE_VALUE then
    begin
      WriteLog('Device opened on attempt ' + IntToStr(Attempt));
      Exit(True);
    end;
    Err := GetLastError;
    WriteLog('OpenDevice attempt ' + IntToStr(Attempt) +
             ' FAILED err=' + IntToStr(Err));
    H := 0;
    Sleep(DEVICE_RETRY_WAIT);
  end;
  WriteLog('OpenDevice: ALL attempts failed');
  Result := False;
end;

function SendCmd(H: THandle; const Cmd: TCmd3): Boolean;
var
  BytesReturned: DWORD;
begin
  BytesReturned := 0;
  Result := DeviceIoControl(H, IOCTL_CODE, @Cmd[0], SizeOf(Cmd),
              nil, 0, BytesReturned, nil);
end;

procedure DoLedOff;
var
  H: THandle;
  I, Pass: Integer;
  Ok: Boolean;
begin
  WriteLog('DoLedOff: opening device...');
  if not OpenDevice(H) then
  begin
    WriteLog('DoLedOff: ABORT - device not opened');
    Exit;
  end;
  try
    WriteLog('DoLedOff: sending commands...');
    for Pass := 1 to 3 do
    begin
      for I := Low(LedOffCmds) to High(LedOffCmds) do
      begin
        Ok := SendCmd(H, LedOffCmds[I]);
        if not Ok then
          WriteLog('SendCmd FAIL pass=' + IntToStr(Pass) +
                   ' idx=' + IntToStr(I) +
                   ' err=' + IntToStr(GetLastError));
        Sleep(2);
      end;
      Sleep(80);
    end;
    WriteLog('DoLedOff: DONE');
  finally
    CloseHandle(H);
  end;
end;

// ---------------------------------------------------------------------------
//  Entry point - two separate try/except blocks.
//  Even if scheduled task setup fails, LED will still be turned off.
// ---------------------------------------------------------------------------
begin
  LogFile := ChangeFileExt(ParamStr(0), '.log');
  WriteLog('=== START === exe=' + ParamStr(0));

  // Block 1: auto-start setup (may fail - not critical)
  try
    EnsureScheduledTask;
  except
    on E: Exception do
      WriteLog('TASK EXCEPTION: ' + E.ClassName + ': ' + E.Message);
  end;

  // Block 2: turn off LED (always runs, even if block 1 failed)
  try
    DoLedOff;
  except
    on E: Exception do
      WriteLog('LED EXCEPTION: ' + E.ClassName + ': ' + E.Message);
  end;

  WriteLog('=== END ===');
end.
