//+------------------------------------------------------------------+
//|                                                 DailyHighLow.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.1"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

enum ENUM_DHL_PRICE {
    DHL_LOWHIGH, // Low/High
    DHL_OPENCLOSE, // Open/Close
    DHL_CLOSECLOSE // Close/Close
};

input ENUM_TIMEFRAMES TimeFrame = PERIOD_D1;
input bool Previous = true;
input ENUM_DHL_PRICE Price = DHL_LOWHIGH;

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
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(HighBuffer, true);
    ArraySetAsSeries(LowBuffer, true);

    if (prev_calculated == 0) {
        ArrayInitialize(HighBuffer, 0);
        ArrayInitialize(LowBuffer, 0);
    }

    int limit = rates_total - prev_calculated;
    if (limit == 0) limit = 1;

    int i1 = iBarShift(NULL, 0, iTime(NULL, TimeFrame, 1));
    int i2 = iBarShift(NULL, 0, iTime(NULL, TimeFrame, 2));
    if (i1 == -1 || i2 == -1) return(0);
    int k = i2 - i1;
    limit = MathMax(i2 - i1 + 2, limit);
    if (limit > rates_total) return(0);
    if (iBarShift(NULL, TimeFrame, time[rates_total - (i2 - i1 + 2)]) == -1) return(0);

    for (int i = 0; i < limit && !IsStopped(); i++) {
        int j = iBarShift(NULL, TimeFrame, time[i]);
        if (j == -1) continue;
        if (Previous) j += 1;

        if (Price == DHL_LOWHIGH) {
            HighBuffer[i] = iHigh(NULL, TimeFrame, j);
            LowBuffer[i] = iLow(NULL, TimeFrame, j);
        }

        else {
            int i1 = iBarShift(NULL, 0, iTime(NULL, TimeFrame, j));
            int i2 = j == 0 ? 0 : iBarShift(NULL, 0, iTime(NULL, TimeFrame, j - 1));
            int cnt = i1 - i2;

            if (cnt == 0) {
                cnt = 1;
            } else if (cnt == k) {
                if (i1 > i2)
                    i2++;
            } else if (cnt < k) {
                cnt++;
            }

            if (i2 + cnt >= rates_total) continue;

            if (Price == DHL_CLOSECLOSE) {
                HighBuffer[i] = close[iHighest(NULL, 0, MODE_CLOSE, cnt, i2)];
                LowBuffer[i] = close[iLowest(NULL, 0, MODE_CLOSE, cnt, i2)];
            }

            else if (Price == DHL_OPENCLOSE) {
                double hc = close[iHighest(NULL, 0, MODE_CLOSE, cnt, i2)];
                double ho = open[iHighest(NULL, 0, MODE_OPEN, cnt, i2)];
                double lc = close[iLowest(NULL, 0, MODE_CLOSE, cnt, i2)];
                double lo = open[iLowest(NULL, 0, MODE_OPEN, cnt, i2)];
                HighBuffer[i] = MathMax(hc, ho);
                LowBuffer[i] = MathMin(lc, lo);
            }
        }
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
