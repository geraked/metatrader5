//+------------------------------------------------------------------+
//|                                                      CEZLSMA.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.00"
#property description "A Strategy Using Chandelier Exit and ZLSMA Indicators Based on the Heikin Ashi Candles"

#include <EAUtils.mqh>

input int CeAtrPeriod = 1; // CE ATR Period
input double CeAtrMult = 0.75; // CE ATR Multiplier
input int ZlPeriod = 50; // ZLSMA Period
// -------------------------------
input int SLDev = 30; // SL Deviation (Points)
input bool IgnoreSL = false;
input double Risk = 0.01;
input bool MultipleOpenPos = true;
input int SpreadLimit = 50;
input int MagicSeed = 1;

#define BuffSize 4

#define PATH_HA "Indicators\\Examples\\Heiken_Ashi.ex5"
#define I_HA "::" + PATH_HA
#resource "\\" + PATH_HA
int HA_handle;
double HA_C[];

#define PATH_CE "Indicators\\ChandelierExit.ex5"
#define I_CE "::" + PATH_CE
#resource "\\" + PATH_CE
int CE_handle;
double CE_B[], CE_S[];

#define PATH_ZL "Indicators\\ZLSMA.ex5"
#define I_ZL "::" + PATH_ZL
#resource "\\" + PATH_ZL
int ZL_handle;
double ZL[];

GerEA ea;
datetime lastCandle;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool c = CE_B[1] != 0 && HA_C[1] > ZL[1];
    if (!c) return false;

    double in = Ask();
    double sl = CE_B[1] - SLDev * _Point;

    ea.BuyOpen(sl, 0, IgnoreSL, true);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    bool c = CE_S[1] != 0 && HA_C[1] < ZL[1];
    if (!c) return false;

    double in = Bid();
    double sl = CE_S[1] + SLDev * _Point;

    ea.SellOpen(sl, 0, IgnoreSL, true);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose() {
    if (HA_C[2] >= ZL[2] && HA_C[1] < ZL[1])
        ea.BuyClose();

    if (HA_C[2] <= ZL[2] && HA_C[1] > ZL[1])
        ea.SellClose();
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init(MagicSeed);
    ea.risk = Risk;

    HA_handle = iCustom(NULL, 0, I_HA);
    CE_handle = iCustom(NULL, 0, I_CE, CeAtrPeriod, CeAtrMult);
    ZL_handle = iCustom(NULL, 0, I_ZL, ZlPeriod, true);

    if (HA_handle < 0 || CE_handle < 0 || ZL_handle < 0) {
        Print("Runtime error = ", GetLastError());
        return(INIT_FAILED);
    }

    return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        if (CopyBuffer(HA_handle, 3, 0, BuffSize, HA_C) <= 0) return;
        ArraySetAsSeries(HA_C, true);

        if (CopyBuffer(CE_handle, 0, 0, BuffSize, CE_B) <= 0) return;
        if (CopyBuffer(CE_handle, 1, 0, BuffSize, CE_S) <= 0) return;
        ArraySetAsSeries(CE_B, true);
        ArraySetAsSeries(CE_S, true);

        if (CopyBuffer(ZL_handle, 0, 0, BuffSize, ZL) <= 0) return;
        ArraySetAsSeries(ZL, true);

        CheckClose();

        if (Spread() > SpreadLimit) return;
        if (!MultipleOpenPos && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
