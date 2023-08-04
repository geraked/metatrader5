//+------------------------------------------------------------------+
//|                                                  DarvasBoxes.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   6

#property indicator_color1 clrRoyalBlue
#property indicator_color2 clrTomato
#property indicator_color3 clrRoyalBlue
#property indicator_color4 clrTomato
#property indicator_color5 clrRoyalBlue
#property indicator_color6 clrTomato

#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 2
#property indicator_width4 2
#property indicator_width5 2
#property indicator_width6 2

#property description "Darvas Modes:"
#property description "0-Classic (by Upper Pivot)"
#property description "1-Modern (by Upper Pivot)"
#property description "2-Bi-directional Classic (UpTrend by Upper Pivot, DownTrend by Lower Pivot)"
#property description "3-Bi-directional Modern (UpTrend by Upper Pivot, DownTrend by Lower Pivot)"
#property description "4-Classic by 1st Pivot (Upper or Lower)"
#property description "5-Modern by 1st Pivot (Upper or Lower)"

//---- input parameters
extern int DarvasMode      = 3;    //Darvas Modes (See table above)
extern int PivotStrength   = 3;    //Pivot Strength in bars
extern int RollingPeriod   = 1;    //Rolling period of evaluation(Classic-12 months,Modern-6 months or less)
extern int BoxesMode       = 0;    //0-off,1-on
extern int ChannelMode     = 1;    //0-off,1-on
extern int PivotsMode      = 0;    //0-off,1-on
extern int GhostBoxesMode  = 0;    //0-off,1-on
extern int SignalMode      = 0;    //0-off,1-on

//---- buffers
double topBox[];
double botBox[];
double pivotHi[];
double pivotLo[];
double upSignal[];
double dnSignal[];
double trend[];

double HiArray[], LoArray[], boxTop[2], boxBottom[2], ghostHeight[2], ghostTop[2], ghostBottom[2], hiPrice[2], loPrice[2];
int    Length, startState[2], confirmState[2], prevState;
string short_name, IndicatorName, name;
datetime prevtime, startTime[2], endTime[2], ghostTime[2], prevTime, confTime, prevGhostTime;

int ATR_handle;
double ATR[];

int MAH_handle;
double MAH[];

