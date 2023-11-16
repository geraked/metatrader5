//+------------------------------------------------------------------+
//|                                                       LRCUTB.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.2"
#property description "A strategy using Linear Regression Candles and UT Bot Alerts"
#property description "AUDCAD-15M  2019.01.01 - 2023.10.30"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int LrLen = 11; // LRC Period
input int LrSmaLen = 7; // LRC Signal Period
input double UtbAtrCoef = 2; // UTB ATR Coefficient (Sensitivity)
input int UtbAtrLen = 1; // UTB ATR Period

input group "General"
input int SLLookback = 10; // SL Look Back
input int SLDev = 100; // SL Deviation (Points)
input bool CloseOrders = false; // Check For Closing Conditions
input bool CloseOnProfit = true; // Close Only On Profit
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 0.6; // Risk (%)
input bool IgnoreSL = false; // Ignore SL
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.2; // Grid Volume Multiplier
input double GridTrailingStopLevel = 0; // Grid Trailing Stop Level (%) (0: Disable)
input int GridMaxLvl = 50; // Grid Max Levels

input group "News"
input bool News = false; // News Enable
input ENUM_NEWS_IMPORTANCE NewsImportance = NEWS_IMPORTANCE_MEDIUM; // News Importance
input int NewsMinsBefore = 60; // News Minutes Before
input int NewsMinsAfter = 60; // News Minutes After
input int NewsStartYear = 0; // News Start Year to Fetch for Backtesting (0: Disable)

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = false; // Allow Having Multiple Open Positions
input double MarginLimit = 300; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30; // Timer Interval (Seconds)
input ulong MagicNumber = 1003; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime lastCandle;
datetime tc;
int BuffSize;

#define PATH_LRC "Indicators\\LinearRegressionCandles.ex5"
#define I_LRC "::" + PATH_LRC
#resource "\\" + PATH_LRC
int LRC_handle;
double LRC_O[], LRC_C[], LRC_S[];

#define PATH_UTB "Indicators\\UTBot.ex5"
#define I_UTB "::" + PATH_UTB
#resource "\\" + PATH_UTB
int UTB_handle;
double UTB_BULL[], UTB_BEAR[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    if (!(LRC_C[1] > LRC_O[1] && LRC_C[1] > LRC_S[1])) return false;

    bool c = false;
    for (int i = 1; i < 4; i++) {
        if (UTB_BULL[i]) {
            c = true;
            break;
        }
    }
    if (!c) return false;

    double in = Ask();
    int il = iLowest(NULL, 0, MODE_LOW, SLLookback);
    double sl = Low(il) - SLDev * _Point;
    double d = MathAbs(in - sl);
    double tp = 0;
    bool isl = Grid ? true : IgnoreSL;

    ea.BuyOpen(sl, tp, isl, true, DoubleToString(d, _Digits));
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    if (!(LRC_C[1] < LRC_O[1] && LRC_C[1] < LRC_S[1])) return false;

    bool c = false;
    for (int i = 1; i < 4; i++) {
        if (UTB_BEAR[i]) {
            c = true;
            break;
        }
    }
    if (!c) return false;

    double in = Bid();
    int ih = iHighest(NULL, 0, MODE_HIGH, SLLookback);
    double sl = High(ih) + SLDev * _Point;
    double d = MathAbs(in - sl);
    double tp = 0;
    bool isl = Grid ? true : IgnoreSL;

    ea.SellOpen(sl, tp, isl, true, DoubleToString(d, _Digits));
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose() {
    if (CloseOnProfit) {
        double p = getProfit(ea.GetMagic()) - calcCost(ea.GetMagic());
        if (p < 0) return;
    }

    if (LRC_C[2] > LRC_O[2] && LRC_C[1] < LRC_O[1])
        ea.BuyClose();
    if (LRC_C[2] < LRC_O[2] && LRC_C[1] > LRC_O[1])
        ea.SellClose();
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
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;
    ea.filling = Filling;

    if (News) fetchCalendarFromYear(NewsStartYear);

    BuffSize = 4;

    LRC_handle = iCustom(NULL, 0, I_LRC, LrLen, LrSmaLen);
    UTB_handle = iCustom(NULL, 0, I_UTB, UtbAtrCoef, UtbAtrLen);

    if (LRC_handle == INVALID_HANDLE || UTB_handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return INIT_FAILED;
    }

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

        if (CopyBuffer(LRC_handle, 0, 0, BuffSize, LRC_O) <= 0) return;
        if (CopyBuffer(LRC_handle, 3, 0, BuffSize, LRC_C) <= 0) return;
        if (CopyBuffer(LRC_handle, 5, 0, BuffSize, LRC_S) <= 0) return;
        ArraySetAsSeries(LRC_O, true);
        ArraySetAsSeries(LRC_C, true);
        ArraySetAsSeries(LRC_S, true);

        if (CopyBuffer(UTB_handle, 0, 0, BuffSize, UTB_BULL) <= 0) return;
        if (CopyBuffer(UTB_handle, 1, 0, BuffSize, UTB_BEAR) <= 0) return;
        ArraySetAsSeries(UTB_BULL, true);
        ArraySetAsSeries(UTB_BEAR, true);

        if (CloseOrders) CheckClose();

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}

//+------------------------------------------------------------------+
