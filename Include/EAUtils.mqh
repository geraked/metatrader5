//+------------------------------------------------------------------+
//|                                                      EAUtils.mqh |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.5"

#include <errordescription.mqh>

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

    GerEA() {
        risk = 0.01;
        martingaleRisk = 0.04;
        martingale = false;
        slippage = 30;
        reverse = false;
        nRetry = 3;
        mRetry = 2000;
    }

    void Init(int magicSeed = 1) {
        magicNumber = calcMagic(magicSeed);
        authorized = auth();
    }

    bool BuyOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
        if (!reverse)
            return order(ORDER_TYPE_BUY, magicNumber, Ask(name), sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry);
        return order(ORDER_TYPE_SELL, magicNumber, Bid(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry);
    }

    bool SellOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
        if (!reverse)
            return order(ORDER_TYPE_SELL, magicNumber, Bid(name), sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry);
        return order(ORDER_TYPE_BUY, magicNumber, Ask(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry);
    }

    void BuyClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, nRetry, mRetry);
        else
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, nRetry, mRetry);
    }

    void SellClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, nRetry, mRetry);
        else
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, nRetry, mRetry);
    }

    bool IsAuthorized() {
        return authorized;
    }

    int PosTotal() {
        return positionsTotalMagic(magicNumber);
    }

    ulong GetMagic() {
        return magicNumber;
    }

    void SetMagic(ulong magic) {
        magicNumber = magic;
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
bool order(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double risk = 0.01, bool martingale = false, double martingaleRisk = 0.04, int slippage = 30, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0, int nRetry = 3, int mRetry = 2000) {
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
            if (res.ask) req.price = res.ask;
            else req.price = Ask(name);
        } else if (ot == ORDER_TYPE_SELL) {
            if (res.bid) req.price = res.bid;
            else req.price = Bid(name);
        }

    } while (!os && cnt <= nRetry);

    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeOrders(ENUM_POSITION_TYPE pt, ulong magic, int slippage = 30, string name = NULL, int nRetry = 3, int mRetry = 2000) {
    int err;
    MqlTradeRequest req;
    MqlTradeResult res;
    int total = PositionsTotal();

    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        int pdigits = (int) SymbolInfoInteger(psymbol, SYMBOL_DIGITS);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        double pvolume = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

        if (pmagic != magic) continue;
        if (ptype != pt) continue;
        if (name != NULL && psymbol != name) continue;

        ZeroMemory(req);
        ZeroMemory(res);

        req.action = TRADE_ACTION_DEAL;
        req.position = pticket;
        req.symbol = psymbol;
        req.volume = pvolume;
        req.deviation = slippage;
        req.magic = pmagic;

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

            if (os && cnt == 1) break;
            if (os) {
                PrintFormat("OrderClose success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment);
                break;
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
                break;
            }

            PrintFormat("OrderClose error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment);

            Sleep(mRetry);
            cnt++;

            if (ptype == POSITION_TYPE_BUY) {
                if (res.bid) req.price = res.bid;
                else req.price = Bid(psymbol);
            } else {
                if (res.ask) req.price = res.ask;
                else req.price = Ask(psymbol);
            }

        } while (!os && cnt <= nRetry);

    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int positionsTotalMagic(ulong magic) {
    int cnt = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        if (pmagic != magic) continue;
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
        if(dealTime > latestDeal) {
            latestDeal = dealTime;
            latestTicket = ticket;
        }
    }

    return latestTicket;
}

//+------------------------------------------------------------------+
