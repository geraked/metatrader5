//+------------------------------------------------------------------+
//|                                                   OrderBlock.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "BullUpper"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrCyan
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "BullLower"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCyan
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "BearUpper"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "BearLower"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrMagenta
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

enum ENUM_OB_MODE {
    OB_MODE_DEFAULT, // Default
    OB_MODE_FVG // Fair Value Gap (FVG)
};

input ENUM_OB_MODE Mode = OB_MODE_DEFAULT;

//--- indicator buffers
double BullUpper[];
double BullLower[];
double BearUpper[];
double BearLower[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, BullUpper, INDICATOR_DATA);
    SetIndexBuffer(1, BullLower, INDICATOR_DATA);
    SetIndexBuffer(2, BearUpper, INDICATOR_DATA);
    SetIndexBuffer(3, BearLower, INDICATOR_DATA);

    PlotIndexSetInteger(0, PLOT_ARROW, 59);
    PlotIndexSetInteger(1, PLOT_ARROW, 59);
    PlotIndexSetInteger(2, PLOT_ARROW, 59);
    PlotIndexSetInteger(3, PLOT_ARROW, 59);

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
        ArrayInitialize(BullUpper, 0);
        ArrayInitialize(BullLower, 0);
        ArrayInitialize(BearUpper, 0);
        ArrayInitialize(BearLower, 0);
        limit = limit - 1 - 4;
    }

    if (rates_total < 4) return(0);
    if (limit < 0) return(0);

    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(BullUpper, true);
    ArraySetAsSeries(BullLower, true);
    ArraySetAsSeries(BearUpper, true);
    ArraySetAsSeries(BearLower, true);

    for (int i = limit; i >= 0 && !IsStopped(); i--) {

        if (Mode == OB_MODE_DEFAULT) {
            bool bu = close[i + 2] < open[i + 2] && close[i + 1] < open[i + 1] && close[i] > open[i];
            bool be = close[i + 2] > open[i + 2] && close[i + 1] > open[i + 1] && close[i] < open[i];
            bu &= close[i + 1] < low[i + 2] && close[i] > high[i + 1];
            be &= close[i + 1] > high[i + 2] && close[i] < low[i + 1];

            if (bu) {
                BullUpper[i] = high[i + 1];
                BullLower[i] = low[i + 1];
            } else {
                BullUpper[i] = 0;
                BullLower[i] = 0;
            }

            if (be) {
                BearUpper[i] = high[i + 1];
                BearLower[i] = low[i + 1];
            } else {
                BearUpper[i] = 0;
                BearLower[i] = 0;
            }
        }

        else if (Mode == OB_MODE_FVG) {
            bool bu = close[i + 3] < open[i + 3] && close[i + 2] < open[i + 2] && close[i + 1] > open[i + 1];
            bool be = close[i + 3] > open[i + 3] && close[i + 2] > open[i + 2] && close[i + 1] < open[i + 1];
            bu &= close[i + 2] < low[i + 3] && close[i + 1] > high[i + 2] && low[i] > high[i + 2];
            be &= close[i + 2] > high[i + 3] && close[i + 1] < low[i + 2] && high[i] < low[i + 2];

            if (bu) {
                BullUpper[i] = low[i];
                BullLower[i] = low[i + 2];
            } else {
                BullUpper[i] = 0;
                BullLower[i] = 0;
            }

            if (be) {
                BearUpper[i] = high[i + 2];
                BearLower[i] = high[i];
            } else {
                BearUpper[i] = 0;
                BearLower[i] = 0;
            }
        }

    }

    return(rates_total);
}

//+------------------------------------------------------------------+
