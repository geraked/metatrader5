//+------------------------------------------------------------------+
//|                                                    NWERSIASF.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.4"
#property description "A strategy using Nadaraya-Watson Envelope, RSI, and ATR Stop Loss Finder indicators"
#property description "Multiple Symbols(USDCAD, AUDUSD, EURCHF)-2H  2019.01.01 - 2023.10.22"

#include <EAUtils.mqh>

#define PATH_ASF "Indicators\\AtrSlFinder.ex5"
#define I_ASF "::" + PATH_ASF
#resource "\\" + PATH_ASF

#define PATH_NWE "Indicators\\NadarayaWatsonEnvelope.ex5"
#define I_NWE "::" + PATH_NWE
#resource "\\" + PATH_NWE

input group "Indicator Parameters"
input double NweBandWidth = 8.0; // NWE Band Width
input double NweMultiplier = 3.0; // NWE Multiplier
input int NweWindowSize = 500; // NWE Window Size
input int RsiLength = 5; // RSI Length
input int AsfLength = 14; // ASF Length
input double AsfMultiplier = 0.75; // ASF Multiplier

input group "General"
input bool MultipleSymbol = true; // Multiple Symbols
input string Symbols = "USDCAD, AUDUSD, EURCHF"; // Symbols
input double TPCoef = 1.5; // TP Coefficient
input int MinPosInterval = 4; // Minimum New Position Interval
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 1.2; // Risk
input ENUM_RISK RiskMode = RISK_DEFAULT; // Risk Mode
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

input group "News"
input bool News = false; // News Enable
input ENUM_NEWS_IMPORTANCE NewsImportance = NEWS_IMPORTANCE_MEDIUM; // News Importance
input int NewsMinsBefore = 60; // News Minutes Before
input int NewsMinsAfter = 60; // News Minutes After
input int NewsStartYear = 0; // News Start Year to Fetch for Backtesting (0: Disable)

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = true; // Allow Having Multiple Open Positions
input double MarginLimit = 4000; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 120; // Timer Interval (Seconds)
input ulong MagicNumber = 1002; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime tc;
string symbols[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NWE(string symbol, int bi = 0, int i = -1) {
    int handle = iCustom(symbol, 0, I_NWE, NweBandWidth, NweMultiplier, NweWindowSize);
    if (i == -1) return -1;
    return Ind(handle, i, bi);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RSI(string symbol, int i = -1) {
    int handle = iRSI(symbol, 0, RsiLength, PRICE_CLOSE);
    if (i == -1) return -1;
    return Ind(handle, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ASF(string symbol, int bi = 0, int i = -1) {
    int handle = iCustom(symbol, 0, I_ASF, AsfLength, AsfMultiplier);
    if (i == -1) return -1;
    return Ind(handle, i, bi);
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

        if (ea.OPTotal(s) > 0) continue;
        if (hasDealRecently(ea.GetMagic(), s, MinPosInterval)) continue;
        if (SpreadLimit != -1 && Spread(s) > SpreadLimit) continue;

        double c1 = Close(1, s);
        double o1 = Open(1, s);
        double h2 = High(2, s);
        double l2 = Low(2, s);
        double up1 = NWE(s, 0, 1);
        double up2 = NWE(s, 0, 2);
        double dn1 = NWE(s, 1, 1);
        double dn2 = NWE(s, 1, 2);
        double rsi = RSI(s, 2);
        double asfUp = ASF(s, 0, 1);
        double asfDn = ASF(s, 1, 1);

        if (up1 == -1 || dn1 == -1 || up2 == -1 || dn2 == -1 || rsi == -1 || asfUp == -1 || asfDn == -1) continue;

        bool bc = l2 < dn2 && c1 > o1 && Ask(s) < dn1 + 0.5 * (up1 - dn1) && rsi < 30;
        bool sc = h2 > up2 && c1 < o1 && Bid(s) > up1 - 0.5 * (up1 - dn1) && rsi > 70;

        if (bc) {
            double in = Ask(s);
            double sl = asfDn;
            double tp = in + TPCoef * MathAbs(in - sl);
            ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP, s);
            Sleep(5000);
        }

        else if (sc) {
            double in = Bid(s);
            double sl = asfUp;
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
    ea.riskMode = RiskMode;

    if (RiskMode == RISK_FIXED_VOL || RiskMode == RISK_MIN_AMOUNT) ea.risk = Risk;
    if (News) fetchCalendarFromYear(NewsStartYear);
    fillSymbols(symbols, MultipleSymbol, Symbols);

    int n = ArraySize(symbols);
    for (int i = 0; i < n; i++) {
        string s = symbols[i];
        NWE(s);
        RSI(s);
        ASF(s);
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
    CheckForSignal();
}

//+------------------------------------------------------------------+
