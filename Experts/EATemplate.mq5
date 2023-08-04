//+------------------------------------------------------------------+
//|                                                   EATemplate.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#include <EAUtils.mqh>



// -------------------------------
input double SLCoef = 1.0;
input double TPCoef = 1.0;
input bool IgnoreSL = false;
input bool IgnoreTP = false;
input bool CloseOrders = true;
input int BuffSize = 512;
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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {

    return false;

    double in = Ask();
    double sl = 0;
    double tp = 0;

    ea.BuyOpen(sl, tp, IgnoreSL, IgnoreTP);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {

    return false;

    double in = Bid();
    double sl = 0;
    double tp = 0;

    ea.SellOpen(sl, tp, IgnoreSL, IgnoreTP);
    return true;
}


void CheckClose() {

}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init(MagicSeed);

//if (ea.IsAuthorized())
//    Print("AHSANT");
//else
//    return INIT_FAILED;

    ea.risk = Risk;
    ea.reverse = Reverse;
    ea.martingale = Martingale;
    ea.martingaleRisk = MartingaleRisk;

    return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

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
