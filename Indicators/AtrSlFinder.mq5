//+------------------------------------------------------------------+
//|                                                  AtrSlFinder.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_label1  "ASF Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "ASF Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSkyBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

input int Length = 14;
input double Multiplier = 1.5;

double Upper[];
double Lower[];
double C1[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, Upper);
    SetIndexBuffer(1, Lower);
    SetIndexBuffer(2, C1, INDICATOR_CALCULATIONS);
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

    if (rates_total <= Length) return(0);

    int limit = rates_total - prev_calculated;
    if (limit == 0) limit = 1;

    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(Upper, true);
    ArraySetAsSeries(Lower, true);
    ArraySetAsSeries(C1, true);

    for (int i = 0; i < limit && !IsStopped(); i++) {
        if (i + 1 >= rates_total) break;
        double t = MathMax(high[i] - low[i], MathAbs(high[i] - close[i + 1]));
        C1[i] = MathMax(t, MathAbs(low[i] - close[i + 1]));
    }

    for (int i = 0; i < limit && !IsStopped(); i++) {
        if (i + 1 >= rates_total) break;

        double s = 0;
        for (int j = i; j < i + Length && j < rates_total; j++)
            s += C1[j];
        double ma = s / Length;

        Upper[i] = ma * Multiplier + high[i];
        Lower[i] = low[i] - ma * Multiplier;
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
