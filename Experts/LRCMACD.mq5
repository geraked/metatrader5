//+------------------------------------------------------------------+
//|                                                      LRCMACD.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.0"
#property description "A strategy using Linear Regression Candles and MACD"
#property description "https://youtu.be/je6vGA30gcQ"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int LrLen = 11; // LRC Period
input int LrSmaLen = 5; // LRC Signal Period
input int MacdFast = 34; // MACD Fast
input int MacdSlow = 144; // MACD Slow

input group "General"
input bool MultipleSymbol = false; // Multiple Symbols
input string Symbols = ""; // Symbols
input double TPCoef = 1.0; // TP Coefficient
input int SLLookback = 10; // SL Lookback
input int SLDev = 60; // SL Deviation (Points)
input int PullbackLookback = 4; // Pullback Lookback
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk (%)
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.5; // Grid Volume Multiplier
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
input double MarginLimit = 300; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30; // Timer Interval (Seconds)
input ulong MagicNumber = 1000; // Magic Number

GerEA ea;
datetime tc;
datetime lastCandles[];
string symbols[];

#define PATH_LRC "Indicators\\LinearRegressionCandles.ex5"
#define I_LRC "::" + PATH_LRC
#resource "\\" + PATH_LRC
enum ENUM_LRC_BI {
    LRC_BI_OPEN,
    LRC_BI_HIGH,
    LRC_BI_LOW,
    LRC_BI_CLOSE,
    LRC_BI_COLOR,
    LRC_BI_SIGNAL
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LRC(string symbol, ENUM_TIMEFRAMES tf = 0, ENUM_LRC_BI bi = 0, int i = 0) {
    int handle;
    double B[];
    handle = iCustom(symbol, tf, I_LRC, LrLen, LrSmaLen);
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
double MD(string symbol, ENUM_TIMEFRAMES tf = 0, int i = 0) {
    int handle;
    double B[];
    handle = iMACD(symbol, tf, MacdFast, MacdSlow, 1, PRICE_CLOSE);
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
bool BuySignal(string s) {
    double lrc_c1 = LRC(s, 0, LRC_BI_CLOSE, 1);
    double lrc_c2 = LRC(s, 0, LRC_BI_CLOSE, 2);
    double lrc_o1 = LRC(s, 0, LRC_BI_OPEN, 1);
    double lrc_o2 = LRC(s, 0, LRC_BI_OPEN, 2);
    double lrc_s1 = LRC(s, 0, LRC_BI_SIGNAL, 1);
    double lrc_s2 = LRC(s, 0, LRC_BI_SIGNAL, 2);
    double md1 = MD(s, 0, 1);
    double md2 = MD(s, 0, 2);

    if (lrc_s1 == -1 || lrc_s2 == -1 || md1 == -1 || md2 == -1) return false;
    if (!(md1 > 0 && md2 > 0 && lrc_c1 > lrc_o1 && lrc_c1 > lrc_s1)) return false;
    if (!(lrc_c2 <= lrc_s2)) return false;
    if (!(lrc_c2 > lrc_o2)) return false;

    int j = 0;
    for (int i = 2; i < PullbackLookback + 2; i++) {
        double mdi = MD(s, 0, i);
        double lrc_ci = LRC(s, 0, LRC_BI_CLOSE, i);
        double lrc_oi = LRC(s, 0, LRC_BI_OPEN, i);
        if (mdi == -1 || lrc_ci == -1) return false;
        if (mdi <= 0) return false;
        if (lrc_ci < lrc_oi) {
            j = i;
            break;
        }
    }
    if (!j) return false;

    for (int i = j; i < j + PullbackLookback; i++) {
        double mdi = MD(s, 0, i);
        double lrc_ci = LRC(s, 0, LRC_BI_CLOSE, i);
        double lrc_oi = LRC(s, 0, LRC_BI_OPEN, i);
        if (mdi == -1 || lrc_ci == -1) return false;
        if (mdi <= 0) return false;
        if (lrc_ci > lrc_oi) {
            return false;
        }
    }

    double point = SymbolInfoDouble(s, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);
    double in = Ask(s);
    int il = iLowest(s, 0, MODE_LOW, SLLookback);
    double sl = iLow(s, 0, il) - SLDev * point;
    double d = MathAbs(in - sl);
    double tp = in + TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.BuyOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, digits), s);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal(string s) {
    double lrc_c1 = LRC(s, 0, LRC_BI_CLOSE, 1);
    double lrc_c2 = LRC(s, 0, LRC_BI_CLOSE, 2);
    double lrc_o1 = LRC(s, 0, LRC_BI_OPEN, 1);
    double lrc_o2 = LRC(s, 0, LRC_BI_OPEN, 2);
    double lrc_s1 = LRC(s, 0, LRC_BI_SIGNAL, 1);
    double lrc_s2 = LRC(s, 0, LRC_BI_SIGNAL, 2);
    double md1 = MD(s, 0, 1);
    double md2 = MD(s, 0, 2);

    if (lrc_s1 == -1 || lrc_s2 == -1 || md1 == -1 || md2 == -1) return false;
    if (!(md1 < 0 && md2 < 0 && lrc_c1 < lrc_o1 && lrc_c1 < lrc_s1)) return false;
    if (!(lrc_c2 >= lrc_s2)) return false;
    if (!(lrc_c2 < lrc_o2)) return false;

    int j = 0;
    for (int i = 2; i < PullbackLookback + 2; i++) {
        double mdi = MD(s, 0, i);
        double lrc_ci = LRC(s, 0, LRC_BI_CLOSE, i);
        double lrc_oi = LRC(s, 0, LRC_BI_OPEN, i);
        if (mdi == -1 || lrc_ci == -1) return false;
        if (mdi >= 0) return false;
        if (lrc_ci > lrc_oi) {
            j = i;
            break;
        }
    }
    if (!j) return false;

    for (int i = j; i < j + PullbackLookback; i++) {
        double mdi = MD(s, 0, i);
        double lrc_ci = LRC(s, 0, LRC_BI_CLOSE, i);
        double lrc_oi = LRC(s, 0, LRC_BI_OPEN, i);
        if (mdi == -1 || lrc_ci == -1) return false;
        if (mdi >= 0) return false;
        if (lrc_ci < lrc_oi) {
            return false;
        }
    }

    double point = SymbolInfoDouble(s, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);
    double in = Bid(s);
    int ih = iHighest(s, 0, MODE_HIGH, SLLookback);
    double sl = iHigh(s, 0, ih) + SLDev * point;
    double d = MathAbs(in - sl);
    double tp = in - TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.SellOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, digits), s);
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
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;

    if (News) fetchCalendarFromYear(NewsStartYear);
    fillSymbols(symbols, MultipleSymbol, Symbols);
    ArrayResize(lastCandles, ArraySize(symbols));
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
    int n = ArraySize(symbols);
    for (int i = 0; i < n; i++) {
        string s = symbols[i];

        datetime t = iTime(s, 0, 0);
        if (lastCandles[i] == t) continue;
        else lastCandles[i] = t;

        if (!OpenNewPos) break;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) break;
        if (!MultipleOpenPos && ea.PosTotal() > 0) break;
        if (SpreadLimit != -1 && Spread(s) > SpreadLimit) continue;
        if (positionsTotalMagic(ea.GetMagic(), s) > 0) continue;

        if (BuySignal(s)) continue;
        SellSignal(s);
    }
}

//+------------------------------------------------------------------+
