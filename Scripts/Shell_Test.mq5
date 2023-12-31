//+------------------------------------------------------------------+
//|                                                   Shell_Test.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#include <Shell.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {

//- Tested on Windows 10 with PowerShell v5.1

    Print("***** Test 1 (Echo command): ");
    Print("PShell: ", PShell("echo 'Hello World!'"));
    Print("CShell: ", CShell("echo Hello World!"));
    Print("");

    Print("***** Test 2 (Get system time): ");
    Print("PShell: ", PShell("Get-Date -Format G"));
    Print("CShell: ", CShell("time /t"));
    Print("");

    Print("***** Test 3 (Get system info): ");
    Print("PShell (PowerShell version): ", PShell("$PSVersionTable.PSVersion.ToString()"));
    Print("PShell (OS version): ", PShell("[System.Environment]::OSVersion.VersionString"));
    Print("");

    Print("***** Test 4 (Get public and local IP addresses): ");
    Print("PShell (public IP): ", PShell("[Net.ServicePointManager]::SecurityProtocol = 'Tls, Tls11, Tls12, Ssl3'; "
                                         "(Invoke-WebRequest ident.me).content"));
    Print("PShell (local IP): ", PShell("(Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne 'Disconnected'}).IPv4Address.IPAddress"));
    Print("");
}

//+------------------------------------------------------------------+
