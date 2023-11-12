//+------------------------------------------------------------------+
//|                                                        BBRSI.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.3"
#property description "A strategy using Bollinger Bands and RSI"
#property description "XAUUSD-5M  2021.02.26 - 2023.09.15"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int BBLen = 500; // BB Period
input double BBDev = 2; // BB Deviations
input int RSILen = 7; // RSI Period

input group "General"
input double SLCoef = 0.9; // SL Coefficient
input double TPCoef = 1; // TP Coefficient
input bool CloseOrders = false; // Check For Closing Conditions
input bool CloseOnProfit = true; // Close Only On Profit
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk (%)
input bool IgnoreSL = true; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.1; // Grid Volume Multiplier
input double GridTrailingStopLevel = 0; // Grid Trailing Stop Level (%) (0: Disable)
input int GridMaxLvl = 20; // Grid Max Levels

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
input ulong MagicNumber = 1000; // Magic Number

GerEA ea;
datetime lastCandle;
datetime tc;

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
    bool c = RSI[2] > RSIUpper && Close(2) > BB_U[2] && RSI[1] < RSIUpper && Close(1) < BB_U[1] && RSI[1] > RSIMiddle && Close(1) > BB_M[1];
    if (!c) return false;

    double in = Bid();
    double sl = BB_U[1] + SLCoef * (BB_U[1] - BB_M[1]);
    double d = MathAbs(in - sl);
    double tp = in - TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.SellOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, _Digits));
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

    if (Close(2) <= BB_M[2] && Close(1) > BB_M[1])
        ea.BuyClose();
    if (Close(2) >= BB_M[2] && Close(1) < BB_M[1])
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

    if (News) fetchCalendarFromYear(NewsStartYear);

    BB_handle = iBands(NULL, 0, BBLen, 0, BBDev, PRICE_CLOSE);
    RSI_handle = iRSI(NULL, 0, RSILen, PRICE_CLOSE);

    if (BB_handle == INVALID_HANDLE || RSI_handle == INVALID_HANDLE) {
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
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}

//+------------------------------------------------------------------+
