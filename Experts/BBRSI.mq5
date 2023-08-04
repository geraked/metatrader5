//+------------------------------------------------------------------+
//|                                                   EATemplate.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property description "A strategy using Bollinger Bands and RSI"

#include <EAUtils.mqh>

input int BBLen = 30;
input double BBDev = 2;
input int RSILen = 13;
// -------------------------------
input double SLCoef = 1.5;
input double TPCoef = 1.1;
input bool IgnoreSL = false;
input bool IgnoreTP = true;
input bool CloseOrders = true; // Close on BB Middle
input double Risk = 0.01;
input bool Reverse = false;
input bool Martingale = false;
input double MartingaleRisk = 0.04;
input bool MultipleOpenPos = true;
input int MarginLimit = 300;
input int SpreadLimit = 50;
input int MagicSeed = 1;
input bool OpenNewPos = true;

GerEA ea;
datetime lastCandle;

#define BuffSize 3
#define RSIMiddle 50
#define RSIUpper 70
#define RSILower 30

int BB_handle, RSI_handle;
double BB_U[], BB_L[], BB_M[], RSI[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool c = RSI[2] < RSILower && Close(2) < BB_L[2] && RSI[1] > RSILower && Close(1) > BB_L[1] && RSI[1] < RSIMiddle && Close(1) < BB_M[1];
    if (!c) return false;

    double in = Ask();
    double sl = BB_L[1] - SLCoef * (BB_M[1] - BB_L[1]);
    double tp = in + TPCoef * (in - sl);

    ea.BuyOpen(sl, tp, IgnoreSL, IgnoreTP);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    bool c = RSI[2] > RSIUpper && Close(2) > BB_U[2] && RSI[1] < RSIUpper && Close(1) < BB_U[1] && RSI[1] > RSIMiddle && Close(1) > BB_M[1];
    if (!c) return false;

    double in = Bid();
    double sl = BB_U[1] + SLCoef * (BB_U[1] - BB_M[1]);;
    double tp = in - TPCoef * (sl - in);

    ea.SellOpen(sl, tp, IgnoreSL, IgnoreTP);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose() {
    if (Close(2) <= BB_M[2] && Close(1) > BB_M[1])
        ea.BuyClose();
    if (Close(2) >= BB_M[2] && Close(1) < BB_M[1])
        ea.SellClose();
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

    BB_handle = iBands(NULL, 0, BBLen, 0, BBDev, PRICE_CLOSE);
    RSI_handle = iRSI(NULL, 0, RSILen, PRICE_CLOSE);

    if (BB_handle < 0 || RSI_handle < 0) {
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

        if (CopyBuffer(BB_handle, 0, 0, BuffSize, BB_M) <= 0) return;
        if (CopyBuffer(BB_handle, 1, 0, BuffSize, BB_U) <= 0) return;
        if (CopyBuffer(BB_handle, 2, 0, BuffSize, BB_L) <= 0) return;
        if (CopyBuffer(RSI_handle, 0, 0, BuffSize, RSI) <= 0) return;

        ArraySetAsSeries(BB_M, true);
        ArraySetAsSeries(BB_U, true);
        ArraySetAsSeries(BB_L, true);
        ArraySetAsSeries(RSI, true);

        if (CloseOrders) CheckClose();

        if (!OpenNewPos) return;
        if (Spread() > SpreadLimit) return;
        if (PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if (!MultipleOpenPos && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
