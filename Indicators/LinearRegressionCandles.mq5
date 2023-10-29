//+------------------------------------------------------------------+
//|                                      LinearRegressionCandles.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   2

#property indicator_label1  "LRC"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrRed,clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "LRC Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

input int LrLen = 11; // Linear Regression Length
input int SmaLen = 7; // Signal Length

double B1[];
double B2[];
double B3[];
double B4[];
double C[];
double S[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, B1, INDICATOR_DATA);
    SetIndexBuffer(1, B2, INDICATOR_DATA);
    SetIndexBuffer(2, B3, INDICATOR_DATA);
    SetIndexBuffer(3, B4, INDICATOR_DATA);
    SetIndexBuffer(4, C, INDICATOR_COLOR_INDEX);
    SetIndexBuffer(5, S, INDICATOR_DATA);
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

    if (prev_calculated == 0) {
        ArrayInitialize(B1, 0);
        ArrayInitialize(B2, 0);
        ArrayInitialize(B3, 0);
        ArrayInitialize(B4, 0);
        ArrayInitialize(C, 0);
        ArrayInitialize(S, 0);
        limit = rates_total - MathMax(LrLen, SmaLen) - 1;
    }

    if (rates_total <= MathMax(LrLen, SmaLen) + 1) return(0);

    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(B1, true);
    ArraySetAsSeries(B2, true);
    ArraySetAsSeries(B3, true);
    ArraySetAsSeries(B4, true);
    ArraySetAsSeries(C, true);
    ArraySetAsSeries(S, true);

    for (int i = limit; i >= 0 && !IsStopped(); i--) {
        B1[i] = LRMA(i, LrLen, open);
        B2[i] = LRMA(i, LrLen, high);
        B3[i] = LRMA(i, LrLen, low);
        B4[i] = LRMA(i, LrLen, close);
        C[i] = B4[i] < B1[i] ? 0 : 1;
    }

    for (int i = limit; i >= 0 && !IsStopped(); i--) {
        double sum = 0;
        for (int j = i; j < i + SmaLen; j++)
            sum += B4[j];
        S[i] = sum / SmaLen;
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
