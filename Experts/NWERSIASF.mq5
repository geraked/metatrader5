//+------------------------------------------------------------------+
//|                                                    NWERSIASF.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.0"
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
input double Risk = 1.3; // Risk (%)
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

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = true; // Allow Having Multiple Open Positions
input double MarginLimit = 4000; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 120; // Timer Interval (Seconds)
input ulong MagicNumber = 1002; // Magic Number

GerEA ea;
datetime tc;
string symbols[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NWE(string symbol, int bi = 0, int i = 0) {
    int handle;
    double B[];
    handle = iCustom(symbol, 0, I_NWE, NweBandWidth, NweMultiplier, NweWindowSize);
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
double RSI(string symbol, int i = 0) {
    int handle;
    double B[];
    handle = iRSI(symbol, 0, RsiLength, PRICE_CLOSE);
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
double ASF(string symbol, int bi = 0, int i = 0) {
    int handle;
    double B[];
    handle = iCustom(symbol, 0, I_ASF, AsfLength, AsfMultiplier);
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
    if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
    if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
    if (!MultipleOpenPos && ea.PosTotal() > 0) return;

    int n = ArraySize(symbols);
    for (int i = 0; i < n; i++) {

        string s = symbols[i];
        double point = SymbolInfoDouble(s, SYMBOL_POINT);
        int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);

        if (positionsTotalMagic(ea.GetMagic(), s) > 0) continue;
        if (RecentlyHadPos(s)) continue;

        double c1 = iClose(s, 0, 1);
        double o1 = iOpen(s, 0, 1);
        double h2 = iHigh(s, 0, 2);
        double l2 = iLow(s, 0, 2);
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
            double d = MathAbs(in - sl);
            double tp = in + TPCoef * d;
            bool isl = Grid ? true : IgnoreSL;
            ea.BuyOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, digits), s);
        }

        else if (sc) {
            double in = Bid(s);
            double sl = asfUp;
            double d = MathAbs(in - sl);
            double tp = in - TPCoef * d;
            bool isl = Grid ? true : IgnoreSL;
            ea.SellOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, digits), s);
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
    ea.gridVolMult = GridVolMult;
    ea.gridTrailingStopLevel = GridTrailingStopLevel * 0.01;
    ea.gridMaxLvl = GridMaxLvl;
    ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    ea.slippage = Slippage;

    FillSymbols();

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
//|                                                                  |
//+------------------------------------------------------------------+
void FillSymbols() {
    if (!MultipleSymbol) {
        ArrayResize(symbols, 1);
        symbols[0] = _Symbol;
        return;
    }

    string sbls[];
    int n = StringSplit(Symbols, ',', sbls);
    if (n > 0) {
        int k = 0;
        string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
        for (int i = 0; i < n; i++) {
            string symbol = Trim(sbls[i]) + postfix;
            bool b = false;
            if (!SymbolExist(symbol, b)) continue;
            ArrayResize(symbols, k + 1);
            symbols[k] = symbol;
            k++;
        }
        return;
    }

    string curs[] = {"EUR", "USD", "JPY", "CHF", "AUD", "GBP", "CAD", "NZD", "SGD"};
    n = ArraySize(curs);
    int k = 0;
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (i == j) continue;
            string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
            string symbol = curs[i] + curs[j] + postfix;
            bool b = false;
            if (!SymbolExist(symbol, b)) continue;
            ArrayResize(symbols, k + 1);
            symbols[k] = symbol;
            k++;
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RecentlyHadPos(string symbol) {
    if (!HistorySelect(TimeCurrent() - 20 * PeriodSeconds(PERIOD_D1), TimeCurrent())) {
        int err = GetLastError();
        PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        return false;
    }
    int totalDeals = HistoryDealsTotal();
    for (int i = totalDeals - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != ea.GetMagic()) continue;
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
        datetime dealTime = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
        if (TimeCurrent() < dealTime + MinPosInterval * PeriodSeconds(PERIOD_CURRENT)) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Trim(string s) {
    string str = s + " ";
    StringTrimLeft(str);
    StringTrimRight(str);
    return str;
}

//+------------------------------------------------------------------+
