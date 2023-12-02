//+------------------------------------------------------------------+
//|                                                      EAUtils.mqh |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.14"

#include <errordescription.mqh>

#define DIR "Geraked\\"

enum ENUM_NEWS_IMPORTANCE {
    NEWS_IMPORTANCE_NONE, // None
    NEWS_IMPORTANCE_LOW, // Low
    NEWS_IMPORTANCE_MEDIUM, // Medium
    NEWS_IMPORTANCE_HIGH // High
};

enum ENUM_FILLING {
    FILLING_DEFAULT, // Default
    FILLING_FOK, // FOK
    FILLING_IOK, // IOK
    FILLING_BOC, // BOC
    FILLING_RETURN // RETURN
};

class GerEA {
private:
    ulong magicNumber;
    bool authorized;
public:
    double risk;
    double martingaleRisk;
    bool martingale;
    int slippage;
    bool reverse;
    int nRetry;
    int mRetry;
    double trailingStopLevel;
    double gridVolMult;
    double gridTrailingStopLevel;
    int gridMaxLvl;
    double equityDrawdownLimit;
    bool news;
    ENUM_NEWS_IMPORTANCE newsImportance;
    int newsMinsBefore;
    int newsMinsAfter;
    ENUM_FILLING filling;   

    GerEA() {
        risk = 0.01;
        martingaleRisk = 0.04;
        martingale = false;
        slippage = 30;
        reverse = false;
        nRetry = 5;
        mRetry = 2000;
        trailingStopLevel = 0.5;
        gridVolMult = 1.0;
        gridTrailingStopLevel = 0;
        gridMaxLvl = 20;
        equityDrawdownLimit = 0;
        news = false;
        newsImportance = NEWS_IMPORTANCE_MEDIUM;
        newsMinsBefore = 60;
        newsMinsAfter = 60;
        filling = FILLING_DEFAULT;
    }

    void Init(int magicSeed = 1) {
        magicNumber = calcMagic(magicSeed);
        authorized = auth();
    }

    bool BuyOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
        if (!reverse)
            return order(ORDER_TYPE_BUY, magicNumber, Ask(name), sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling);
        return order(ORDER_TYPE_SELL, magicNumber, Bid(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling);
    }

    bool SellOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
        if (!reverse)
            return order(ORDER_TYPE_SELL, magicNumber, Bid(name), sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling);
        return order(ORDER_TYPE_BUY, magicNumber, Ask(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling);
    }

