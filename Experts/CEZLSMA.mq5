//+------------------------------------------------------------------+
//|                                                      CEZLSMA.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.5"
#property description "A Strategy Using Chandelier Exit and ZLSMA Indicators Based on the Heikin Ashi Candles"
#property description "AUDUSD-15M  2019.01.01 - 2023.08.01"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int CeAtrPeriod = 1; // CE ATR Period
input double CeAtrMult = 0.75; // CE ATR Multiplier
input int ZlPeriod = 50; // ZLSMA Period

input group "General"
input int SLDev = 650; // SL Deviation (Points)
input bool CloseOrders = true; // Check For Closing Conditions
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 3; // Risk (%)
input bool IgnoreSL = true; // Ignore SL
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.5; // Grid Volume Multiplier
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
input ulong MagicNumber = 2000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

int BuffSize = 4;

GerEA ea;
datetime lastCandle;
datetime tc;

#define PATH_HA "Indicators\\Examples\\Heiken_Ashi.ex5"
#define I_HA "::" + PATH_HA
#resource "\\" + PATH_HA
int HA_handle;
double HA_C[];

#define PATH_CE "Indicators\\ChandelierExit.ex5"
#define I_CE "::" + PATH_CE
#resource "\\" + PATH_CE
int CE_handle;
double CE_B[], CE_S[];

#define PATH_ZL "Indicators\\ZLSMA.ex5"
#define I_ZL "::" + PATH_ZL
#resource "\\" + PATH_ZL
int ZL_handle;
double ZL[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool c = CE_B[1] != 0 && HA_C[1] > ZL[1];
    if (!c) return false;

    double in = Ask();
    double sl = CE_B[1] - SLDev * _Point;
    double tp = 0;
    ea.BuyOpen(in, sl, tp, IgnoreSL, true);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    bool c = CE_S[1] != 0 && HA_C[1] < ZL[1];
    if (!c) return false;

    double in = Bid();
    double sl = CE_S[1] + SLDev * _Point;
    double tp = 0;
    ea.SellOpen(in, sl, tp, IgnoreSL, true);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose() {
    double p = getProfit(ea.GetMagic()) - calcCost(ea.GetMagic());
    if (p < 0) return;

    if (HA_C[2] >= ZL[2] && HA_C[1] < ZL[1])
        ea.BuyClose();

    if (HA_C[2] <= ZL[2] && HA_C[1] > ZL[1])
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

    HA_handle = iCustom(NULL, 0, I_HA);
    CE_handle = iCustom(NULL, 0, I_CE, CeAtrPeriod, CeAtrMult);
    ZL_handle = iCustom(NULL, 0, I_ZL, ZlPeriod, true);

    if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return(INIT_FAILED);
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

        if (CopyBuffer(HA_handle, 3, 0, BuffSize, HA_C) <= 0) return;
        ArraySetAsSeries(HA_C, true);

        if (CopyBuffer(CE_handle, 0, 0, BuffSize, CE_B) <= 0) return;
        if (CopyBuffer(CE_handle, 1, 0, BuffSize, CE_S) <= 0) return;
        ArraySetAsSeries(CE_B, true);
        ArraySetAsSeries(CE_S, true);

        if (CopyBuffer(ZL_handle, 0, 0, BuffSize, ZL) <= 0) return;
        ArraySetAsSeries(ZL, true);

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
