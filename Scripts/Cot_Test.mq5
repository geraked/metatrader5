//+------------------------------------------------------------------+
//|                                                     Cot_Test.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.00"
#property description "An example to use the Commitments of Traders (COT) library."
#property script_show_inputs

#include <Cot.mqh>
#include <Sql.mqh>
#include <Generic/HashMap.mqh>

input string Date = "0000.00.00"; // Date (yyyy.mm.dd) (default: current)

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

struct SSignalCnt {
    string           symbol;
    string           type;
    int              count;
    string           details;
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    datetime time = Date == "0000.00.00" ? TimeTradeServer() : StringToTime(Date);

    if (!CotInit(COT_REPORT_T, time, false))
        return;

    SSignal signals[];
    for (int i = COT_CLASS_CO_COM; i <= COT_CLASS_CO_ORT; i++) {
        for (int j = COT_MODE_COP; j <= COT_MODE_FO; j++) {
            if (!FetchSignals((ENUM_COT_CLASS_CO) i, (ENUM_COT_MODE) j, signals, time))
                return;
        }
    }

    Print("");
    Print("***** CFTC signals for date: ", time);
    ArrayPrint(signals, _Digits, " | ");
    Print("");

    SSignalCnt sigcnts[];
    FetchSignalsCnt(signals, sigcnts);
    ArrayPrint(sigcnts, _Digits, " | ");
    Print("");
}

//+--------------------------------------------------------------------+
//| Generate 6 signals by crossing the top 2 currencies with the top 3 |
//| currencies based on the highest long/short percentage positions.   |
//+--------------------------------------------------------------------+
bool FetchSignals(ENUM_COT_CLASS_CO clss, ENUM_COT_MODE mode, SSignal &signals[], datetime time = 0) {
    if (time == 0) time = TimeTradeServer();
    datetime date_from, date_to;
    CotGetDateRange(time, date_from, date_to);
    ENUM_COT_REPORT report_type = CotGetReportType(clss, mode);
    if (!CotIsAvailable(report_type, time, true)) {
        PrintFormat("The COT report is not available: %s (%s - %s)", TimeToString(time), TimeToString(date_from, TIME_DATE), TimeToString(date_to, TIME_DATE));
        return false;
    }

    string table = CotGetTableName(clss);
    string ccol = CotGetColClause(clss);
    string lcol = StringFormat("%s_positions_long", ccol);
    string scol = StringFormat("%s_positions_short", ccol);
    int fo = (mode == COT_MODE_FO) ? 1 : 0;

    if (clss == COT_CLASS_CO_COM || clss == COT_CLASS_CO_NCOM || clss == COT_CLASS_CO_NR || StringFind(lcol, "dealer") != -1) {
        lcol += "_all";
        scol += "_all";
    }

    string sql = "WITH M AS ( "
                 "SELECT strftime('%Y.%m.%d', date, 'unixepoch') AS d, date, name, "
                 + StringFormat("round(%s * 100.0 / (%s + %s), 2) AS lp, ", lcol, lcol, scol)
                 + StringFormat("round(%s * 100.0 / (%s + %s), 2) AS sp ", scol, lcol, scol)
                 + StringFormat("FROM %s A ", table) +
                 "INNER JOIN contract C ON C.id = A.cid "
                 + StringFormat("WHERE date >= %d AND date < %d ", date_from, date_to) +
                 "AND C.id IN ('232741','099741','096742','112741','090741','092741','097741','098662') "
                 + StringFormat("AND fo = %d ", fo) +
                 "ORDER BY date DESC, name ASC LIMIT 8 "
                 "), "
                 "LM AS ( "
                 "SELECT lp AS lmin FROM (SELECT lp FROM M ORDER BY lp DESC LIMIT 3) ORDER BY lp ASC LIMIT 1 "
                 "), "
                 "SM AS ( "
                 "SELECT sp AS smin FROM (SELECT sp FROM M ORDER BY sp DESC LIMIT 3) ORDER BY sp ASC LIMIT 1 "
                 "), "
                 "LL AS (SELECT CASE WHEN smin > lmin THEN 2 ELSE 3 END AS llim FROM LM, SM), "
                 "SL AS (SELECT CASE WHEN smin > lmin THEN 3 ELSE 2 END AS slim FROM LM, SM) "

                 "SELECT t1.name AS green, t2.name AS red, t1.lp AS green_percent, t2.sp As red_percent, t1.d AS date FROM "
                 "(SELECT * FROM M ORDER BY lp DESC LIMIT (SELECT * FROM LL)) AS t1, "
                 "(SELECT * FROM M ORDER BY sp DESC LIMIT (SELECT * FROM SL)) AS t2 "
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
//| Identify overlapping signals.                                    |
//+------------------------------------------------------------------+
void FetchSignalsCnt(const SSignal &signals[], SSignalCnt &sigcnts[]) {
    CHashMap<string, int> hm();
    string key, cls_desc;
    int m;
    int n = ArraySize(signals);

    for (int i = 0; i < n; i++) {
        key = signals[i].symbol + signals[i].type;

        if (!hm.ContainsKey(key)) {
            m = ArraySize(sigcnts);
            ArrayResize(sigcnts, m + 1);
            sigcnts[m].symbol = signals[i].symbol;
            sigcnts[m].type = signals[i].type;
            sigcnts[m].count = 0;
            sigcnts[m].details = "";
            hm.Add(key, m);
        }

        hm.TryGetValue(key, m);
        sigcnts[m].count++;
        cls_desc = CotGetColClause((ENUM_COT_CLASS_CO) signals[i].cid);
        if (StringLen(sigcnts[m].details) > 0)
            StringAdd(sigcnts[m].details, ", ");
        StringAdd(sigcnts[m].details, StringFormat("%s(%d)", cls_desc, signals[i].mid));
    }
}

//+------------------------------------------------------------------+
