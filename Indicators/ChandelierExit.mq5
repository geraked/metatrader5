//+------------------------------------------------------------------+
//|                                               ChandelierExit.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 3
#property indicator_plots   2

#property indicator_color1 clrLawnGreen
#property indicator_color2 clrOrange

#property indicator_type1 DRAW_ARROW
#property indicator_type2 DRAW_ARROW

#property indicator_width1 1
#property indicator_width2 1

#property indicator_label1 "CE Buy"
#property indicator_label2 "CE Sell"

input int ATRPeriod = 1; // ATR Period
input double ATRMult = 0.75; // ATR Multiplier

// Buffers
double BuySignal[];
double SellSignal[];
double Dir[];

#define PATH_HA "Indicators\\Examples\\Heiken_Ashi.ex5"
#define I_HA "::" + PATH_HA
#resource "\\" + PATH_HA
int HA_handle;
double HA_C[];

#define PATH_ATR "Indicators\\ATR_HeikenAshi.ex5"
#define I_ATR "::" + PATH_ATR
#resource "\\" + PATH_ATR
int ATR_handle;
double ATR[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, BuySignal);
    PlotIndexSetInteger(0, PLOT_ARROW, 233);

    SetIndexBuffer(1, SellSignal);
    PlotIndexSetInteger(1, PLOT_ARROW, 234);

    SetIndexBuffer(2, Dir, INDICATOR_CALCULATIONS);

    ATR_handle = iCustom(NULL, 0, I_ATR, ATRPeriod);
    HA_handle = iCustom(NULL, 0, I_HA);

    if (ATR_handle < 0 || HA_handle < 0) {
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

    if (BarsCalculated(ATR_handle) < rates_total) return(0);
    if (BarsCalculated(HA_handle) < rates_total) return(0);

    if (rates_total < 2 + ATRPeriod) return(0);
    if (prev_calculated == rates_total) return(rates_total);

    int start;
    if (prev_calculated == 0) {
        for (int i = 0; i < 3; i++) {
            Dir[i] = 1;
            BuySignal[i] = 0;
            SellSignal[i] = 0;
        }
        start = 1 + ATRPeriod - 1;
    } else {
        start = prev_calculated - 1;
    }

    int to_copy = rates_total;
    if (CopyBuffer(ATR_handle, 0, BarsCalculated(ATR_handle) - rates_total, to_copy, ATR) <= 0) return(0);
    if (CopyBuffer(HA_handle, 3, BarsCalculated(HA_handle) - rates_total, to_copy, HA_C) <= 0) return(0);

    for (int i = start; i < rates_total && !IsStopped(); i++) {
        double atr1, atr2;
        double longStop, longStop1, longStop2;
        double shortStop, shortStop1, shortStop2;
        bool buyChk, sellChk;

        atr1 = ATR[i] * ATRMult;
        atr2 = ATR[i - 1] * ATRMult;

        longStop1 = HA_C[ArrayMaximum(HA_C, i - ATRPeriod + 1, ATRPeriod)] - atr1;
        longStop2 = HA_C[ArrayMaximum(HA_C, i - 1 - ATRPeriod + 1, ATRPeriod)] - atr2;
        longStop = HA_C[i - 1] > longStop2 ? MathMax(longStop1, longStop2) : longStop1;

        shortStop1 = HA_C[ArrayMinimum(HA_C, i - ATRPeriod + 1, ATRPeriod)] + atr1;
        shortStop2 = HA_C[ArrayMinimum(HA_C, i - 1 - ATRPeriod + 1, ATRPeriod)] + atr2;
        shortStop = HA_C[i - 1] < shortStop2 ? MathMin(shortStop1, shortStop2) : shortStop1;

        Dir[i] = HA_C[i] > shortStop2 ? 1 : HA_C[i] < longStop2 ? -1 : Dir[i - 1];

        buyChk = Dir[i] == 1 && Dir[i - 1] == -1;
        sellChk = Dir[i] == -1 && Dir[i - 1] == 1;

        BuySignal[i] = buyChk ? longStop : 0;
        SellSignal[i] = sellChk ? shortStop : 0;
    }

    return(rates_total);
}
//+------------------------------------------------------------------+
