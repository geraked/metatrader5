//+------------------------------------------------------------------+
//|                                            Andean Oscillator.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   3

#property indicator_label1  "Bull"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Bear"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

input int Length = 50;
input int SignalLength = 9;

double Bull[];
double Bear[];
double Signal[];
double Up1[], Up2[], Dn1[], Dn2[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, Bull, INDICATOR_DATA);
    SetIndexBuffer(1, Bear, INDICATOR_DATA);
    SetIndexBuffer(2, Signal, INDICATOR_DATA);
    SetIndexBuffer(3, Up1, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, Up2, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, Dn1, INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, Dn2, INDICATOR_CALCULATIONS);
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

    if (rates_total < SignalLength + 1) return(0);

    int start;

    if (prev_calculated == 0) {
        Up1[0] = 0;
        Up2[0] = 0;
        Dn1[0] = 0;
        Dn2[0] = 0;
        Signal[0] = 0;
        start = 1;
    } else {
        start = prev_calculated - 1;
    }

    for (int i = start; i < rates_total && !IsStopped(); i++) {
        double t;
        double alpha = 2.0 / (Length + 1);

        t = MathMax(close[i], open[i]);
        Up1[i] = MathMax(t, Up1[i - 1] - (Up1[i - 1] - close[i]) * alpha);
        if (Up1[i] == 0) Up1[i] = close[i];

        t = MathMax(close[i] * close[i], open[i] * open[i]);
        Up2[i] = MathMax(t, Up2[i - 1] - (Up2[i - 1] - close[i] * close[i]) * alpha);
        if (Up2[i] == 0) Up2[i] = close[i] * close[i];

        t = MathMin(close[i], open[i]);
        Dn1[i] = MathMin(t, Dn1[i - 1] + (close[i] - Dn1[i - 1]) * alpha);
        if (Dn1[i] == 0) Dn1[i] = close[i];

        t = MathMin(close[i] * close[i], open[i] * open[i]);
        Dn2[i] = MathMin(t, Dn2[i - 1] + (close[i] * close[i] - Dn2[i - 1]) * alpha);
        if (Dn2[i] == 0) Dn2[i] = close[i] * close[i];

        Bull[i] = MathSqrt(Dn2[i] - Dn1[i] * Dn1[i]);
        Bear[i] = MathSqrt(Up2[i] - Up1[i] * Up1[i]);
        Signal[i] = MathMax(Bull[i], Bear[i]);
    }

    CalculateEMA(rates_total, prev_calculated, SignalLength, Signal);

    return(rates_total);
}

//+------------------------------------------------------------------+
//|  exponential moving average                                      |
//+------------------------------------------------------------------+
void CalculateEMA(int rates_total, int prev_calculated, int len, double &s[]) {
    int i, start;
    double SmoothFactor = 2.0 / (1.0 + len);
    if (prev_calculated == 0) {
        start = 1;
    } else {
        start = prev_calculated - 1;
    }
    for (i = start; i < rates_total && !IsStopped(); i++) {
        s[i] = s[i] * SmoothFactor + s[i - 1] * (1.0 - SmoothFactor);
    }
}
//+------------------------------------------------------------------+
