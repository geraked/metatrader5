//+------------------------------------------------------------------+
//|                                                        UTBot.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.00"
#property description "UT Bot Alerts Indicator"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_label1  "Bull"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLawnGreen
#property indicator_width1  1

#property indicator_label2  "Bear"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrange
#property indicator_width2  1

input double AtrCoef = 2; // ATR Coefficient (Sensitivity)
input int AtrLen = 1; // ATR Period

// Buffers
double Bull[];
double Bear[];
double C1[];

int ATR_handle;
double ATR[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, Bull);
    PlotIndexSetInteger(0, PLOT_ARROW, 233);

    SetIndexBuffer(1, Bear);
    PlotIndexSetInteger(1, PLOT_ARROW, 234);

    SetIndexBuffer(2, C1, INDICATOR_CALCULATIONS);

    ATR_handle = iATR(NULL, 0, AtrLen);
    if (ATR_handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return(INIT_FAILED);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

    int limit = rates_total - prev_calculated;
    int toCopy = limit + 1;

    if (prev_calculated == 0) {
        ArrayInitialize(Bull, 0);
        ArrayInitialize(Bear, 0);
        ArrayInitialize(C1, 0);
        limit = limit - 1 - MathMax(1, AtrLen);
        toCopy = rates_total;
    }

    if (rates_total <= MathMax(1, AtrLen)) return(0);
    if (limit < 0) return(0);

    if (BarsCalculated(ATR_handle) != rates_total) return(0);
    if (CopyBuffer(ATR_handle, 0, 0, toCopy, ATR) <= 0) return(0);
    ArraySetAsSeries(ATR, true);

    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(Bull, true);
    ArraySetAsSeries(Bear, true);
    ArraySetAsSeries(C1, true);

    for (int i = limit; i >= 0 && !IsStopped(); i--) {
        double loss = ATR[i] * AtrCoef;
        double t1 = close[i] > C1[i + 1] ? close[i] - loss : close[i] + loss;
        double t2 = close[i] < C1[i + 1] && close[i + 1] < C1[i + 1] ? MathMin(C1[i + 1], close[i] + loss) : t1;
        C1[i] = close[i] > C1[i + 1] && close[i + 1] > C1[i + 1] ? MathMax(C1[i + 1], close[i] - loss) : t2;

        double h = MathAbs(high[i + 1] - low[i + 1]);
        Bull[i] = close[i] > C1[i] && close[i + 1] <= C1[i + 1] ? low[i] - h : 0;
        Bear[i] = close[i] < C1[i] && close[i + 1] >= C1[i + 1] ? high[i] + h : 0;
    }

    return(rates_total);
}
//+------------------------------------------------------------------+
