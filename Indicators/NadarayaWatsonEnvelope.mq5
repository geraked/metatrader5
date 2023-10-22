//+------------------------------------------------------------------+
//|                                       NadarayaWatsonEnvelope.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_label1  "NWE Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_style1  STYLE_DASH
#property indicator_width1  1

#property indicator_label2  "NWE Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

input double BandWidth = 8.0;
input double Multiplier = 3.0;
input int WindowSize = 500;

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

    if (rates_total <= WindowSize) return(0);

    int limit = rates_total - prev_calculated;
    if (limit == 0) limit = 1;

    ArraySetAsSeries(close, true);
    ArraySetAsSeries(Upper, true);
    ArraySetAsSeries(Lower, true);
    ArraySetAsSeries(C1, true);

    for (int i = 0; i < limit && !IsStopped(); i++) {
        double ws = 0;
        double s = 0;
        for (int j = i; j < i + WindowSize && j < rates_total; j++) {
            int k = j - i;
            double g = gauss(k, BandWidth);
            ws += close[j] * g;
            s += g;
        }

        Upper[i] = ws / s;
        C1[i] = MathAbs(close[i] - Upper[i]);
    }

    for (int i = 0; i < limit && !IsStopped(); i++) {
        double s = 0;
        for (int j = i; j < i + WindowSize && j < rates_total; j++)
            s += C1[j];
        Lower[i] = s / WindowSize * Multiplier;

        double t = Upper[i];
        Upper[i] = t + Lower[i];
        Lower[i] = t - Lower[i];
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double gauss(int x, double h) {
    return MathExp(-(MathPow(x, 2) / (h * h * 2)));
}
//+------------------------------------------------------------------+
