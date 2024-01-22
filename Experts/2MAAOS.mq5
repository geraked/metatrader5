//+------------------------------------------------------------------+
//|                                                       2MAAOS.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.3"
#property description "A strategy using two Moving Averages and Andean Oscillator"
#property description "Multiple Symbols(EURUSD, EURCAD, USDCAD)-4H  2019.01.01 - 2023.10.17"

#include <EAUtils.mqh>

#define PATH_AOS "Indicators\\AndeanOscillator.ex5"
#define I_AOS "::" + PATH_AOS
#resource "\\" + PATH_AOS
enum ENUM_AOS_BI {
    AOS_BI_BULL,
    AOS_BI_BEAR,
    AOS_BI_SIGNAL
};

input group "Indicator Parameters"
input int AosPeriod = 50; // Andean Oscillator Period
input int AosSignalPeriod = 9; // Andean Oscillator Signal Period
input int FastMaPeriod = 50; // Fast MA Period
input int SlowMaPeriod = 200; // Slow MA Period
input ENUM_MA_METHOD MaMethod = MODE_SMA; // MA Method
input ENUM_APPLIED_PRICE MaPrice = PRICE_CLOSE; // MA Price

input group "General"
input bool MultipleSymbol = true; // Multiple Symbols
input string Symbols = "EURUSD, EURCAD, USDCAD"; // Symbols
input double TPCoef = 1; // TP Coefficient
input ENUM_SL SLType = SL_SWING; // SL Type
input int SLLookback = 10; // SL Look Back
input int SLDev = 100; // SL Deviation (Points)
input int MinPosInterval = 6; // Minimum New Position Interval
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 5.5; // Risk (%)
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.3; // Grid Volume Multiplier
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
input bool MultipleOpenPos = true; // Allow Having Multiple Open Positions
input double MarginLimit = 5000; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 120; // Timer Interval (Seconds)
input ulong MagicNumber = 1000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime tc;
string symbols[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MA(string symbol, int ma_period, int i = 0) {
    int handle;
    double B[];
    handle = iMA(symbol, 0, ma_period, 0, MaMethod, MaPrice);
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
double AOS(string symbol, ENUM_AOS_BI bi = 0, int i = 0) {
    int handle;
    double B[];
    handle = iCustom(symbol, 0, I_AOS, AosPeriod, AosSignalPeriod);
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
void CheckForSignal() {
    if (!OpenNewPos) return;
    if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
    if (!MultipleOpenPos && ea.PosTotal() > 0) return;

    int n = ArraySize(symbols);
    for (int i = 0; i < n; i++) {

        string s = symbols[i];
        double point = SymbolInfoDouble(s, SYMBOL_POINT);
        int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);

        if (positionsTotalMagic(ea.GetMagic(), s) > 0) continue;
        if (hasDealRecently(ea.GetMagic(), s, MinPosInterval)) continue;
        if (SpreadLimit != -1 && Spread(s) > SpreadLimit) continue;

        bool bc = AOS(s, AOS_BI_BULL, 2) <= AOS(s, AOS_BI_SIGNAL, 2) && AOS(s, AOS_BI_BULL, 1) > AOS(s, AOS_BI_SIGNAL, 1);
        bool sc = AOS(s, AOS_BI_BEAR, 2) <= AOS(s, AOS_BI_SIGNAL, 2) && AOS(s, AOS_BI_BEAR, 1) > AOS(s, AOS_BI_SIGNAL, 1);

        bc = bc && AOS(s, AOS_BI_BULL, 1) > AOS(s, AOS_BI_BEAR, 1);
        sc = sc && AOS(s, AOS_BI_BULL, 1) < AOS(s, AOS_BI_BEAR, 1);

        double fma1 = MA(s, FastMaPeriod, 1);
        double sma1 = MA(s, SlowMaPeriod, 1);
        double diff = MathAbs(fma1 - sma1);

        bc = bc && fma1 > sma1;
        sc = sc && fma1 < sma1;

        bc = bc && Ask(s) > fma1 - 0.5 * diff;
        sc = sc && Bid(s) < fma1 + 0.5 * diff;

        if (bc) {
            double in = Ask(s);
            double sl = BuySL(SLType, SLLookback, in, SLDev, 0, s);
            double tp = in + TPCoef * MathAbs(in - sl);
            ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP, s);
            Sleep(5000);
        }

        else if (sc) {
            double in = Bid(s);
            double sl = SellSL(SLType, SLLookback, in, SLDev, 0, s);
            double tp = in - TPCoef * MathAbs(in - sl);
            ea.SellOpen(in, sl, tp, IgnoreSL, IgnoreTP, s);
            Sleep(5000);
        }

    }
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
    fillSymbols(symbols, MultipleSymbol, Symbols);
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
    CheckForSignal();
}

//+------------------------------------------------------------------+
