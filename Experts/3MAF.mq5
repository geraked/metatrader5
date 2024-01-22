//+------------------------------------------------------------------+
//|                                                         3MAF.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.4"
#property description "A simple strategy using three Moving Averages and Williams Fractals"
#property description "USDCAD-15M  2021.02.22 - 2023.09.08"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int MA1Len = 60; // MA1 Period
input int MA2Len = 350; // MA2 Period
input int MA3Len = 600; // MA3 Period
input ENUM_MA_METHOD MaMethod = MODE_EMA; // MA Method
input ENUM_APPLIED_PRICE MaPrice = PRICE_CLOSE; // MA Price

input group "General"
input int MinSL = 100; // Minimum SL (Points)
input double TPCoef = 1.5; // TP Coefficient
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk (%)
input bool IgnoreSL = true; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.5; // Grid Volume Multiplier
input double GridTrailingStopLevel = 40; // Grid Trailing Stop Level (%) (0: Disable)
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
input int TimerInterval = 60; // Timer Interval (Seconds)
input ulong MagicNumber = 3000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

int BuffSize = 5;

GerEA ea;
datetime lastCandle;
datetime tc;

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
    double d = MathAbs(in - sl);
    double tp = in + TPCoef * d;

    if (d < MinSL * _Point) return false;

    ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP);
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
    double d = MathAbs(in - sl);
    double tp = in - TPCoef * d;

    if (d < MinSL * _Point) return false;

    ea.SellOpen(in, sl, tp, IgnoreSL, IgnoreTP);
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
    ea.grid = Grid;
    ea.gridVolMult = GridVolMult;
    ea.gridMaxLvl = GridMaxLvl;
    ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    ea.slippage = Slippage;
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;
    ea.filling = Filling;

    if (News) fetchCalendarFromYear(NewsStartYear);

    MA1_handle = iMA(NULL, 0, MA1Len, 0, MaMethod, MaPrice);
    MA2_handle = iMA(NULL, 0, MA2Len, 0, MaMethod, MaPrice);
    MA3_handle = iMA(NULL, 0, MA3Len, 0, MaMethod, MaPrice);
    FR_handle = iFractals(NULL, 0);

    if (MA1_handle == INVALID_HANDLE || MA2_handle == INVALID_HANDLE || MA3_handle == INVALID_HANDLE || FR_handle == INVALID_HANDLE) {
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

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}

//+------------------------------------------------------------------+
