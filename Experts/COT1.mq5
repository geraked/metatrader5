//+------------------------------------------------------------------+
//|                                                         COT1.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.0"
#property description "A strategy using Commitments of Traders (COT) and Super Trend indicator"
#property description "Multiple Symbols-Daily  2021.01.01 - 2024.01.14"

#include <EAUtils.mqh>
#include <Cot.mqh>
#include <Sql.mqh>

#define PATH_ST "Indicators\\SuperTrend.ex5"
#define I_ST "::" + PATH_ST
#resource "\\" + PATH_ST

input group "Indicator Parameters"
input bool StEnable = false; // SuperTrend Enable
input double StMultiplier = 3; // SuperTrend Multiplier
input int StPeriod = 10; // SuperTrend Period
input ENUM_TIMEFRAMES IndTimeframe = PERIOD_M15; // Timeframe

input group "COT"
input ENUM_COT_CLASS_CO CotPrimaryClass = COT_CLASS_CO_DEALER; // COT Primary Class
input ENUM_COT_MODE CotPrimaryMode = COT_MODE_FO; // COT Primary Mode
input ENUM_COT_CLASS_CO CotSecondaryClass = COT_CLASS_CO_LEV; // COT Secondary Class
input ENUM_COT_MODE CotSecondaryMode = COT_MODE_FO; // COT Secondary Mode

input group "General"
input string OpenTime = "03:00"; // Open Time for Trades
input double TPCoef = 2.0; // TP Coefficient
input ENUM_SL SLType = SL_AR; // SL Type
input int SLLookback = 6; // SL Lookback
input int SLDev = 30; // SL Deviation (Points)
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 3.5; // Risk (%)
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = true; // Ignore TP
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.2; // Grid Volume Multiplier
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
input bool MultipleOpenPos = false; // Allow Having Multiple Open Positions
input double MarginLimit = 1500; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 120; // Timer Interval (Seconds)
input ulong MagicNumber = 1004; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

int SignalCheckInterval = 15; // Minutes

GerEA ea;
string tcd;
MqlDateTime tcs;
datetime tc;
datetime signalLastCheck;

