//+------------------------------------------------------------------+
//|                                                 DailyHighLow.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.3"
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

ENUM_TIMEFRAMES tf;

double HighBuffer[];
double LowBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, HighBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, LowBuffer, INDICATOR_DATA);
    tf = PeriodSeconds(TimeFrame) < PeriodSeconds(PERIOD_CURRENT) ? PERIOD_CURRENT : TimeFrame;
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

    int limit = rates_total - prev_calculated;
    if (limit == 0) limit = 1;

    int i1 = iBarShift(NULL, 0, iTime(NULL, tf, 1));
    int i2 = iBarShift(NULL, 0, iTime(NULL, tf, 2));
    if (i1 == -1 || i2 == -1) return(0);
    int k = i2 - i1;
    limit = MathMax(i2 - i1 + 2, limit);
    if (limit > rates_total) return(0);
    if (iBarShift(NULL, tf, time[rates_total - (i2 - i1 + 2)]) == -1) return(0);

    for (int i = 0; i < limit && !IsStopped(); i++) {
        int j = iBarShift(NULL, tf, time[i]);
        if (j == -1) continue;
        if (Previous) j += 1;

        if (Price == DHL_LOWHIGH) {
            HighBuffer[i] = iHigh(NULL, tf, j);
            LowBuffer[i] = iLow(NULL, tf, j);
        }

        else {
            int i1 = iBarShift(NULL, 0, iTime(NULL, tf, j));
            int i2 = j == 0 ? 0 : iBarShift(NULL, 0, iTime(NULL, tf, j - 1));
            int cnt = i1 - i2;

            if (cnt < k) {
                cnt++;
            } else if (cnt == k) {
                if (i1 > i2)
                    i2++;
            }

            int ihc = iHighest(NULL, 0, MODE_CLOSE, cnt, i2);
            int iho = iHighest(NULL, 0, MODE_OPEN, cnt, i2);
            int ilc = iLowest(NULL, 0, MODE_CLOSE, cnt, i2);
            int ilo = iLowest(NULL, 0, MODE_OPEN, cnt, i2);

            if (ihc < 0 || ihc >= rates_total) continue;
            if (iho < 0 || iho >= rates_total) continue;
            if (ilc < 0 || ilc >= rates_total) continue;
            if (ilo < 0 || ilo >= rates_total) continue;

            if (Price == DHL_CLOSECLOSE) {
                HighBuffer[i] = close[ihc];
                LowBuffer[i] = close[ilc];
            }

            else if (Price == DHL_OPENCLOSE) {
                HighBuffer[i] = MathMax(close[ihc], open[iho]);
                LowBuffer[i] = MathMin(close[ilc], open[ilo]);
            }
        }
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
