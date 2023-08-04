//+------------------------------------------------------------------+
//|                                                        ZLSMA.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property description "Zero Lag Least Squares Moving Average (ZLSMA)"
#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1 "ZLSMA"
#property indicator_type1  DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_color1 clrCyan
#property indicator_width1 2

double B1[];
double B2[];

input int LRPeriod = 14; // Period
input bool HeikenAshi = true; // Use HeikenAshi

#define PATH_HA "Indicators\\Examples\\Heiken_Ashi.ex5"
#define I_HA "::" + PATH_HA
#resource "\\" + PATH_HA
int HA_handle;
double HA_C[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, B1);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    ArraySetAsSeries(B1, true);

    SetIndexBuffer(1, B2, INDICATOR_CALCULATIONS);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    ArraySetAsSeries(B2, true);

    if (HeikenAshi) {
        HA_handle = iCustom(NULL, 0, I_HA);
        if (HA_handle < 0) {
            Print("Runtime error = ", GetLastError());
            return(INIT_FAILED);
        }
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

    ArraySetAsSeries(close, true);

    if (HeikenAshi && BarsCalculated(HA_handle) < rates_total) return(0);
    if (rates_total <= LRPeriod + 1) return(0);

    int limit = rates_total - prev_calculated;
    int hcnt = limit;
    if (limit > 1) {
        ArrayInitialize(B1, 0.0);
        ArrayInitialize(B2, 0.0);
        limit = rates_total - LRPeriod - 1;
        hcnt = rates_total;
    }

    if (HeikenAshi) {
        hcnt = MathMax(LRPeriod + 1, hcnt);
        if (CopyBuffer(HA_handle, 3, 0, hcnt, HA_C) != hcnt) Print("Err: ", GetLastError());
        ArraySetAsSeries(HA_C, true);
    }

    for (int pos = limit; pos >= 0; pos--) {
        B2[pos] = HeikenAshi ? LRMA(pos, LRPeriod, HA_C) : LRMA(pos, LRPeriod, close);
    }

    for (int pos = limit; pos >= 0; pos--) {
        B1[pos] = 2 * B2[pos] - LRMA(pos, LRPeriod, B2);
    }

    return(rates_total);
}


//+------------------------------------------------------------------+
//| Calculate LRMA                                                   |
//+------------------------------------------------------------------+
double LRMA(const int pos, const int period, const double &price[]) {
    double res = 0;
    double tmpS = 0, tmpW = 0, wsum = 0;;
    for (int i = 0; i < period; i++) {
        tmpS += price[pos + i];
        tmpW += price[pos + i] * (period - i);
        wsum += (period - i);
    }
    tmpS /= period;
    tmpW /= wsum;
    res = 3.0 * tmpW - 2.0 * tmpS;
    return res;
}
//+------------------------------------------------------------------+
