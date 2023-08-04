//+------------------------------------------------------------------+
//|                                                         Grid.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"
#property indicator_chart_window

#define PREFIX "ger_grid_"

input int InpP1 = 30; // Points
input color InpColor = clrCyan; // Color
input ENUM_LINE_STYLE InpStyle = STYLE_DOT; // Style
input int InpMaxBars = 10000; // Max Bars

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    ObjectsDeleteAll(0, PREFIX);

    int bars = MathMin(Bars(NULL, 0), InpMaxBars);
    int imax = iHighest(NULL, 0, MODE_HIGH, bars);
    int imin = iLowest(NULL, 0, MODE_LOW, bars);
    double max = iHigh(NULL, 0, imax);
    double min = iLow(NULL, 0, imin);

    int s = (int) MathFloor(min / _Point);
    int e = (int) MathCeil(max / _Point);
    s -= s % InpP1;
    e -= e % InpP1;
    e += InpP1;

    for (int i = s; i <= e; i += InpP1) {
        double v = NormalizeDouble(i * _Point, _Digits);
        datetime t1 = iTime(NULL, 0, 0);
        datetime t2 = iTime(NULL, 0, 1);
        string name = PREFIX + DoubleToString(v, _Digits);

        ObjectCreate(0, name, OBJ_TREND, 0, t1, v, t2, v);
        ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, true);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, name, OBJPROP_COLOR, InpColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, InpStyle);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }

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

    return(rates_total);
}
//+------------------------------------------------------------------+
