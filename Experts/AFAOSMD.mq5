//+------------------------------------------------------------------+
//|                                                      AFAOSMD.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.1"
#property description "A strategy using Average Force, Andean Oscillator, and MACD"
#property description "NZDCAD-30M  2019.01.01 - 2023.10.22"

#include <EAUtils.mqh>

#define PATH_AF "Indicators\\AverageForce.ex5"
#define I_AF "::" + PATH_AF
#resource "\\" + PATH_AF

#define PATH_AOS "Indicators\\AndeanOscillator.ex5"
#define I_AOS "::" + PATH_AOS
#resource "\\" + PATH_AOS
enum ENUM_AOS_BI {
    AOS_BI_BULL,
    AOS_BI_BEAR,
    AOS_BI_SIGNAL
};

input group "Indicator Parameters"
input int AfPeriod = 20; // Average Force Period
input int AfSmooth = 9; // Average Force Smooth
input int AosPeriod = 50; // Andean Oscillator Period
input int AosSignalPeriod = 9; // Andean Oscillator Signal Period
input int MdFast = 100; // MACD Fast
input int MdSlow = 200; // MACD Slow

input group "General"
input double TPCoef = 1.0; // TP Coefficient
input int SLLookback = 7; // SL Look Back
input int SLDev = 60; // SL Deviation (Points)
input bool Reverse = true; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk (%)
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.1; // Grid Volume Multiplier
input double GridTrailingStopLevel = 0; // Grid Trailing Stop Level (%) (0: Disable)
input int GridMaxLvl = 20; // Grid Max Levels

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = true; // Allow Having Multiple Open Positions
input double MarginLimit = 300; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30; // Timer Interval (Seconds)
input ulong MagicNumber = 1001; // Magic Number

GerEA ea;
datetime lastCandle;
datetime tc;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AF(int i = 0) {
    int handle;
    double B[];
    handle = iCustom(NULL, 0, I_AF, AfPeriod, AfSmooth);
    if (handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return -1;
    }
    if (CopyBuffer(handle, 0, 0, i + 1, B) <= 0) return -1;
    ArraySetAsSeries(B, true);
    return B[i];
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AOS(ENUM_AOS_BI bi = 0, int i = 0) {
    int handle;
    double B[];
    handle = iCustom(NULL, 0, I_AOS, AosPeriod, AosSignalPeriod);
    if (handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return -1;
    }
    if (CopyBuffer(handle, bi, 0, i + 1, B) <= 0) return -1;
    ArraySetAsSeries(B, true);
    return B[i];
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MD(int i = 0) {
    int handle;
    double B[];
    handle = iMACD(NULL, 0, MdFast, MdSlow, 1, PRICE_CLOSE);
    if (handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return -1;
    }
    if (CopyBuffer(handle, 0, 0, i + 1, B) <= 0) return -1;
    ArraySetAsSeries(B, true);
    return B[i];
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    if (!(AOS(AOS_BI_BULL, 1) > AOS(AOS_BI_BEAR, 1))) return false;
    if (!(AF(2) < 0 && AF(1) > 0)) return false;
    if (!(MD(2) > 0 && MD(1) > 0)) return false;
    if (!(MD(2) < MD(1))) return false;

    double in = Ask();
    int il = iLowest(NULL, 0, MODE_LOW, SLLookback, 1);
    double sl = Low(il) - SLDev * _Point;
    double d = MathAbs(in - sl);
    double tp = in + TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.BuyOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, _Digits));
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    if (!(AOS(AOS_BI_BULL, 1) < AOS(AOS_BI_BEAR, 1))) return false;
    if (!(AF(2) > 0 && AF(1) < 0)) return false;
    if (!(MD(2) < 0 && MD(1) < 0)) return false;
    if (!(MD(2) > MD(1))) return false;

    double in = Bid();
    int ih = iHighest(NULL, 0, MODE_HIGH, SLLookback, 1);
    double sl = High(ih) + SLDev * _Point;
    double d = MathAbs(in - sl);
    double tp = in - TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.SellOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, _Digits));
    return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init();
    ea.SetMagic(MagicNumber);
    ea.risk = Risk * 0.01;
    ea.reverse = Reverse;
    ea.trailingStopLevel = TrailingStopLevel * 0.01;
    ea.gridVolMult = GridVolMult;
    ea.gridTrailingStopLevel = GridTrailingStopLevel * 0.01;
    ea.gridMaxLvl = GridMaxLvl;
    ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    ea.slippage = Slippage;

    EventSetTimer(TimerInterval);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = TimeCurrent();
    if (tc == oldTc) return;

    if (Trail) ea.CheckForTrail();
    if (EquityDrawdownLimit) ea.CheckForEquity();
    if (Grid) ea.CheckForGrid();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
