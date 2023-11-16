//+------------------------------------------------------------------+
//|                                                        3MACD.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.2"
#property description "A strategy using triple MACDs for scalping"
#property description "AUDUSD-5M  2021.02.22 - 2023.09.26"

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int M1Fast = 5; // MACD1 Fast
input int M1Slow = 8; // MACD1 Slow
input int M2Fast = 13; // MACD2 Fast
input int M2Slow = 21; // MACD2 Slow
input int M3Fast = 34; // MACD3 Fast
input int M3Slow = 144; // MACD3 Slow

input group "General"
input double TPCoef = 2.0; // TP Coefficient
input int SLLookBack = 7; // SL Look Back
input int SLDev = 60; // SL Deviation (Points)
input int BuffSize = 32; // Buffer Size
input bool Reverse = true; // Reverse Signal

input group "Risk Management"
input double Risk = 0.5; // Risk (%)
input bool IgnoreSL = true; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
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
input ulong MagicNumber = 5000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

GerEA ea;
datetime lastCandle;
datetime tc;

int M1_handle, M2_handle, M3_handle;
double M1[], M2[], M3[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    if (M3[1] > 0 && M2[1] > 0 && M2[2] > 0 && M2[3] > 0 && M2[1] > M2[2] && M2[2] < M2[3]) {
        int j = 0;
        int k = 0;

        for (int i = 2; i < BuffSize - 1; i++) {
            if (M3[i] <= 0 || M3[i + 1] <= 0) return false;
            if (M2[i] <= 0 || M2[i + 1] <= 0) return false;
            if (M1[i] < 0 && M1[i + 1] > 0) {
                j = i + 1;
                break;
            }
        }

        if (j == 0) return false;

        for (int i = j; i < BuffSize - 2; i++) {
            if (M3[i] <= 0 || M3[i + 1] <= 0 || M3[i + 2] <= 0) return false;
            if (M2[i] <= 0 || M2[i + 1] <= 0 || M2[i + 2] <= 0) return false;
            if (M2[i] < M2[i + 1] && M2[i + 1] > M2[i + 2]) {
                k = i + 1;
                break;
            }
        }

        if (k == 0) return false;
    }

    else if (M3[1] > 0 && M3[2] > 0 && M3[3] > 0 && M3[1] > M3[2] && M3[2] < M3[3]) {
        int j = 0;
        int k = 0;
        int m = 0;

        for (int i = 2; i < BuffSize - 1; i++) {
            if (M3[i] <= 0 || M3[i + 1] <= 0) return false;
            if (M2[i] < 0 && M2[i + 1] > 0) {
                j = i + 1;
                break;
            }
        }

        if (j == 0) return false;

        for (int i = j; i < BuffSize - 1; i++) {
            if (M3[i] <= 0 || M3[i + 1] <= 0) return false;
            if (M2[i] <= 0 || M2[i + 1] <= 0) return false;
            if (M1[i] < 0 && M1[i + 1] > 0) {
                k = i + 1;
                break;
            }
        }

        if (k == 0) return false;

        for (int i = k; i < BuffSize - 2; i++) {
            if (M3[i] <= 0 || M3[i + 1] <= 0 || M3[i + 2] <= 0) return false;
            if (M2[i] <= 0 || M2[i + 1] <= 0 || M2[i + 2] <= 0) return false;
            if (M2[i] < M2[i + 1] && M2[i + 1] > M2[i + 2]) {
                m = i + 1;
                break;
            }
        }

        if (m == 0) return false;
    }

    else {
        return false;
    }

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
    if (M3[1] < 0 && M2[1] < 0 && M2[2] < 0 && M2[3] < 0 && M2[1] < M2[2] && M2[2] > M2[3]) {
        int j = 0;
        int k = 0;

        for (int i = 2; i < BuffSize - 1; i++) {
            if (M3[i] >= 0 || M3[i + 1] >= 0) return false;
            if (M2[i] >= 0 || M2[i + 1] >= 0) return false;
            if (M1[i] > 0 && M1[i + 1] < 0) {
                j = i + 1;
                break;
            }
        }

        if (j == 0) return false;

        for (int i = j; i < BuffSize - 2; i++) {
            if (M3[i] >= 0 || M3[i + 1] >= 0 || M3[i + 2] >= 0) return false;
            if (M2[i] >= 0 || M2[i + 1] >= 0 || M2[i + 2] >= 0) return false;
            if (M2[i] > M2[i + 1] && M2[i + 1] < M2[i + 2]) {
                k = i + 1;
                break;
            }
        }

        if (k == 0) return false;
    }

    else if (M3[1] < 0 && M3[2] < 0 && M3[3] < 0 && M3[1] < M3[2] && M3[2] > M3[3]) {
        int j = 0;
        int k = 0;
        int m = 0;

        for (int i = 2; i < BuffSize - 1; i++) {
            if (M3[i] >= 0 || M3[i + 1] >= 0) return false;
            if (M2[i] > 0 && M2[i + 1] < 0) {
                j = i + 1;
                break;
            }
        }

        if (j == 0) return false;

        for (int i = j; i < BuffSize - 1; i++) {
            if (M3[i] >= 0 || M3[i + 1] >= 0) return false;
            if (M2[i] >= 0 || M2[i + 1] >= 0) return false;
            if (M1[i] > 0 && M1[i + 1] < 0) {
                k = i + 1;
                break;
            }
        }

        if (k == 0) return false;

        for (int i = k; i < BuffSize - 2; i++) {
            if (M3[i] >= 0 || M3[i + 1] >= 0 || M3[i + 2] >= 0) return false;
            if (M2[i] >= 0 || M2[i + 1] >= 0 || M2[i + 2] >= 0) return false;
            if (M2[i] > M2[i + 1] && M2[i + 1] < M2[i + 2]) {
                m = i + 1;
                break;
            }
        }

        if (m == 0) return false;
    }

    else {
        return false;
    }

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

    M1_handle = iMACD(NULL, 0, M1Fast, M1Slow, 1, PRICE_CLOSE);
    M2_handle = iMACD(NULL, 0, M2Fast, M2Slow, 1, PRICE_CLOSE);
    M3_handle = iMACD(NULL, 0, M3Fast, M3Slow, 1, PRICE_CLOSE);

    if (M1_handle == INVALID_HANDLE || M2_handle == INVALID_HANDLE || M3_handle == INVALID_HANDLE) {
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

        if (CopyBuffer(M1_handle, 0, 0, BuffSize, M1) <= 0) return;
        if (CopyBuffer(M2_handle, 0, 0, BuffSize, M2) <= 0) return;
        if (CopyBuffer(M3_handle, 0, 0, BuffSize, M3) <= 0) return;

        ArraySetAsSeries(M1, true);
        ArraySetAsSeries(M2, true);
        ArraySetAsSeries(M3, true);

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}

//+------------------------------------------------------------------+
