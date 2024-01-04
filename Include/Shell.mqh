//+------------------------------------------------------------------+
//|                                                        Shell.mqh |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.0"

#include <WinAPI\processthreadsapi.mqh>

#define SHELL_DIR_PATH    "Shell\\"
#define CREATE_NO_WINDOW  0x08000000
#define WAIT_TIMEOUT      0x00000102

#import "kernel32.dll"
uint GetLastError(void);
int CloseHandle(long hObject);
int WaitForSingleObject(long hHandle, int dwMilliseconds);
#import

#import "user32.dll"
int WaitForInputIdle(long hHandle, int dwMilliseconds);
#import

//+------------------------------------------------------------------+
//| Execute PowerShell command.                                      |
//+------------------------------------------------------------------+
string PShell(string cmd, int timeout_ms = -1) {
    string wrap = "powershell & {Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; %s} *> \"%s\"";
    return _shell(wrap, cmd, timeout_ms);
}

//+------------------------------------------------------------------+
//| Execute CMD command.                                             |
//+------------------------------------------------------------------+
string CShell(string cmd, int timeout_ms = -1) {
    string wrap = "cmd /c \"(%s) > \"%s\" 2>&1\"";
    return _shell(wrap, cmd, timeout_ms);
}

//+------------------------------------------------------------------+
//| Open an application and pass the command.                        |
//+------------------------------------------------------------------+
bool Open(string cmd, int timeout_ms = -1) {
    PROCESS_INFORMATION pi;
    STARTUPINFOW si;
    ZeroMemory(pi);
    ZeroMemory(si);
    si.cb = sizeof(si);
    string dir = GetShellDirAbs();
    if (!CreateProcessW(NULL, cmd, 0, 0, 0, 0, 0, dir, si, pi)) {
        uint err = kernel32::GetLastError();
        PrintFormat("Error (%s, CreateProcess): #%d", __FUNCTION__, err);
        return false;
    }
    int wfs = WaitForSingleObject(pi.hProcess, timeout_ms);
    if (wfs != 0) {
        if (wfs == WAIT_TIMEOUT)
            Print("Warning: waiting for process timed out");
        else
            PrintFormat("Error (%s, WaitForSingleObject): #%d", __FUNCTION__, wfs);
        return false;
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return true;
}

//+------------------------------------------------------------------+
//| Get absolute path of Shell working directory.                    |
//+------------------------------------------------------------------+
string GetShellDirAbs() {
    string abs_dir = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + SHELL_DIR_PATH;
    if (!FileIsExist(SHELL_DIR_PATH, FILE_COMMON)) {
        if (!FolderCreate(SHELL_DIR_PATH, FILE_COMMON)) {
            PrintFormat("Error (%s): #%d", __FUNCTION__, ::GetLastError());
            return NULL;
        }
    }
    return abs_dir;
}

//+------------------------------------------------------------------+
//| Check if OS is Windows.                                          |
//+------------------------------------------------------------------+
bool IsWindows() {
    string os = TerminalInfoString(TERMINAL_OS_VERSION);
    StringToLower(os);
    return(StringFind(os, "windows") != -1);
}

//+------------------------------------------------------------------+
//| Used for the execution of console commands.                      |
//+------------------------------------------------------------------+
string _shell(string wrap, string cmd, int timeout_ms = -1) {
    PROCESS_INFORMATION pi;
    STARTUPINFOW si;
    ZeroMemory(pi);
    ZeroMemory(si);
    si.cb = sizeof(si);

    string dir_abs = GetShellDirAbs();
    string file_name = "ps-" + (string) GetMicrosecondCount();
    string p = dir_abs + file_name;
    string c = StringFormat(wrap, cmd, p);

    if (!CreateProcessW(NULL, c, 0, 0, 0, CREATE_NO_WINDOW, 0, dir_abs, si, pi)) {
        uint err = kernel32::GetLastError();
        PrintFormat("Error (%s, CreateProcess): #%d", __FUNCTION__, err);
        return NULL;
    }

    int wfs = WaitForSingleObject(pi.hProcess, timeout_ms);
    if (wfs != 0) {
        if (wfs == WAIT_TIMEOUT)
            Print("Warning: waiting for process timed out");
        else
            PrintFormat("Error (%s, WaitForSingleObject): #%d", __FUNCTION__, wfs);
        return NULL;
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    int fh = FileOpen(SHELL_DIR_PATH + file_name, FILE_READ | FILE_SHARE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON, CP_UTF8);
    if (fh == INVALID_HANDLE) {
        PrintFormat("Error (%s, FileOpen): #%d", __FUNCTION__, ::GetLastError());
        return NULL;
    }

    string str = "";
    while (!FileIsEnding(fh)) {
        if (IsStopped()) {
            PrintFormat("%s (loop: file) stopped!", __FUNCTION__);
            FileClose(fh);
            return NULL;
        }
        StringAdd(str, FileReadString(fh));
    }
    FileClose(fh);

    if (!FileDelete(SHELL_DIR_PATH + file_name, FILE_COMMON)) {
        PrintFormat("Error (%s, FileDelete): #%d", __FUNCTION__, ::GetLastError());
        return NULL;
    }

    return str;
}

//+------------------------------------------------------------------+