struct SSignal {
    string           symbol;
    string           type;
    string           clss;
    string           mode;
    string           gp;
    string           rp;
    string           date;
    int              cid;
    int              mid;
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ST(string symbol, int i = 0) {
    int handle;
    double B[];
    handle = iCustom(symbol, IndTimeframe, I_ST, StPeriod, StMultiplier, false);
    if (handle < 0) {
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
void CheckForSignal() {
    if (!OpenNewPos) return;
    if (tcs.day_of_week != MONDAY && tcs.day_of_week != TUESDAY) return;
    if (tc - signalLastCheck < SignalCheckInterval * 60) return;
    if (tc < StringToTime(tcd + OpenTime)) return;
    if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
    if (!MultipleOpenPos && ea.PosTotal() > 0) return;

    signalLastCheck = tc;
    SSignal signals[];
    if (!FetchSignals(CotPrimaryClass, CotPrimaryMode, signals, tc))
        return;
    if (!FetchSignals(CotSecondaryClass, CotSecondaryMode, signals, tc))
        return;

    for (int i = 0; i < ArraySize(signals); i++) {
        string s = signals[i].symbol;
        string stype = signals[i].type;

        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if (!MultipleOpenPos && ea.PosTotal() > 0) return;

        if (positionsTotalMagic(ea.GetMagic(), s) > 0) continue;
        if (hasDealCurrentWeek(ea.GetMagic(), s)) continue;
        if (SpreadLimit != -1 && Spread(s) > SpreadLimit) continue;

        int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);

        if (StEnable) {
            double st = ST(s);
            if (st == -1) continue;

            double h = iHigh(s, IndTimeframe, 0);
            double l = iLow(s, IndTimeframe, 0);
            double c = iClose(s, IndTimeframe, 0);

            if (st < c && stype == "sell")
                continue;
            if (st > c && stype == "buy")
                continue;
        }

        fixMultiCurrencies();

        if (stype == "buy") {
            double in = Ask(s);
            double sl = BuySL(SLType, SLLookback, in, SLDev, 0, s, PERIOD_D1);
            double tp = in + TPCoef * MathAbs(in - sl);
            ea.BuyOpen(in, sl, tp, IgnoreSL, IgnoreTP, s);
            Sleep(5000);
        }

        if (stype == "sell") {
            double in = Bid(s);
            double sl = SellSL(SLType, SLLookback, in, SLDev, 0, s, PERIOD_D1);
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

    if (!CotInit(CotGetReportType(CotPrimaryClass, CotPrimaryMode)))
        return INIT_FAILED;
    if (!CotInit(CotGetReportType(CotSecondaryClass, CotSecondaryMode)))
        return INIT_FAILED;

    if (News) fetchCalendarFromYear(NewsStartYear);
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
    tc = TimeCurrent(tcs);
    tcd = TimeToString(tc, TIME_DATE) + " ";
    if (tc == oldTc) return;

    if (Trail) ea.CheckForTrail();
    if (EquityDrawdownLimit) ea.CheckForEquity();
    if (Grid) ea.CheckForGrid();
    CheckForSignal();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnTesterInit() {
    return INIT_FAILED;
}

void OnTesterDeinit() {

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FetchSignals(ENUM_COT_CLASS_CO clss, ENUM_COT_MODE mode, SSignal &signals[], datetime time = 0) {
    if (time == 0) time = TimeTradeServer();
    datetime date_from, date_to;
    CotGetDateRange(time, date_from, date_to);
    ENUM_COT_REPORT report_type = CotGetReportType(clss, mode);
    if (!CotIsAvailable(report_type, time)) {
        PrintFormat("The COT report is not available: %s (%s - %s)", TimeToString(time), TimeToString(date_from, TIME_DATE), TimeToString(date_to, TIME_DATE));
        return false;
    }

    string table = CotGetTableName(clss);
    string ccol = CotGetColClause(clss);
    string lcol = StringFormat("%s_positions_long", ccol);
    string scol = StringFormat("%s_positions_short", ccol);
    string lccol = StringFormat("change_in_%s_long", ccol);
    string sccol = StringFormat("change_in_%s_short", ccol);
    int fo = (mode == COT_MODE_FO) ? 1 : 0;

    if (clss == COT_CLASS_CO_COM || clss == COT_CLASS_CO_NCOM || clss == COT_CLASS_CO_NR || StringFind(lcol, "dealer") != -1) {
        lcol += "_all";
        scol += "_all";
        lccol += "_all";
        sccol += "_all";
    }

    string sql = "WITH M AS ( "
                 "SELECT strftime('%Y.%m.%d', date, 'unixepoch') AS d, date, name, "
                 + StringFormat("round(%s * 100.0 / (%s + %s), 2) AS lp, ", lcol, lcol, scol)
                 + StringFormat("round(%s * 100.0 / (%s + %s), 2) AS sp, ", scol, lcol, scol)
                 + StringFormat("%s AS lc, %s AS sc, ", lccol, sccol)
                 + StringFormat("(%s - %s) AS cnp ", lccol, sccol)
                 + StringFormat("FROM %s A ", table) +
                 "INNER JOIN contract C ON C.id = A.cid "
                 + StringFormat("WHERE date >= %d AND date < %d ", date_from, date_to) +
                 "AND C.id IN ('232741','099741','096742','112741','090741','092741','097741','098662') "
                 + StringFormat("AND fo = %d ", fo) +
                 "ORDER BY date DESC, name ASC LIMIT 8 "
                 ") "

                 "SELECT t1.name AS green, t2.name AS red, t1.lp AS green_percent, t2.sp As red_percent, t1.d AS date FROM "
                 "(SELECT * FROM M WHERE cnp > 0 ORDER BY lp DESC LIMIT 2) AS t1, "
                 "(SELECT * FROM M WHERE cnp < 0 ORDER BY sp DESC LIMIT 2) AS t2 "
                 ";";

    int db = CotInitDb();
    if (db == INVALID_HANDLE) return false;
    string rows[], head[];
    SqlSelect(db, sql, rows, head, '\t');
    DatabaseClose(db);

    string row[];
    string g, r, symbol;
    string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
    int nrows = ArraySize(rows);
    int j = 0;
    bool b;

    for (int i = 0; i < nrows; i++) {
        StringSplit(rows[i], '\t', row);
        g = row[0];
        r = row[1];
        symbol = g + r + postfix;
        j = ArraySize(signals);

        if (SymbolExist(symbol, b)) {
            ArrayResize(signals, j + 1);
            signals[j].symbol = symbol;
            signals[j].type = "buy";
        } else {
            symbol = r + g + postfix;
            if (!SymbolExist(symbol, b)) continue;
            ArrayResize(signals, j + 1);
            signals[j].symbol = symbol;
            signals[j].type = "sell";
        }

        signals[j].clss = CotGetDescription(clss);
        signals[j].mode = CotGetDescription(mode);
        signals[j].gp = row[2];
        signals[j].rp = row[3];
        signals[j].date = row[4];
        signals[j].cid = clss;
        signals[j].mid = mode;
    }

    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasDealCurrentWeek(ulong magic, string symbol) {
    datetime date_from, date_to;
    CotGetDateRange(TimeCurrent(), date_from, date_to);
    date_from += 7 * PeriodSeconds(PERIOD_D1);
    if (!HistorySelect(TimeCurrent() - 10 * PeriodSeconds(PERIOD_D1), TimeCurrent())) {
        int err = GetLastError();
        PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        return false;
    }
    int totalDeals = HistoryDealsTotal();
    for (int i = totalDeals - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
        datetime dealTime = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
        if (dealTime >= date_from) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
