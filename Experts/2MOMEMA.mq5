//+------------------------------------------------------------------+
//|                                                      2MOMEMA.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.00"
#property description "A strategy using two Momentums and EMAs"
#property description "https://youtu.be/deBLPlt8N4E"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int FastPeriod = 10; // Fast Period
input int SlowPeriod = 34; // Slow Period

input group "General"
input double SLCoef = 1.0; // SL Coefficient
input double TPCoef = 1.0; // TP Coefficient
input ENUM_SL SLType = SL_SWING; // SL Type
input int SLLookback = 10; // SL Look Back
input int SLDev = 60; // SL Deviation (Points)
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
input ulong MagicNumber = 1000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime lastCandle;
datetime tc;

int FMA_handle, SMA_handle, FMOM_handle, SMOM_handle;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    if (!(Ind(FMOM_handle, 1) > 100 && Ind(FMOM_handle, 2) <= 100)) return false;

    for (int i = 1; i < 10; i++) {
        if (Ind(SMOM_handle, i) <= 100) return false;
        if (Ind(FMA_handle, i) <= Ind(SMA_handle, i)) return false;
    }

    double in = Ask();
    double sl = BuySL(SLType, SLLookback, in, SLDev, 1);
    double tp = in + TPCoef * MathAbs(in - sl);
    ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    if (!(Ind(FMOM_handle, 1) < 100 && Ind(FMOM_handle, 2) >= 100)) return false;

    for (int i = 1; i < 10; i++) {
        if (Ind(SMOM_handle, i) >= 100) return false;
        if (Ind(FMA_handle, i) >= Ind(SMA_handle, i)) return false;
    }

    double in = Bid();
    double sl = SellSL(SLType, SLLookback, in, SLDev, 1);
    double tp = in - TPCoef * MathAbs(in - sl);
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
    EventSetTimer(TimerInterval);

    SMA_handle = iMA(NULL, PERIOD_CURRENT, SlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    FMA_handle = iMA(NULL, PERIOD_CURRENT, FastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    SMOM_handle = iMomentum(NULL, PERIOD_CURRENT, SlowPeriod, PRICE_CLOSE);
    FMOM_handle = iMomentum(NULL, PERIOD_CURRENT, FastPeriod, PRICE_CLOSE);

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
        if ((Grid || !MultipleOpenPos) && ea.OPTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
