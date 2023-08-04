//+---

#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#define PREFIX "ger_boxline_"

#property indicator_label1  "Box Middle"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCyan
#property indicator_style1  STYLE_DASH
#property indicator_width1  1

#property indicator_label2  "Box Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCyan
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Box Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCyan
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "Box IsBullish"
#property indicator_type4   DRAW_NONE


input bool showBoxes = true;
input color hcolor = clrLightBlue; // Color of Bullish box
input color lcolor = clrLightPink; // Color of Bearish box


//--- buffers
double middle[];
double top[];
double bottom[];
double boxColor[];

int k;


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    ObjectsDeleteAll(0, PREFIX);
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

    SetIndexBuffer(0, middle);
    SetIndexBuffer(1, top);
    SetIndexBuffer(2, bottom);
    SetIndexBuffer(3, boxColor);

    return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, PREFIX);
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
//---
    if (rates_total < 2) return 0;

    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(top, false);
    ArraySetAsSeries(bottom, false);
    ArraySetAsSeries(boxColor, false);
    ArraySetAsSeries(middle, false);

    if (prev_calculated == 0) {
        k = 0;
        top[k] = high[k];
        bottom[k] = low[k];
        boxColor[k] = false;
        middle[k] = (top[k] + bottom[k]) / 2;
    }

    int pos = 0;
    if (prev_calculated > 1) pos = prev_calculated - 1;

    for (int i = pos; i < rates_total - 1 && !IsStopped(); i++) {

        bool check = (close[i] > top[k] || close[i] < bottom[k]);
        //if (openCheck) check = (check || open[i] > top[k] || open[i] < bottom[k]);

        if (check) {
            for (int j = k; j < i; j++) {
                top[j] = top[k];
                bottom[j] = bottom[k];
                boxColor[j] = boxColor[k];
                middle[j] = (top[j] + bottom[j]) / 2;
            }

            if (showBoxes) {
                color objcolor = !boxColor[k] ? lcolor : hcolor;
                string bname = PREFIX + "b" + (string) k;
                ObjectCreate(ChartID(), bname, OBJ_RECTANGLE, 0, time[k], top[k], time[i], bottom[k]);
                ObjectSetInteger(ChartID(), bname, OBJPROP_COLOR, objcolor);
                ObjectSetInteger(ChartID(), bname, OBJPROP_FILL, objcolor);
                ObjectSetInteger(ChartID(), bname, OBJPROP_BACK, true);
            }

            k = i;
            top[k] = high[k];
            bottom[k] = low[k];
            boxColor[k] = !(k > 0 && close[k] < bottom[k - 1]);
            middle[k] = (top[k] + bottom[k]) / 2;
        }

        top[i] = top[k];
        bottom[i] = bottom[k];
        boxColor[i] = boxColor[k];
        middle[i] = (top[i] + bottom[i]) / 2;

        if (high[i] > top[k] || low[i] < bottom[k]) {
            if (high[i] > top[k]) top[k] = high[i];
            if (low[i] < bottom[k]) bottom[k] = low[i];
            for (int j = k; j <= i; j++) {
                top[j] = top[k];
                bottom[j] = bottom[k];
                middle[j] = (top[j] + bottom[j]) / 2;
            }
        }
    }


//--- return value of prev_calculated for next call
    return(rates_total);
}
//+------------------------------------------------------------------+
