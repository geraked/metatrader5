//+------------------------------------------------------------------+
//|                                             KijunSenEnvelope.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_width1 2
#property indicator_width2 1
#property indicator_width3 2

#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_DASH
#property indicator_style3 STYLE_SOLID

#property indicator_color1 clrCyan
#property indicator_color2 clrCyan
#property indicator_color3 clrCyan

#property indicator_type1 DRAW_LINE
#property indicator_type2 DRAW_LINE
#property indicator_type3 DRAW_LINE

#property indicator_label1 "Top Env Band"
#property indicator_label2 "KijunSen"
#property indicator_label3 "Bottom Env Band"

input int Kijun_Sen_Period = 100; // Kijun Sen Period
input int Envelope_Deviation = 230; // Envelope Deviation
input int ShiftKijun = 0; // Shift

double Kijun_Buffer_1[];
double Kijun_Buffer_2[];
double Kijun_Buffer_3[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    int begin = Kijun_Sen_Period + ShiftKijun - 1;

    SetIndexBuffer(0, Kijun_Buffer_1);
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, begin);
    PlotIndexSetInteger(0, PLOT_SHIFT, ShiftKijun);

    SetIndexBuffer(1, Kijun_Buffer_2);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, begin);
    PlotIndexSetInteger(1, PLOT_SHIFT, ShiftKijun);

    SetIndexBuffer(2, Kijun_Buffer_3);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, begin);
    PlotIndexSetInteger(2, PLOT_SHIFT, ShiftKijun);

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

    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(Kijun_Buffer_1, true);
    ArraySetAsSeries(Kijun_Buffer_2, true);
    ArraySetAsSeries(Kijun_Buffer_3, true);

    int Bars = rates_total;
    int counted_bars = prev_calculated;

    int i, k;
    double highx, lowx, pricex;

    if (Bars <= Kijun_Sen_Period) return (0);
    if (counted_bars < 1) {
        for (i = 1; i <= Kijun_Sen_Period; i++)
            Kijun_Buffer_1[Bars - i] = 0;
        Kijun_Buffer_2[Bars - i] = 0;
        Kijun_Buffer_3[Bars - i] = 0;
    }

    i = Bars - Kijun_Sen_Period;
    if (counted_bars > Kijun_Sen_Period) i = Bars - counted_bars - 1;
    while (i >= 0) {
        highx = high[i];
        lowx = low[i];
        k = i - 1 + Kijun_Sen_Period;
        while (k >= i) {
            pricex = high[k];
            if (highx < pricex) highx = pricex;
            pricex = low[k];
            if (lowx > pricex) lowx = pricex;
            k--;
        }
        Kijun_Buffer_1[i + ShiftKijun] = ((highx + lowx) / 2) + Envelope_Deviation * _Point;
        Kijun_Buffer_2[i + ShiftKijun] = ((highx + lowx) / 2);
        Kijun_Buffer_3[i + ShiftKijun] = ((highx + lowx) / 2) - Envelope_Deviation * _Point;
        i--;
    }
    i = ShiftKijun - 1;

    return(rates_total);
}

//+------------------------------------------------------------------+
