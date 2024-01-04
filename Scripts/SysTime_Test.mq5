//+------------------------------------------------------------------+
//|                                                 SysTime_Test.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#include <SysTime.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    Print("TimeSystem:      ", TimeSystem());
    Print("TimeSystemLocal: ", TimeSystemLocal());
    Print("TimeCurrent:     ", TimeCurrent());
    Print("TimeTradeServer: ", TimeTradeServer());
    Print("TimeGMT:         ", TimeGMT());
    Print("TimeLocal:       ", TimeLocal());
}

//+------------------------------------------------------------------+
