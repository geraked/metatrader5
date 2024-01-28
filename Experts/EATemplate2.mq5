//+------------------------------------------------------------------+
//|                                                  EATemplate2.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.0"
#property description "A strategy using..."
#property description ""

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int P1 = 0;

input group "General"
input bool MultipleSymbol = false; // Multiple Symbols
input string Symbols = ""; // Symbols
input double TPCoef = 1.0; // TP Coefficient
input ENUM_SL SLType = SL_SWING; // SL Type
input int SLLookback = 10; // SL Lookback
input int SLDev = 60; // SL Deviation (Points)
input bool CloseOrders = true; // Check For Closing Conditions
input bool CloseOnProfit = false; // Close Only On Profit
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk
input ENUM_RISK RiskMode = RISK_DEFAULT; // Risk Mode
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = false; // Ignore TP
input bool Trail = false; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = false; // Grid Enable
input double GridVolMult = 1.0; // Grid Volume Multiplier
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
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime tc;
datetime lastCandles[];
string symbols[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal(string s) {

    return false;

    double in = Ask(s);
    double sl = BuySL(SLType, SLLookback, in, SLDev, 0, s);
    double tp = in + TPCoef * MathAbs(in - sl);
    ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP, s);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal(string s) {

    return false;

    double in = Bid(s);
    double sl = SellSL(SLType, SLLookback, in, SLDev, 0, s);
    double tp = in - TPCoef * MathAbs(in - sl);
    ea.SellOpen(in, sl, tp, IgnoreSL, IgnoreTP, s);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose(string s) {
    if (CloseOnProfit) {
        double p = getProfit(ea.GetMagic(), s) - calcCost(ea.GetMagic(), s);
        if (p < 0) return;
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

    if (RiskMode == RISK_FIXED_VOL) ea.risk = Risk;
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

        if (CloseOrders) CheckClose(s);

        if (!OpenNewPos) break;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) break;
        if (!MultipleOpenPos && ea.OPTotal() > 0) break;
        if (ea.OPTotal(s) > 0) continue;
        if (SpreadLimit != -1 && Spread(s) > SpreadLimit) continue;

        if (BuySignal(s)) continue;
        SellSignal(s);
    }
}

//+------------------------------------------------------------------+
