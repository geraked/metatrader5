//+------------------------------------------------------------------+
//|                                                 DailyHighLow.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightCyan
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCyan
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

input ENUM_TIMEFRAMES TimeFrame = PERIOD_D1;
input bool Previous = true;

double HighBuffer[];
double LowBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, HighBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, LowBuffer, INDICATOR_DATA);
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

    ArraySetAsSeries(time, true);
    ArraySetAsSeries(HighBuffer, true);
    ArraySetAsSeries(LowBuffer, true);

    int limit = rates_total - prev_calculated;
    if (limit == 0) limit = 1;

    for (int i = 0; i < limit && !IsStopped(); i++) {
        int j = iBarShift(NULL, TimeFrame, time[i]);
        if (Previous) j += 1;
        HighBuffer[i] = iHigh(NULL, TimeFrame, j);
        LowBuffer[i] = iLow(NULL, TimeFrame, j);
    }

    return(rates_total);
}
//+------------------------------------------------------------------+