int MAL_handle;
double MAL[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

    SetIndexBuffer(0, topBox);
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);

    SetIndexBuffer(1, botBox);
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);

    SetIndexBuffer(2, pivotHi);
    PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(2, PLOT_ARROW, 159);

    SetIndexBuffer(3, pivotLo);
    PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(3, PLOT_ARROW, 159);

    SetIndexBuffer(4, upSignal);
    PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(4, PLOT_ARROW, 233);

    SetIndexBuffer(5, dnSignal);
    PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(5, PLOT_ARROW, 234);

    SetIndexBuffer(6, trend, INDICATOR_CALCULATIONS);

    PlotIndexSetString(0, PLOT_LABEL, "Top of Darvas Box");
    PlotIndexSetString(1, PLOT_LABEL, "Bottom of Darvas Box");
    PlotIndexSetString(2, PLOT_LABEL, "Pivot High");
    PlotIndexSetString(3, PLOT_LABEL, "Pivot Low");
    PlotIndexSetString(4, PLOT_LABEL, "Up Signal");
    PlotIndexSetString(5, PLOT_LABEL, "Down Signal");

    Length = PivotStrength + 2;
    int begin = MathMax(2, Length);

    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, begin);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, begin);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, begin);
    PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, begin);

    ArrayResize(HiArray, Length);
    ArrayResize(LoArray, Length);

    ATR_handle = iATR(NULL, 0, 14);
    MAH_handle = iMA(NULL, 0, 1, 0, 0, PRICE_HIGH);
    MAL_handle = iMA(NULL, 0, 1, 0, 0, PRICE_LOW);

    if(ATR_handle < 0 || MAH_handle < 0 || MAL_handle < 0) {
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
    if (BarsCalculated(MAH_handle) < rates_total) return(0);
    if (BarsCalculated(MAL_handle) < rates_total) return(0);

    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(topBox, true);
    ArraySetAsSeries(botBox, true);
    ArraySetAsSeries(pivotHi, true);
    ArraySetAsSeries(pivotLo, true);
    ArraySetAsSeries(upSignal, true);
    ArraySetAsSeries(dnSignal, true);
    ArraySetAsSeries(trend, true);

    int Bars = rates_total;
    int counted_bars = prev_calculated;
    int limit = 0;

    if (counted_bars < 0) return(0);
    if (counted_bars > 0 ) limit = Bars - counted_bars - 1;
    if (counted_bars == 0) limit = Bars - Length;

    if ( counted_bars < 1 ) {
        for(int i = 0; i < Bars; i++) {
            topBox[i]  = EMPTY_VALUE;
            botBox[i]  = EMPTY_VALUE;
            pivotHi[i] = EMPTY_VALUE;
            pivotLo[i] = EMPTY_VALUE;

            upSignal[i] = EMPTY_VALUE;
            dnSignal[i] = EMPTY_VALUE;
            trend[i] = EMPTY_VALUE;
        }
    }

    _DarvasBoxes(limit, counted_bars, time, open, high, low, close);

    ChartRedraw();

    return(rates_total);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void _DarvasBoxes(int limit, int counted_bars,
                  const datetime &time[],
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[]) {
    int hcnt = 0;
    if (counted_bars > 0 ) hcnt = limit + counted_bars + 1;
    if (counted_bars == 0) hcnt = limit + Length;

    if (CopyBuffer(ATR_handle, 0, 0, hcnt, ATR) <= 0) Print("Err: ", GetLastError());
    if (CopyBuffer(MAH_handle, 0, 0, hcnt, MAH) <= 0) Print("Err: ", GetLastError());
    if (CopyBuffer(MAL_handle, 0, 0, hcnt, MAL) <= 0) Print("Err: ", GetLastError());
    ArraySetAsSeries(ATR, true);
    ArraySetAsSeries(MAH, true);
    ArraySetAsSeries(MAL, true);

    for(int shift = limit; shift >= 0; shift--) {
        if(prevtime != time[shift]) {
            startState[1]   = startState[0];
            confirmState[1] = confirmState[0];
            boxTop[1]       = boxTop[0];
            boxBottom[1]    = boxBottom[0];
            startTime[1]    = startTime[0];
            endTime[1]      = endTime[0];
            ghostHeight[1]  = ghostHeight[0];
            ghostTime[1]    = ghostTime[0];
            ghostTop[1]     = ghostTop[0];
            ghostBottom[1]  = ghostBottom[0];
            hiPrice[1]      = hiPrice[0];
            loPrice[1]      = loPrice[0];
            prevtime        = time[shift];
        }

        for(int j = 0; j < Length; j++) {
            HiArray[j] = MAH[shift + j];
            LoArray[j] = MAL[shift + j];
        }

        double hiBoxPrice = high[shift];
        double loBoxPrice = low[shift];

        if(DarvasMode == 0 || DarvasMode == 2 || DarvasMode == 4) {
            hiPrice[0] = high[shift];
            loPrice[0] = low[shift];
        } else {
            hiPrice[0] = close[shift];
            loPrice[0] = close[shift];
        }

        trend[shift]  = trend[shift + 1];
        botBox[shift] = botBox[shift + 1];
        topBox[shift] = topBox[shift + 1];

        double upPivot = DarvasPivot(HiArray, 0, PivotStrength);
        double loPivot = DarvasPivot(LoArray, 1, PivotStrength);

        if(PivotsMode > 0) {
            pivotHi[shift + PivotStrength] = EMPTY_VALUE;
            pivotLo[shift + PivotStrength] = EMPTY_VALUE;

            if(upPivot > 0) pivotHi[shift + PivotStrength] = upPivot;
            if(loPivot > 0) pivotLo[shift + PivotStrength] = loPivot;
        }

        startState[0]   = startState[1];
        confirmState[0] = confirmState[1];
        boxTop[0]       = boxTop[1];
        boxBottom[0]    = boxBottom[1];
        startTime[0]    = startTime[1];
        endTime[0]      = endTime[1];
        ghostHeight[0]  = ghostHeight[1];
        ghostTime[0]    = ghostTime[1];
        ghostTop[0]     = ghostTop[1];
        ghostBottom[0]  = ghostBottom[1];


        if(startState[0] == 0) {
            bool allPivotVerify = false;

            bool upPivotVerify = upPivot > 0 && shift + PivotStrength == iHighest(NULL, 0, MODE_HIGH, RollingPeriod, shift + PivotStrength);
            bool loPivotVerify = loPivot > 0 && shift + PivotStrength == iLowest (NULL, 0, MODE_LOW, RollingPeriod, shift + PivotStrength);

            if(DarvasMode < 2) allPivotVerify = upPivotVerify;
            else if(DarvasMode < 4) {
                if(trend[shift] > 0) allPivotVerify = upPivotVerify;
                else allPivotVerify = loPivotVerify;
            } else allPivotVerify = upPivotVerify || loPivotVerify;

            if(allPivotVerify) {
                startTime[0] = time[shift + PivotStrength];
                if(startTime[0] >= endTime[0]) {
                    if(DarvasMode < 2) {
                        boxTop[0] = upPivot;
                        startState[0] = 1;
                    } else if(DarvasMode < 4) {
                        startState[0] = 1;
                        if(trend[shift] > 0) boxTop[0] = upPivot;
                        else boxBottom[0] = loPivot;
                    } else {
                        if(upPivotVerify || (upPivotVerify && loPivotVerify)) {
                            boxTop[0] = upPivot;
                            startState[0] = 1;
                        } else {
                            boxBottom[0] = loPivot;
                            startState[0] = -1;
                        }
                    }

                    prevTime  = startTime[0];
                    prevState = startState[0];
                }
            }
        }

        if(startState[0] != 0 && confirmState[0] == 0) {
            if(DarvasMode < 2) {
                if(upPivot > boxTop[0] || hiBoxPrice > boxTop[0]) {
                    startState[0] = 0;
                    startTime[0] = 0;
                } else if(loPivot > 0 && time[shift] > startTime[0]) {
                    confirmState[0] = 1;
                    boxBottom[0] = loPivot;
                    confTime = time[shift];
                }
            } else if(DarvasMode < 4) {

                if(trend[shift] > 0 && (upPivot > boxTop[0] || hiBoxPrice > boxTop[0])) {
                    startState[0] = 0;
                    startTime[0] = 0;
                } else if(trend[shift] < 0 && ((loPivot > 0 && loPivot < boxBottom[0]) || loBoxPrice < boxBottom[0])) {
                    startState[0] = 0;
                    startTime[0] = 0;
                } else if(time[shift] > startTime[0]) {
                    if(trend[shift] > 0 && loPivot > 0) {
                        confirmState[0] = 1;
                        boxBottom[0] = loPivot;
                        confTime = time[shift];
                    } else if(trend[shift] < 0 && upPivot > 0) {
                        confirmState[0] = 1;
                        boxTop[0]    = upPivot;
                        confTime = time[shift];
                    }
                }
            } else {
                if(startState[0] > 0 && (upPivot > boxTop[0] || hiBoxPrice > boxTop[0])) {
                    startState[0] = 0;
                    startTime[0] = 0;
                } else if(startState[0] < 0 && ((loPivot > 0 && loPivot < boxBottom[0]) || loBoxPrice < boxBottom[0])) {
                    startState[0] = 0;
                    startTime[0] = 0;
                } else if(time[shift] > startTime[0]) {
                    if(startState[0] > 0 && loPivot > 0 && confirmState[0] == 0) {
                        confirmState[0] = 1;
                        boxBottom[0] = loPivot;
                        confTime = time[shift];
                    } else if(startState[0] < 0 && upPivot > 0 && confirmState[0] == 0) {
                        confirmState[0] = 1;
                        boxTop[0]    = upPivot;
                        confTime = time[shift];
                    }
                }
            }
        } else if(startState[0] != 0 && confirmState[0] != 0) {

            upSignal[shift] = EMPTY_VALUE;
            dnSignal[shift] = EMPTY_VALUE;

            double gap = 0.5 * MathCeil(ATR[shift] / _Point);

            if(hiPrice[0] > boxTop[0]) {
                trend[shift]    = 1;
                startState[0]   = 0;
                confirmState[0] = 0;
                endTime[0]      = time[shift];
                startTime[0]    = 0;
                if(SignalMode > 0) upSignal[shift] = low[shift] - gap * _Point;
            }

            if(loPrice[0] < boxBottom[0]) {
                trend[shift]    = -1;
                startState[0]   = 0;
                confirmState[0] = 0;
                endTime[0]      = time[shift];
                startTime[0]    = 0;
                if(SignalMode > 0) dnSignal[shift] = high[shift] + gap * _Point;
            }

            if(ChannelMode > 0) {
                botBox[shift] = boxBottom[0];
                topBox[shift] = boxTop[0];
            }

            if(endTime[0] != endTime[1]) {
                if(GhostBoxesMode > 0) {
                    ghostTime[0]   = endTime[0];
                    ghostHeight[0] = boxTop[0] - boxBottom[0];
                    prevGhostTime  = ghostTime[0];

                    if(trend[shift] > 0) {
                        ghostBottom[0] = boxTop[0];
                        ghostTop[0]    = ghostBottom[0] + ghostHeight[0];
                    } else {
                        ghostTop[0]    = boxBottom[0];
                        ghostBottom[0] = ghostTop[0] - ghostHeight[0];
                    }
                }
            }
        }


        if(GhostBoxesMode > 0) {
            if(trend[shift] > 0) {
                if(confirmState[0] == 0 || (confirmState[0] > 0 && confirmState[1] == 0)) {
                    if(hiPrice[0] > ghostTop[0] && hiPrice[1] <= ghostTop[1]) {
                        ghostTime[0]   = time[shift];
                        ghostBottom[0] = ghostTop[0];
                        ghostTop[0]    = ghostBottom[0] + ghostHeight[0];
                        prevGhostTime  = ghostTime[0];
                    }
                }
            } else {
                if(confirmState[0] == 0 || (confirmState[0] > 0 && confirmState[1] == 0)) {
                    if(loPrice[0] < ghostBottom[0] && loPrice[1] >= ghostBottom[1]) {
                        ghostTime[0]   = time[shift];
                        ghostTop[0]    = ghostBottom[0];
                        ghostBottom[0] = ghostTop[0] - ghostHeight[0];
                        prevGhostTime  = ghostTime[0];
                    }
                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double DarvasPivot(double& price[], int type, int size) {
    double upPivot;
    bool condition;

    if (type == 0) condition = ArrayMaximum(price, 0, 0) == size;
    else condition = ArrayMinimum(price, 0, 0) == size;

    if(condition) upPivot = price[size];
    else upPivot = 0;

    return(upPivot);
}

//+------------------------------------------------------------------+
