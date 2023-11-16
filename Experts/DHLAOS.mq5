//+------------------------------------------------------------------+
//|                                                       DHLAOS.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.3"
#property description "A strategy using Daily High/Low and Andean Oscillator indicators for scalping"
#property description "AUDUSD-5M  2021.02.22 - 2023.09.19"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int AosPeriod = 50; // AOS Period
input int AosSignalPeriod = 9; // AOS Signal Period

input group "General"
input double TPCoef = 1.5; // TP Coefficient
input int SLLookBack = 7; // SL Look Back
input int SLDev = 60; // SL Deviation (Points)
input int AosNCheck = 300; // AOS Max Candles
input int DhlNCheck = 50; // DHL Max Candles
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 0.5; // Risk (%)
input bool IgnoreSL = true; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.1; // Grid Volume Multiplier
input double GridTrailingStopLevel = 20; // Grid Trailing Stop Level (%) (0: Disable)
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
input ulong MagicNumber = 4000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime lastCandle;
datetime tc;
int BuffSize;

#define PATH_AOS "Indicators\\AndeanOscillator.ex5"
#define I_AOS "::" + PATH_AOS
#resource "\\" + PATH_AOS
int AOS_handle;
double AOS_Bull[], AOS_Bear[], AOS_Signal[];

#define PATH_DHL "Indicators\\DailyHighLow.ex5"
#define I_DHL "::" + PATH_DHL
#resource "\\" + PATH_DHL
int DHL_handle;
double DHL_H[], DHL_L[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool c = AOS_Bull[2] <= AOS_Signal[2] &&  AOS_Bull[1] > AOS_Signal[1];
    if (!c) return false;

    int j = 0;
    for (int i = 3; i < AosNCheck; i++) {
        if (AOS_Bull[i + 1] >= AOS_Bear[i + 1] && AOS_Bull[i] < AOS_Bear[i])
            return false;
        if (AOS_Bull[i + 1] >= AOS_Signal[i + 1] && AOS_Bull[i] < AOS_Signal[i])
            return false;
        if (AOS_Bull[i + 1] <= AOS_Signal[i + 1] && AOS_Bull[i] > AOS_Signal[i])
            return false;
        if (AOS_Bull[i + 1] <= AOS_Bear[i + 1] && AOS_Bull[i] > AOS_Bear[i]) {
            j = i;
            break;
        }
    }

    bool c2 = false;
    for (int i = j; i < j + DhlNCheck; i++) {
        if (High(i) < DHL_L[i] && AOS_Bull[i] < AOS_Bear[i]) {
            c2 = true;
            break;
        }
    }
    if (!c2) return false;

    double in = Ask();
    int il = iLowest(NULL, 0, MODE_LOW, SLLookBack, 1);
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
    bool c = AOS_Bear[2] <= AOS_Signal[2] &&  AOS_Bear[1] > AOS_Signal[1];
    if (!c) return false;

    int j = 0;
    for (int i = 3; i < AosNCheck; i++) {
        if (AOS_Bull[i + 1] <= AOS_Bear[i + 1] && AOS_Bull[i] > AOS_Bear[i])
            return false;
        if (AOS_Bear[i + 1] >= AOS_Signal[i + 1] && AOS_Bear[i] < AOS_Signal[i])
            return false;
        if (AOS_Bear[i + 1] <= AOS_Signal[i + 1] && AOS_Bear[i] > AOS_Signal[i])
            return false;
        if (AOS_Bull[i + 1] >= AOS_Bear[i + 1] && AOS_Bull[i] < AOS_Bear[i]) {
            j = i;
            break;
        }
    }

    bool c2 = false;
    for (int i = j; i < j + DhlNCheck; i++) {
        if (Low(i) > DHL_H[i] && AOS_Bull[i] > AOS_Bear[i]) {
            c2 = true;
            break;
        }
    }
    if (!c2) return false;

    double in = Bid();
    int ih = iHighest(NULL, 0, MODE_HIGH, SLLookBack, 1);
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
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;
    ea.filling = Filling;

    if (News) fetchCalendarFromYear(NewsStartYear);

    BuffSize = AosNCheck + DhlNCheck + 2;

    AOS_handle = iCustom(NULL, 0, I_AOS, AosPeriod, AosSignalPeriod);
    DHL_handle = iCustom(NULL, 0, I_DHL);

    if (AOS_handle == INVALID_HANDLE || DHL_handle == INVALID_HANDLE) {
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

        if (CopyBuffer(AOS_handle, 0, 0, BuffSize, AOS_Bull) <= 0) return;
        if (CopyBuffer(AOS_handle, 1, 0, BuffSize, AOS_Bear) <= 0) return;
        if (CopyBuffer(AOS_handle, 2, 0, BuffSize, AOS_Signal) <= 0) return;
        ArraySetAsSeries(AOS_Bull, true);
        ArraySetAsSeries(AOS_Bear, true);
        ArraySetAsSeries(AOS_Signal, true);

        if (CopyBuffer(DHL_handle, 0, 0, BuffSize, DHL_H) <= 0) return;
        if (CopyBuffer(DHL_handle, 1, 0, BuffSize, DHL_L) <= 0) return;
        ArraySetAsSeries(DHL_H, true);
        ArraySetAsSeries(DHL_L, true);

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}

//+------------------------------------------------------------------+
