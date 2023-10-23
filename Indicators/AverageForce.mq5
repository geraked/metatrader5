//+------------------------------------------------------------------+
//|                                                 AverageForce.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.1"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "AF"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

input int P = 20; // Period
input int S = 9; // Smooth

//--- indicator buffers
double AF[];
double C1[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, AF, INDICATOR_DATA);
    SetIndexBuffer(1, C1, INDICATOR_CALCULATIONS);
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

    if (rates_total <= MathMax(P, S)) return(0);

    ArraySetAsSeries(AF, false);
    ArraySetAsSeries(C1, false);
    if (prev_calculated == 0) {
        for (int i = 0; i <= MathMax(P, S); i++) {
            AF[i] = 0;
            C1[i] = 0;
        }
    }

    int limit = rates_total - prev_calculated;
    if (limit == 0) limit = 1;

    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(AF, true);
    ArraySetAsSeries(C1, true);

    for (int i = 0; i < limit && !IsStopped(); i++) {
        if (i + P >= rates_total) break;
        int ih = ArrayMaximum(high, i, P);
        int il = ArrayMinimum(low, i, P);
        double diff = high[ih] - low[il];
        C1[i] = diff == 0 ? 0 : (close[i] - low[il]) / diff - 0.5;
    }

    for (int i = 0; i < limit && !IsStopped(); i++) {
        if (i + S >= rates_total) break;
        double sum = 0;
        for (int j = i; j < i + S; j++)
            sum += C1[j];
        AF[i] = sum / S;
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
