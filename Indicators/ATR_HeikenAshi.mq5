//+------------------------------------------------------------------+
//|                                               ATR_HeikenAshi.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.00"
#property description "Average True Range Based on HeikenAshi"

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  DodgerBlue

//--- input parameters
input int InpAtrPeriod = 14; // Period

//--- indicator buffers
double ATR[];
double TR[];

//--- HA buffers
double HA_O[];
double HA_H[];
double HA_L[];
double HA_C[];

int ExtPeriodATR;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit() {
    // check for input value
    if(InpAtrPeriod <= 0) {
        ExtPeriodATR = 14;
        PrintFormat("Incorrect input parameter InpAtrPeriod = %d. Indicator will use value %d for calculations.", InpAtrPeriod, ExtPeriodATR);
    } else {
        ExtPeriodATR = InpAtrPeriod;
    }

    // indicator buffers mapping
    SetIndexBuffer(0, ATR, INDICATOR_DATA);
    SetIndexBuffer(1, TR, INDICATOR_CALCULATIONS);
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

    // sets first bar from what index will be drawn
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpAtrPeriod);

    // name for DataWindow and indicator subwindow label
    string short_name = StringFormat("ATR HA (%d)", ExtPeriodATR);
    IndicatorSetString(INDICATOR_SHORTNAME, short_name);
    PlotIndexSetString(0, PLOT_LABEL, short_name);

    SetIndexBuffer(2, HA_O, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, HA_H, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, HA_L, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, HA_C, INDICATOR_CALCULATIONS);
}


//+------------------------------------------------------------------+
//| Average True Range                                               |
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

    HAOnCalculate(rates_total,
                  prev_calculated,
                  time,
                  open,
                  high,
                  low,
                  close,
                  tick_volume,
                  volume,
                  spread);

    if(rates_total <= ExtPeriodATR) return(0);

    // preliminary calculations
    int i, start;
    if (prev_calculated == 0) {
        TR[0] = 0.0;
        ATR[0] = 0.0;

        // filling out the array of True Range values for each period
        for (i = 1; i < rates_total && !IsStopped(); i++)
            TR[i] = MathMax(HA_H[i], HA_C[i - 1]) - MathMin(HA_L[i], HA_C[i - 1]);

        // first AtrPeriod values of the indicator are not calculated
        double firstValue = 0.0;
        for (i = 1; i <= ExtPeriodATR; i++) {
            ATR[i] = 0.0;
            firstValue += TR[i];
        }

        // calculating the first value of the indicator
        firstValue /= ExtPeriodATR;
        ATR[ExtPeriodATR] = firstValue;
        start = ExtPeriodATR + 1;

    } else {
        start = prev_calculated - 1;
    }

    // the main loop of calculations
    for (i = start; i < rates_total && !IsStopped(); i++) {
        TR[i] = MathMax(HA_H[i], HA_C[i - 1]) - MathMin(HA_L[i], HA_C[i - 1]);
        ATR[i] = ATR[i - 1] + (TR[i] - TR[i - ExtPeriodATR]) / ExtPeriodATR;
    }

    // return value of prev_calculated for next call
    return(rates_total);
}


//+------------------------------------------------------------------+
//| Heiken Ashi                                                      |
//+------------------------------------------------------------------+
int HAOnCalculate(const int rates_total,
                  const int prev_calculated,
                  const datetime &time[],
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  const long &tick_volume[],
                  const long &volume[],
                  const int &spread[]) {
    int start;

    if (prev_calculated == 0) {
        HA_L[0] = low[0];
        HA_H[0] = high[0];
        HA_O[0] = open[0];
        HA_C[0] = close[0];
        start = 1;
    } else {
        start = prev_calculated - 1;
    }

    for (int i = start; i < rates_total && !IsStopped(); i++) {
        double ha_open = (HA_O[i - 1] + HA_C[i - 1]) / 2;
        double ha_close = (open[i] + high[i] + low[i] + close[i]) / 4;
        double ha_high = MathMax(high[i], MathMax(ha_open, ha_close));
        double ha_low  = MathMin(low[i], MathMin(ha_open, ha_close));
        HA_L[i] = ha_low;
        HA_H[i] = ha_high;
        HA_O[i] = ha_open;
        HA_C[i] = ha_close;
    }

    return(rates_total);
}
//+------------------------------------------------------------------+
