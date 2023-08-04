//+------------------------------------------------------------------+
//|                                                         3MAF.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property description "A simple strategy using three Moving Averages and Williams Fractals for scalping."

#include <EAUtils.mqh>

input int MA1Len = 20;
input int MA2Len = 50;
input int MA3Len = 100;
input ENUM_MA_METHOD MaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE MaPrice = PRICE_CLOSE;
// -------------------------------
input double TPCoef = 1.5;
input double Risk = 0.01;
input bool Reverse = false;
input bool Martingale = false;
input double MartingaleRisk = 0.04;
input bool MultipleOpenPos = true;
input int MagicSeed = 1;

GerEA ea;
datetime lastCandle;

#define BuffSize 5
int MA1_handle, MA2_handle, MA3_handle, FR_handle;
double MA1[], MA2[], MA3[], FR_U[], FR_D[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool lower = FR_D[2] != EMPTY_VALUE;
    bool c = MA1[1] > MA2[1] && MA2[1] > MA3[1] && Low(1) > MA3[1] && Low(1) < MA1[1] && lower;
    if (!c) return false;

    double in = Ask();
    double sl = Low(1) > MA2[1] ? MA2[1] : MA3[1];
    double tp = in + TPCoef * (in - sl);

    ea.BuyOpen(sl, tp);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    bool upper = FR_U[2] != EMPTY_VALUE;
    bool c = MA3[1] > MA2[1] && MA2[1] > MA1[1] && High(1) < MA3[1] && High(1) > MA1[1] && upper;
    if (!c) return false;

    double in = Bid();
    double sl = High(1) < MA2[1] ? MA2[1] : MA3[1];
    double tp = in - TPCoef * (sl - in);

    ea.SellOpen(sl, tp);
    return true;
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init(MagicSeed);
    ea.risk = Risk;
    ea.reverse = Reverse;
    ea.martingale = Martingale;
    ea.martingaleRisk = MartingaleRisk;

    MA1_handle = iMA(NULL, 0, MA1Len, 0, MaMethod, MaPrice);
    MA2_handle = iMA(NULL, 0, MA2Len, 0, MaMethod, MaPrice);
    MA3_handle = iMA(NULL, 0, MA3Len, 0, MaMethod, MaPrice);
    FR_handle = iFractals(NULL, 0);

    if (MA1_handle < 0 || MA2_handle < 0 || MA3_handle < 0 || FR_handle < 0) {
        Print("Runtime error = ", GetLastError());
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        if (CopyBuffer(MA1_handle, 0, 0, BuffSize, MA1) <= 0) return;
        if (CopyBuffer(MA2_handle, 0, 0, BuffSize, MA2) <= 0) return;
        if (CopyBuffer(MA3_handle, 0, 0, BuffSize, MA3) <= 0) return;
        if (CopyBuffer(FR_handle, 0, 0, BuffSize, FR_U) <= 0) return;
        if (CopyBuffer(FR_handle, 1, 0, BuffSize, FR_D) <= 0) return;

        ArraySetAsSeries(MA1, true);
        ArraySetAsSeries(MA2, true);
        ArraySetAsSeries(MA3, true);
        ArraySetAsSeries(FR_U, true);
        ArraySetAsSeries(FR_D, true);

        if (!MultipleOpenPos && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