    void BuyClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, nRetry, mRetry, filling);
        else
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, nRetry, mRetry, filling);
    }

    void SellClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, nRetry, mRetry, filling);
        else
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, nRetry, mRetry, filling);
    }

    bool PosClose(ulong ticket) {
        return closeOrder(ticket, slippage, nRetry, mRetry, filling);
    }

    bool IsAuthorized() {
        return authorized;
    }

    int PosTotal(string name = NULL) {
        return positionsTotalMagic(magicNumber, name);
    }

    ulong GetMagic() {
        return magicNumber;
    }

    void SetMagic(ulong magic) {
        magicNumber = magic;
    }

    void CheckForTrail() {
        checkForTrail(magicNumber, trailingStopLevel, gridTrailingStopLevel);
    }

    void CheckForGrid() {
        checkForGrid(magicNumber, risk, gridVolMult, gridMaxLvl, slippage, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling);
    }

    void CheckForEquity() {
        checkForEquity(magicNumber, equityDrawdownLimit, slippage, nRetry, mRetry, filling);
    }
};


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool auth() {
    long logins[] = {6279587};
    long login = AccountInfoInteger(ACCOUNT_LOGIN);
    int n = ArraySize(logins);
    for(int i = 0; i < n; i++) {
        if (logins[i] == login) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Ask(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    return SymbolInfoDouble(name, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Bid(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    return SymbolInfoDouble(name, SYMBOL_BID);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Spread(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    return (int) SymbolInfoInteger(name, SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(int i) {
    return iHigh(_Symbol, PERIOD_CURRENT, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(int i) {
    return iLow(_Symbol, PERIOD_CURRENT, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(int i) {
    return iOpen(_Symbol, PERIOD_CURRENT, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(int i) {
    return iClose(_Symbol, PERIOD_CURRENT, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int i) {
    return iTime(_Symbol, PERIOD_CURRENT, i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong calcMagic(int magicSeed = 1) {
    string s = StringSubstr(_Symbol, 0);
    StringToLower(s);

    int n = 0;
    int l = StringLen(s);

    for(int i = 0; i < l; i++) {
        n += StringGetCharacter(s, i);
    }

    string str = (string) magicSeed + (string) n + (string) Period();
    return (ulong) str;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcVolume(double in, double sl, double risk = 0.01, double tp = 0, bool martingale = false, double martingaleRisk = 0.04, ulong magic = 0, string name = NULL, double balance = 0) {
    name = name == NULL ? _Symbol : name;
    if (balance == 0)
        balance = MathMin(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    if (sl == 0)
        sl = tp;

    double point = SymbolInfoDouble(name, SYMBOL_POINT);
    double tvl = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_VALUE_LOSS);
    double tvp = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_VALUE_PROFIT);
    double volMax = SymbolInfoDouble(name, SYMBOL_VOLUME_MAX);
    double volMin = SymbolInfoDouble(name, SYMBOL_VOLUME_MIN);
    double vol = 0;

    vol = (balance * risk) / MathAbs(in - sl) * point / tvl;

    if (martingale) {
        ulong ticket = getLatestTicket(magic);
        if (ticket != 0) {
            double lprofit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if (lprofit < 0) {
                double lin = HistoryDealGetDouble(ticket, DEAL_PRICE);
                double lsl = HistoryDealGetDouble(ticket, DEAL_SL);
                double lvol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                vol = 2 * MathAbs(lin - lsl) * lvol / MathAbs(in - tp);
                vol = MathMin(vol, (balance * martingaleRisk) / MathAbs(in - sl) * point / tvl);
            }
        }
    }

    vol = NormalizeDouble(vol, 2);
    if (vol > volMax) vol = volMax;
    if (vol < volMin) vol = volMin;

    return vol;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(string symbol, ENUM_ORDER_TYPE_FILLING fill_type) {
    int filling = (int) SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    return((filling & fill_type) == fill_type);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool order(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double risk = 0.01, bool martingale = false, double martingaleRisk = 0.04, int slippage = 30, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0, int nRetry = 3, int mRetry = 2000, bool news = false, ENUM_NEWS_IMPORTANCE newsImportance = NEWS_IMPORTANCE_MEDIUM, int newsMinsBefore = 60, int newsMinsAfter = 60, ENUM_FILLING filling = FILLING_DEFAULT) {
    name = name == NULL ? _Symbol : name;
    int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
    int err;
    bool os, osc;

    in = NormalizeDouble(in, digits);
    tp = NormalizeDouble(tp, digits);
    sl = NormalizeDouble(sl, digits);

    if (ot == ORDER_TYPE_BUY) {
        in = Ask(name);
        if (sl != 0 && sl >= Bid(name)) return false;
        if (tp != 0 && tp <= Bid(name)) return false;
    } else if (ot == ORDER_TYPE_SELL) {
        in = Bid(name);
        if (sl != 0 && sl <= Ask(name)) return false;
        if (tp != 0 && tp >= Ask(name)) return false;
    } else {
        return false;
    }

    if (MQLInfoInteger(MQL_TESTER) && in == 0) {
        Print("Warning: OpenPrice is 0!");
        return false;
    }

    if (news) {
        if (hasSymbolNews(name, newsImportance, newsMinsBefore, newsMinsAfter))
            return false;
    }

    if (comment == "" && positionsTotalMagic(magic, name) == 0)
        comment = sl ? DoubleToString(MathAbs(in - sl), digits) : tp ? DoubleToString(MathAbs(in - tp), digits) : "";

    if (vol == 0)
        vol = calcVolume(in, sl, risk, tp, martingale, martingaleRisk, magic, name);

    if (isl) sl = 0;
    if (itp) tp = 0;

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    req.action = TRADE_ACTION_DEAL;
    req.symbol = name;
    req.volume = vol;
    req.type = ot;
    req.price = in;
    req.sl = sl;
    req.tp = tp;
    req.deviation = slippage;
    req.magic = magic;
    req.comment = comment;

    if (filling == FILLING_DEFAULT) {
        if (IsFillingTypeAllowed(name, ORDER_FILLING_FOK)) {
            req.type_filling = ORDER_FILLING_FOK;
        } else if (IsFillingTypeAllowed(name, ORDER_FILLING_IOC)) {
            req.type_filling = ORDER_FILLING_IOC;
        }
    } else if (filling == FILLING_FOK) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_IOK) req.type_filling = ORDER_FILLING_IOC;
    else if (filling == FILLING_BOC) req.type_filling = ORDER_FILLING_BOC;
    else if (filling == FILLING_RETURN) req.type_filling = ORDER_FILLING_RETURN;

    int cnt = 1;
    do {
        ZeroMemory(res);
        ResetLastError();
        os = OrderSend(req, res);
        err = GetLastError();

        if (os && cnt == 1) return true;
        if (os) {
            PrintFormat("OrderSend success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment);
            return true;
        }

        osc = false;
        osc = osc || res.retcode == TRADE_RETCODE_REQUOTE;
        osc = osc || res.retcode == TRADE_RETCODE_TIMEOUT;
        osc = osc || res.retcode == TRADE_RETCODE_INVALID_PRICE;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_CHANGED;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_OFF;
        osc = osc || res.retcode == TRADE_RETCODE_CONNECTION;

        if (!osc) {
            PrintFormat("OrderSend error: retcode=%u  deal=%I64u  order=%I64u  %s", res.retcode, res.deal, res.order, res.comment);
            return false;
        }

        PrintFormat("OrderSend error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment);

        Sleep(mRetry);
        cnt++;

        if (ot == ORDER_TYPE_BUY) {
            if (res.ask && Ask(name) == req.price) req.price = res.ask;
            else req.price = Ask(name);
        } else if (ot == ORDER_TYPE_SELL) {
            if (res.bid && Bid(name) == req.price) req.price = res.bid;
            else req.price = Bid(name);
        }

    } while (!os && cnt <= nRetry);

    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeOrders(ENUM_POSITION_TYPE pt, ulong magic, int slippage = 30, string name = NULL, int nRetry = 3, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        if (pmagic != magic) continue;
        if (ptype != pt) continue;
        if (name != NULL && psymbol != name) continue;
        closeOrder(pticket, slippage, nRetry, mRetry, filling);
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool closeOrder(ulong ticket, int slippage = 30, int nRetry = 3, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    int err;

    if (!PositionSelectByTicket(ticket)) {
        err = GetLastError();
        PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        return false;
    }

    string psymbol = PositionGetString(POSITION_SYMBOL);
    ulong pmagic = PositionGetInteger(POSITION_MAGIC);
    double pvolume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    req.action = TRADE_ACTION_DEAL;
    req.position = ticket;
    req.symbol = psymbol;
    req.volume = pvolume;
    req.deviation = slippage;
    req.magic = pmagic;

    if (filling == FILLING_DEFAULT) {
        if (IsFillingTypeAllowed(psymbol, ORDER_FILLING_FOK)) {
            req.type_filling = ORDER_FILLING_FOK;
        } else if (IsFillingTypeAllowed(psymbol, ORDER_FILLING_IOC)) {
            req.type_filling = ORDER_FILLING_IOC;
        }
    } else if (filling == FILLING_FOK) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_IOK) req.type_filling = ORDER_FILLING_IOC;
    else if (filling == FILLING_BOC) req.type_filling = ORDER_FILLING_BOC;
    else if (filling == FILLING_RETURN) req.type_filling = ORDER_FILLING_RETURN;

    if (ptype == POSITION_TYPE_BUY) {
        req.price = Bid(psymbol);
        req.type = ORDER_TYPE_SELL;
    } else {
        req.price = Ask(psymbol);
        req.type = ORDER_TYPE_BUY;
    }

    bool os, osc;
    int cnt = 1;
    do {
        ZeroMemory(res);
        ResetLastError();
        os = OrderSend(req, res);
        err = GetLastError();

        if (os && cnt == 1) return true;
        if (os) {
            PrintFormat("OrderClose success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment);
            return true;
        }

        osc = false;
        osc = osc || res.retcode == TRADE_RETCODE_REQUOTE;
        osc = osc || res.retcode == TRADE_RETCODE_TIMEOUT;
        osc = osc || res.retcode == TRADE_RETCODE_INVALID_PRICE;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_CHANGED;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_OFF;
        osc = osc || res.retcode == TRADE_RETCODE_CONNECTION;

        if (!osc) {
            PrintFormat("OrderClose error: retcode=%u  deal=%I64u  order=%I64u  %s", res.retcode, res.deal, res.order, res.comment);
            return false;
        }

        PrintFormat("OrderClose error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment);

        Sleep(mRetry);
        cnt++;

        if (ptype == POSITION_TYPE_BUY) {
            if (res.bid && Bid(psymbol) == req.price) req.price = res.bid;
            else req.price = Bid(psymbol);
        } else {
            if (res.ask && Ask(psymbol) == req.price) req.price = res.ask;
            else req.price = Ask(psymbol);
        }

    } while (!os && cnt <= nRetry);

    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int positionsTotalMagic(ulong magic, string name = NULL) {
    int cnt = 0;
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        cnt++;
    }
    return cnt;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong getLatestTicket(ulong magic) {
    int err;
    ulong latestTicket = 0;

    if (!HistorySelect(TimeCurrent() - 40 * PeriodSeconds(PERIOD_D1), TimeCurrent())) {
        err = GetLastError();
        PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        return latestTicket;
    }

    int totalDeals = HistoryDealsTotal();
    datetime latestDeal = 0;

    for (int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);

        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;

        datetime dealTime = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
        if (dealTime > latestDeal) {
            latestDeal = dealTime;
            latestTicket = ticket;
        }
    }

    return latestTicket;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int positionsTickets(ulong magic, ulong &arr[], string name = NULL) {
    int total = PositionsTotal();
    int j = 0;
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        ArrayResize(arr, j + 1);
        arr[j] = pticket;
        j++;
    }
    return j;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int positionsVolumes(ulong magic, double &arr[], string name = NULL) {
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    ArrayResize(arr, n);
    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        arr[i] = PositionGetDouble(POSITION_VOLUME);
    }
    return n;
}

//+------------------------------------------------------------------+
//| Sum of swap, commission, fee                                     |
//+------------------------------------------------------------------+
double calcCost(ulong magic, string name = NULL) {
    double swap = 0;
    double comm = 0;
    double fee = 0;
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        double pswap = PositionGetDouble(POSITION_SWAP);
        double pcomm = HistoryDealGetDouble(pticket, DEAL_COMMISSION);
        double pfee = HistoryDealGetDouble(pticket, DEAL_FEE);
        swap += pswap;
        comm += pcomm;
        fee += pfee;
    }
    return -(comm + swap + fee);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcPrice(ulong magic, double target, double newOp = 0, double newVol = 0, string name = NULL) {
    name = name == NULL ? _Symbol : name;
    double tvp = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_VALUE_PROFIT);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);

    bool isBuy = true;
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    double sum_vol_op = 0;
    double sum_vol = 0;

    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        double op = PositionGetDouble(POSITION_PRICE_OPEN);
        double vol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        isBuy = ptype == POSITION_TYPE_BUY;
        sum_vol_op += vol * op;
        sum_vol += vol;
    }

    sum_vol_op += newVol * newOp;
    sum_vol += newVol;

    double line = isBuy ? (target + tvp * sum_vol_op / point) / (tvp * sum_vol / point) : (target - tvp * sum_vol_op / point) / (- tvp * sum_vol / point);
    line = NormalizeDouble(line, digits);

    return line;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcProfit(ulong magic, double target, string name = NULL) {
    name = name == NULL ? _Symbol : name;
    double tvp = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_VALUE_PROFIT);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);

    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    double prof = 0;

    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        double op = PositionGetDouble(POSITION_PRICE_OPEN);
        double vol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        bool isBuy = ptype == POSITION_TYPE_BUY;
        double d = isBuy ? target - op : op - target;
        prof += vol * tvp * (d / point);
    }

    return prof;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getProfit(ulong magic, string name = NULL) {
    name = name == NULL ? _Symbol : name;
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    double prof = 0;

    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        prof += PositionGetDouble(POSITION_PROFIT);
    }

    return prof;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForTrail(ulong magic, double stopLevel = 0.5, double gridStopLevel = 0.4) {
    int minPoints = 30;
    MqlTradeRequest req;
    MqlTradeResult res;

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        double ppoint = SymbolInfoDouble(psymbol, SYMBOL_POINT);
        int pdigits = (int) SymbolInfoInteger(psymbol, SYMBOL_DIGITS);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        double pin = PositionGetDouble(POSITION_PRICE_OPEN);
        double psl = PositionGetDouble(POSITION_SL);
        double ptp = PositionGetDouble(POSITION_TP);
        double pd = StringToDouble(PositionGetString(POSITION_COMMENT));
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        ENUM_SYMBOL_TRADE_MODE pstm = (ENUM_SYMBOL_TRADE_MODE) SymbolInfoInteger(psymbol, SYMBOL_TRADE_MODE);

        if (pmagic != magic) continue;
        if (pd == 0) continue;
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        ulong tickets[];
        int n = positionsTickets(pmagic, tickets, psymbol);
        int k = 0;
        for (int j = 0; j < n; j++) {
            PositionSelectByTicket(tickets[j]);
            if (StringToDouble(PositionGetString(POSITION_COMMENT))) k++;
        }

        double sl;
        double cost = calcCost(pmagic, psymbol);
        double brkeven = calcPrice(pmagic, cost, 0, 0, psymbol);

        if (n == 1 || k > 1) {
            if (stopLevel == 0) continue;

            ZeroMemory(req);
            ZeroMemory(res);
            req.action = TRADE_ACTION_SLTP;
            req.position = pticket;
            req.symbol = psymbol;
            req.magic = pmagic;
            req.sl = psl;
            req.tp = ptp;

            if (ptype == POSITION_TYPE_BUY) {
                double h = Bid(psymbol);
                if (h <= pin) continue;
                double d = h - pin;

                if (k > 1)
                    sl = pin + d - stopLevel * pd + minPoints * ppoint;
                else
                    sl = MathMax(pin, brkeven) + d - stopLevel * pd;

                sl = NormalizeDouble(sl, pdigits);
                if (sl < pin) continue;
                if (psl != 0 && (psl >= sl || sl > Bid(psymbol))) continue;
                req.sl = sl;
            }

            else if (ptype == POSITION_TYPE_SELL) {
                double l = Ask(psymbol);
                if (l >= pin) continue;
                double d = pin - l;

                if (k > 1)
                    sl = pin - d + stopLevel * pd - minPoints * ppoint;
                else
                    sl = MathMin(pin, brkeven) - d + stopLevel * pd;

                sl = NormalizeDouble(sl, pdigits);
                if (sl > pin) continue;
                if (psl != 0 && (psl <= sl || sl < Ask(psymbol))) continue;
                req.sl = sl;
            }

            if (!OrderSend(req, res)) {
                int err = GetLastError();
                PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
            }
        }

        else {
            if (gridStopLevel == 0) continue;

            for (int j = 0; j < n; j++) {
                PositionSelectByTicket(tickets[j]);
                if (ptype == POSITION_TYPE_BUY && PositionGetDouble(POSITION_TP) < ptp)
                    ptp = PositionGetDouble(POSITION_TP);
                if (ptype == POSITION_TYPE_SELL && PositionGetDouble(POSITION_TP) > ptp)
                    ptp = PositionGetDouble(POSITION_TP);
            }

            double target_prof = calcProfit(pmagic, ptp, psymbol);
            double per_target = calcPrice(pmagic, gridStopLevel * target_prof, 0, 0, psymbol);

            if (ptype == POSITION_TYPE_BUY) {
                double h = Bid(psymbol);
                if (h <= per_target) continue;
                double d = h - per_target;
                sl = brkeven + d;
                sl = NormalizeDouble(sl, pdigits);
                if (!(Bid(psymbol) - sl >= minPoints * ppoint)) continue;
                if (psl != 0 && psl >= sl) continue;

                for (int j = 0; j < n; j++) {
                    PositionSelectByTicket(tickets[j]);
                    ZeroMemory(req);
                    ZeroMemory(res);
                    req.action = TRADE_ACTION_SLTP;
                    req.position = tickets[j];
                    req.symbol = psymbol;
                    req.magic = pmagic;
                    req.sl = sl;
                    req.tp = ptp;

                    if (pticket == tickets[j]) {
                        if (!OrderSend(req, res)) {
                            int err = GetLastError();
                            PrintFormat("%s (grid, long) error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                        }
                    } else {
                        if (!OrderSendAsync(req, res)) {
                            int err = GetLastError();
                            PrintFormat("%s (grid, long) error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                        }
                    }
                }
            }

            else if (ptype == POSITION_TYPE_SELL) {
                double l = Ask(psymbol);
                if (l >= per_target) continue;
                double d = per_target - l;
                sl = brkeven - d;
                sl = NormalizeDouble(sl, pdigits);
                if (!(sl - Ask(psymbol) >= minPoints * ppoint)) continue;
                if (psl != 0 && psl <= sl) continue;

                for (int j = 0; j < n; j++) {
                    PositionSelectByTicket(tickets[j]);
                    ZeroMemory(req);
                    ZeroMemory(res);
                    req.action = TRADE_ACTION_SLTP;
                    req.position = tickets[j];
                    req.symbol = psymbol;
                    req.magic = pmagic;
                    req.sl = sl;
                    req.tp = ptp;

                    if (pticket == tickets[j]) {
                        if (!OrderSend(req, res)) {
                            int err = GetLastError();
                            PrintFormat("%s (grid, short) error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                        }
                    } else {
                        if (!OrderSendAsync(req, res)) {
                            int err = GetLastError();
                            PrintFormat("%s (grid, short) error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                        }
                    }
                }
            }

        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForGrid(ulong magic, double risk, double volCoef, int maxLvl, int slippage = 30, int nRetry = 3, int mRetry = 2000, bool news = false, ENUM_NEWS_IMPORTANCE newsImportance = NEWS_IMPORTANCE_MEDIUM, int newsMinsBefore = 60, int newsMinsAfter = 60, ENUM_FILLING filling = FILLING_DEFAULT) {
    int minPoints = 30;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        datetime ptime = (datetime) PositionGetInteger(POSITION_TIME);
        double ppoint = SymbolInfoDouble(psymbol, SYMBOL_POINT);
        double ptvl = SymbolInfoDouble(psymbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
        double pin = PositionGetDouble(POSITION_PRICE_OPEN);
        double pd = StringToDouble(PositionGetString(POSITION_COMMENT));
        double psl = PositionGetDouble(POSITION_SL);
        double pvol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        ENUM_SYMBOL_TRADE_MODE pstm = (ENUM_SYMBOL_TRADE_MODE) SymbolInfoInteger(psymbol, SYMBOL_TRADE_MODE);

        if (pmagic != magic) continue;
        if (pd == 0) continue;
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        ulong tickets[];
        int n = positionsTickets(pmagic, tickets, psymbol);
        if (n < 1 || n >= maxLvl) continue;

        double vols[];
        positionsVolumes(pmagic, vols, psymbol);
        double lastVol = vols[ArrayMaximum(vols)];

        MqlTradeRequest req;
        MqlTradeResult res;
        double lvl, tp;

        double vol = lastVol * volCoef;
        double volMax = SymbolInfoDouble(psymbol, SYMBOL_VOLUME_MAX);
        double volMin = SymbolInfoDouble(psymbol, SYMBOL_VOLUME_MIN);
        vol = NormalizeDouble(vol, 2);
        if (vol > volMax) vol = volMax;
        if (vol < volMin) vol = volMin;

        double loss = pvol * ptvl * (pd / ppoint);
        double balance = loss / risk;
        double target_prof = risk * balance;
        double cost = calcCost(pmagic, psymbol);
        if (cost > 0) target_prof += cost;

        if (ptype == POSITION_TYPE_BUY) {
            double low = Bid(psymbol);
            lvl = pin - n * pd;
            if (low > lvl) continue;
            tp = calcPrice(pmagic, target_prof, Ask(psymbol), vol, psymbol);

            if (!(tp - Bid(psymbol) >= minPoints * ppoint))
                tp = Bid(psymbol) + minPoints * ppoint;

            if (!order(ORDER_TYPE_BUY, pmagic, Ask(psymbol), psl, tp, risk, false, 0, slippage, false, false, "", psymbol, vol, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling)) continue;

            for (int j = 0; j < n; j++) {
                PositionSelectByTicket(tickets[j]);
                ZeroMemory(req);
                ZeroMemory(res);
                req.action = TRADE_ACTION_SLTP;
                req.position = tickets[j];
                req.symbol = psymbol;
                req.magic = pmagic;
                req.sl = psl;
                req.tp = tp;

                if (PositionGetDouble(POSITION_TP) == req.tp && PositionGetDouble(POSITION_SL) == req.sl) continue;

                if (!OrderSendAsync(req, res)) {
                    int err = GetLastError();
                    PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                }
            }
        }

        else if (ptype == POSITION_TYPE_SELL) {
            double high = Ask(psymbol);
            lvl = pin + n * pd;
            if (high < lvl) continue;
            tp = calcPrice(pmagic, target_prof, Bid(psymbol), vol, psymbol);

            if (!(Ask(psymbol) - tp >= minPoints * ppoint))
                tp = Ask(psymbol) - minPoints * ppoint;

            if (!order(ORDER_TYPE_SELL, pmagic, Bid(psymbol), psl, tp, risk, false, 0, slippage, false, false, "", psymbol, vol, nRetry, mRetry, news, newsImportance, newsMinsBefore, newsMinsAfter, filling)) continue;

            for (int j = 0; j < n; j++) {
                PositionSelectByTicket(tickets[j]);
                ZeroMemory(req);
                ZeroMemory(res);
                req.action = TRADE_ACTION_SLTP;
                req.position = tickets[j];
                req.symbol = psymbol;
                req.magic = pmagic;
                req.sl = psl;
                req.tp = tp;

                if (PositionGetDouble(POSITION_TP) == req.tp && PositionGetDouble(POSITION_SL) == req.sl) continue;

                if (!OrderSendAsync(req, res)) {
                    int err = GetLastError();
                    PrintFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForEquity(ulong magic, double limit, int slippage = 30, int nRetry = 3, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    if (limit == 0) return;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double p = (equity - balance) / balance;
    if (p >= 0) return;
    if (MathAbs(p) < limit) return;

    double max_loss = -DBL_MAX;
    string max_symbol = "";
    ulong tickets[];
    int n = positionsTickets(magic, tickets);
    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        double loss = calcCost(magic, psymbol) - getProfit(magic, psymbol);
        if (loss > max_loss) {
            max_loss = loss;
            max_symbol = psymbol;
        }
    }

    closeOrders(POSITION_TYPE_BUY, magic, slippage, max_symbol, nRetry, mRetry, filling);
    closeOrders(POSITION_TYPE_SELL, magic, slippage, max_symbol, nRetry, mRetry, filling);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fillSymbols(string &arr[], bool multiple_symbols, string symbols_str = "", string currencies_str = "EUR, USD, JPY, CHF, AUD, GBP, CAD, NZD") {
    if (!multiple_symbols) {
        ArrayResize(arr, 1);
        arr[0] = _Symbol;
        return;
    }

    string sbls[];
    int n = StringSplit(symbols_str, ',', sbls);
    if (n > 0) {
        int k = 0;
        string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
        for (int i = 0; i < n; i++) {
            string symbol = Trim(sbls[i]) + postfix;
            bool b = false;
            if (!SymbolExist(symbol, b)) continue;
            ArrayResize(arr, k + 1);
            arr[k] = symbol;
            k++;
        }
        return;
    }

    string curs[];
    n = StringSplit(currencies_str, ',', curs);
    int k = 0;
    string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (i == j) continue;
            string symbol = Trim(curs[i]) + Trim(curs[j]) + postfix;
            bool b = false;
            if (!SymbolExist(symbol, b)) continue;
            ArrayResize(arr, k + 1);
            arr[k] = symbol;
            k++;
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasDealRecently(ulong magic, string symbol, int nCandles) {
    if (!HistorySelect(TimeCurrent() - 2 * (nCandles + 1) * PeriodSeconds(PERIOD_CURRENT), TimeCurrent())) {
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
        if (TimeCurrent() < dealTime + nCandles * PeriodSeconds(PERIOD_CURRENT)) return true;
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
//|                                                                  |
//+------------------------------------------------------------------+
string getCalendarDbPath() {
    return DIR + "calendar-" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".db";
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fetchCalendarFromYear(int year) {
    if (year == 0) return;
    MqlDateTime Tcs;
    TimeCurrent(Tcs);
    for (int i = Tcs.year; i >= year; i--)
        fetchCalendar(i);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool fetchCalendar(int year) {
    const int Max_Retry = 4;

    if (MQLInfoInteger(MQL_TESTER)) return true;
    if (year == 0) return true;
    if (year < 2010) {
        Print("Fetching News data older than year 2010 is not allowed!");
        return false;
    }

    MqlDateTime Tcs;
    datetime Tc = TimeCurrent();
    TimeToStruct(Tc, Tcs);
    if (year > Tcs.year) return false;

    PrintFormat("Fetching News data for year %d...", year);

    datetime date_from = StringToTime(IntegerToString(year) + ".01.01");
    datetime date_to = StringToTime(IntegerToString(year + 1) + ".01.01");
    if (year == Tcs.year) date_to = Tc + PeriodSeconds(PERIOD_D1);

    MqlCalendarCountry countries[];
    int n = 0;
    int iter = 0;
    int err;
    do {
        iter++;
        ResetLastError();
        n = CalendarCountries(countries);
        err = GetLastError();
        if (n > 0) break;
        if (err != ERR_CALENDAR_TIMEOUT || iter == Max_Retry) {
            PrintFormat("%s error #%d (CalendarCountries) : %s", __FUNCTION__, err, ErrorDescription(err));
            return false;
        }
    } while(err == ERR_CALENDAR_TIMEOUT);

    int db, dp, t;
    string sql;

    db = DatabaseOpen(getCalendarDbPath(), DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
    if (db == INVALID_HANDLE) {
        err = GetLastError();
        PrintFormat("%s error (DatabaseOpen) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        return false;
    }

    if (!DatabaseTableExists(db, "country")) {
        sql = "CREATE TABLE country ("
              "id INT,"
              "name TEXT,"
              "code TEXT,"
              "currency TEXT,"
              "currency_symbol TEXT,"
              "url_name TEXT,"
              "PRIMARY KEY(id)"
              ");"
              ;

        if (!DatabaseExecute(db, sql)) {
            err = GetLastError();
            PrintFormat("%s error (table: country) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
            DatabaseClose(db);
            return false;
        }
    }

    if (!DatabaseTableExists(db, "event")) {
        sql = "CREATE TABLE event ("
              "id INT,"
              "type INT,"
              "sector INT,"
              "frequency INT,"
              "time_mode INT,"
              "country_id INT,"
              "unit INT,"
              "importance INT,"
              "multiplier INT,"
              "digits INT,"
              "source_url TEXT,"
              "event_code TEXT,"
              "name TEXT,"
              "FOREIGN KEY(country_id) REFERENCES country(id),"
              "PRIMARY KEY(id)"
              ");"
              ;

        if (!DatabaseExecute(db, sql)) {
            err = GetLastError();
            PrintFormat("%s error (table: event) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
            DatabaseClose(db);
            return false;
        }
    }

    if (!DatabaseTableExists(db, "value")) {
        sql = "CREATE TABLE value ("
              "id INT,"
              "event_id INT,"
              "time INT,"
              "period INT,"
              "revision INT,"
              "actual_value INT,"
              "prev_value INT,"
              "revised_prev_value INT,"
              "forecast_value INT,"
              "impact_type INT,"
              "FOREIGN KEY(event_id) REFERENCES event(id),"
              "PRIMARY KEY(id)"
              ");"
              "CREATE INDEX idx_value_1 ON value(time);"
              ;

        if (!DatabaseExecute(db, sql)) {
            err = GetLastError();
            PrintFormat("%s error (table: value) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
            DatabaseClose(db);
            return false;
        }
    }

    sql = "CREATE VIEW IF NOT EXISTS main AS "
          "SELECT v.id, event_id, time, period, revision, actual_value, prev_value, revised_prev_value, forecast_value, impact_type, "
          "type, sector, frequency, time_mode, country_id, unit, importance, multiplier, digits, source_url, event_code, e.name, "
          "c.name AS cname, code, currency, currency_symbol, url_name "
          "FROM value v "
          "JOIN event e ON e.id = v.event_id "
          "JOIN country c ON c.id = e.country_id "
          "ORDER BY time DESC "
          ";";

    if (!DatabaseExecute(db, sql)) {
        err = GetLastError();
        PrintFormat("%s error (view) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        DatabaseClose(db);
        return false;
    }

    if (!DatabaseTransactionBegin(db)) {
        err = GetLastError();
        PrintFormat("%s error (DatabaseTransactionBegin) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        DatabaseClose(db);
        return false;
    }

    for (int i = 0; i < n; i++) {
        if (IsStopped()) {
            PrintFormat("%s (loop: countries) stopped!", __FUNCTION__);
            DatabaseTransactionRollback(db);
            DatabaseClose(db);
            return false;
        }

        sql = StringFormat("SELECT count(*) FROM country WHERE id=%d LIMIT 1", countries[i].id);
        dp = DatabasePrepare(db, sql);
        DatabaseRead(dp);
        DatabaseColumnInteger(dp, 0, t);
        DatabaseFinalize(dp);

        if (!t) {
            StringReplace(countries[i].name, "'", "''");
            StringReplace(countries[i].code, "'", "''");
            StringReplace(countries[i].currency, "'", "''");
            StringReplace(countries[i].currency_symbol, "'", "''");
            StringReplace(countries[i].url_name, "'", "''");

            sql = "INSERT INTO country(id, name, code, currency, currency_symbol, url_name) VALUES("
                  + StringFormat("%d, '%s', '%s', '%s', '%s', '%s'", countries[i].id, countries[i].name, countries[i].code, countries[i].currency, countries[i].currency_symbol, countries[i].url_name) +
                  ")"
                  ";";

            if (!DatabaseExecute(db, sql)) {
                err = GetLastError();
                PrintFormat("%s error (insert: country) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                DatabaseTransactionRollback(db);
                DatabaseClose(db);
                return false;
            }
        }

        MqlCalendarValue values[];
        int m = 0;
        iter = 0;
        do {
            iter++;
            ResetLastError();
            m = CalendarValueHistory(values, date_from, date_to, countries[i].code);
            err = GetLastError();
            if (m > -1) break;
            if (err != ERR_CALENDAR_TIMEOUT || iter == Max_Retry) {
                PrintFormat("%s error #%d (CalendarValueHistory) : %s, country: %s", __FUNCTION__, err, ErrorDescription(err), countries[i].code);
                DatabaseTransactionRollback(db);
                DatabaseClose(db);
                return false;
            }
        } while(err == ERR_CALENDAR_TIMEOUT);

        for (int j = 0; j < m; j++) {
            if (IsStopped()) {
                PrintFormat("%s (loop: values) stopped!", __FUNCTION__);
                DatabaseTransactionRollback(db);
                DatabaseClose(db);
                return false;
            }

            sql = StringFormat("SELECT count(*) FROM value WHERE id=%d LIMIT 1", values[j].id);
            dp = DatabasePrepare(db, sql);
            DatabaseRead(dp);
            DatabaseColumnInteger(dp, 0, t);
            DatabaseFinalize(dp);
            if (t) {
                if (year == Tcs.year) {
                    sql = "UPDATE value SET " +
                          StringFormat("event_id=%d, time=%d, period=%d, revision=%d, actual_value=%d, prev_value=%d, revised_prev_value=%d, forecast_value=%d, impact_type=%d ", values[j].event_id, values[j].time, values[j].period, values[j].revision, values[j].actual_value, values[j].prev_value, values[j].revised_prev_value, values[j].forecast_value, values[j].impact_type) +
                          StringFormat("WHERE id=%d ", values[j].id) +
                          ";";

                    if (!DatabaseExecute(db, sql)) {
                        err = GetLastError();
                        PrintFormat("%s error (update: value) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                        DatabaseTransactionRollback(db);
                        DatabaseClose(db);
                        return false;
                    }
                }
                continue;
            }

            MqlCalendarEvent event;
            if (!CalendarEventById(values[j].event_id, event)) {
                err = GetLastError();
                PrintFormat("%s (CalendarEventById) error #%d : %s, country: %s", __FUNCTION__, err, ErrorDescription(err), countries[i].code);
                continue;
            }

            sql = StringFormat("SELECT count(*) FROM event WHERE id=%d LIMIT 1", event.id);
            dp = DatabasePrepare(db, sql);
            DatabaseRead(dp);
            DatabaseColumnInteger(dp, 0, t);
            DatabaseFinalize(dp);

            if (!t) {
                StringReplace(event.source_url, "'", "''");
                StringReplace(event.event_code, "'", "''");
                StringReplace(event.name, "'", "''");

                sql = "INSERT INTO `event`(id, type, sector, frequency, time_mode, country_id, unit, importance, multiplier, digits, source_url, event_code, name) VALUES("
                      + StringFormat("%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, '%s', '%s', '%s'", event.id, event.type, event.sector, event.frequency, event.time_mode, event.country_id, event.unit, event.importance, event.multiplier, event.digits, event.source_url, event.event_code, event.name) +
                      ")"
                      ";";

                if (!DatabaseExecute(db, sql)) {
                    err = GetLastError();
                    PrintFormat("%s error (insert: event) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                    DatabaseTransactionRollback(db);
                    DatabaseClose(db);
                    return false;
                }
            }

            sql = "INSERT INTO value(id, event_id, time, period, revision, actual_value, prev_value, revised_prev_value, forecast_value, impact_type) VALUES("
                  + StringFormat("%d, %d, %d, %d, %d, %d, %d, %d, %d, %d", values[j].id, values[j].event_id, values[j].time, values[j].period, values[j].revision, values[j].actual_value, values[j].prev_value, values[j].revised_prev_value, values[j].forecast_value, values[j].impact_type) +
                  ")"
                  ";";

            if (!DatabaseExecute(db, sql)) {
                err = GetLastError();
                PrintFormat("%s error (insert: value) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
                DatabaseTransactionRollback(db);
                DatabaseClose(db);
                return false;
            }
        }
    }

    if (!DatabaseTransactionCommit(db)) {
        err = GetLastError();
        PrintFormat("%s error (DatabaseTransactionCommit) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        DatabaseClose(db);
        return false;
    }

    DatabaseClose(db);
    Print("Done!");
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasSymbolNews(string symbol, ENUM_NEWS_IMPORTANCE importance, int minsBefore, int minsAfter) {
    string cur1 = StringSubstr(symbol, 0, 3);
    string cur2 = StringSubstr(symbol, 3, 3);
    bool hcn1 = hasCurrencyNews(cur1, importance, minsBefore, minsAfter);
    bool hcn2 = hasCurrencyNews(cur2, importance, minsBefore, minsAfter);
    if (hcn1 || hcn2) return true;
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasCurrencyNews(string currency, ENUM_NEWS_IMPORTANCE importance, int minsBefore, int minsAfter) {
    const int Max_Retry = 4;

    int p = 2 * (minsBefore + minsAfter + 1) * PeriodSeconds(PERIOD_M1);
    datetime Tc = TimeCurrent();
    datetime date_from = Tc - p;
    datetime date_to = Tc + p;

    if (!MQLInfoInteger(MQL_TESTER)) {
        MqlCalendarValue values[];
        int n = 0;
        int iter = 0;
        int err;
        do {
            iter++;
            ResetLastError();
            n = CalendarValueHistory(values, date_from, date_to, NULL, currency);
            err = GetLastError();
            if (n > -1) break;
            if (err != ERR_CALENDAR_TIMEOUT || iter == Max_Retry) {
                PrintFormat("%s error #%d (CalendarValueHistory) : %s, currency: %s", __FUNCTION__, err, ErrorDescription(err), currency);
                return false;
            }
        } while(err == ERR_CALENDAR_TIMEOUT);

        for (int i = 0; i < n; i++) {
            MqlCalendarEvent event;
            if (!CalendarEventById(values[i].event_id, event)) {
                err = GetLastError();
                PrintFormat("%s error #%d : %s, currency: %s", __FUNCTION__, err, ErrorDescription(err), currency);
                continue;
            }

            datetime t = values[i].time;
            datetime tb = t - minsBefore * PeriodSeconds(PERIOD_M1);
            datetime te = t + minsAfter * PeriodSeconds(PERIOD_M1);
            if (!(Tc > tb && Tc < te)) continue;
            if (event.importance >= (int) importance) return true;
        }

        return false;
    }

    if (!FileIsExist(getCalendarDbPath(), FILE_COMMON)) return false;

    int db, dp;
    string sql;

    db = DatabaseOpen(getCalendarDbPath(), DATABASE_OPEN_READONLY | DATABASE_OPEN_COMMON);
    if (db == INVALID_HANDLE) {
        int err = GetLastError();
        PrintFormat("%s error (DatabaseOpen) #%d : %s", __FUNCTION__, err, ErrorDescription(err));
        return false;
    }

    sql = StringFormat("SELECT time_mode, time, importance FROM main WHERE time >= %d AND time < %d AND currency='%s' COLLATE NOCASE", date_from, date_to, currency);
    dp = DatabasePrepare(db, sql);

    while (DatabaseRead(dp) && !IsStopped()) {
        int time_mode, time, imp;
        DatabaseColumnInteger(dp, 0, time_mode);
        DatabaseColumnInteger(dp, 1, time);
        DatabaseColumnInteger(dp, 2, imp);
        datetime t = (datetime) time;

        datetime tb = t - minsBefore * PeriodSeconds(PERIOD_M1);
        datetime te = t + minsAfter * PeriodSeconds(PERIOD_M1);
        if (!(Tc > tb && Tc < te)) continue;

        if (imp >= (int) importance) {
            DatabaseFinalize(dp);
            DatabaseClose(db);
            return true;
        }
    }

    DatabaseFinalize(dp);
    DatabaseClose(db);
    return false;
}

//+------------------------------------------------------------------+
