//+------------------------------------------------------------------+
//|                                                       DHLAOS.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.00"
#property description "A strategy using Daily High/Low and Andean Oscillator indicators for scalping"

#include <EAUtils.mqh>

input double TPCoef = 1.5;
input int SwingLookBack = 5;
input int SwingDevPoints = 50;
input int AosNCheck = 300;
input int DhlNCheck = 50;
// -------------------------------
input double Risk = 0.01;
input bool Reverse = false;
input bool MultipleOpenPos = true;
input int MagicSeed = 1;

GerEA ea;
datetime lastCandle;
int BuffSize;

#define PATH_AOS "Indicators\\AndeanOscillator.ex5"
#define I_AOS "::" + PATH_AOS
#resource "\\" + PATH_AOS
int AOS_handle;
double AOS_Bull[], AOS_Bear[], AOS_Signal[];

#define PATH_DHL "Indicators\\DailyHighLow.ex5"
#define I_DHL "::" + PATH_DHL
#resource "\\" + PATH_DHL
int DHL_handle;
double DHL_H[], DHL_L[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool c = AOS_Bull[2] <= AOS_Signal[2] &&  AOS_Bull[1] > AOS_Signal[1];
    if (!c) return false;

    int j = 0;
    for (int i = 3; i < AosNCheck; i++) {
        if (AOS_Bull[i + 1] >= AOS_Bear[i + 1] && AOS_Bull[i] < AOS_Bear[i])
            return false;
        if (AOS_Bull[i + 1] >= AOS_Signal[i + 1] && AOS_Bull[i] < AOS_Signal[i])
            return false;
        if (AOS_Bull[i + 1] <= AOS_Signal[i + 1] && AOS_Bull[i] > AOS_Signal[i])
            return false;
        if (AOS_Bull[i + 1] <= AOS_Bear[i + 1] && AOS_Bull[i] > AOS_Bear[i]) {
            j = i;
            break;
        }
    }

    bool c2 = false;
    for (int i = j; i < j + DhlNCheck; i++) {
        if (High(i) < DHL_L[i] && AOS_Bull[i] < AOS_Bear[i]) {
            c2 = true;
            break;
        }
    }
    if (!c2) return false;

    int il = iLowest(NULL, 0, MODE_LOW, SwingLookBack, 1);
    double sl = Low(il) - SwingDevPoints * _Point;

    double in = Ask();
    double tp = in + TPCoef * MathAbs(in - sl);

    ea.BuyOpen(sl, tp);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    bool c = AOS_Bear[2] <= AOS_Signal[2] &&  AOS_Bear[1] > AOS_Signal[1];
    if (!c) return false;

    int j = 0;
    for (int i = 3; i < AosNCheck; i++) {
        if (AOS_Bull[i + 1] <= AOS_Bear[i + 1] && AOS_Bull[i] > AOS_Bear[i])
            return false;
        if (AOS_Bear[i + 1] >= AOS_Signal[i + 1] && AOS_Bear[i] < AOS_Signal[i])
            return false;
        if (AOS_Bear[i + 1] <= AOS_Signal[i + 1] && AOS_Bear[i] > AOS_Signal[i])
            return false;
        if (AOS_Bull[i + 1] >= AOS_Bear[i + 1] && AOS_Bull[i] < AOS_Bear[i]) {
            j = i;
            break;
        }
    }

    bool c2 = false;
    for (int i = j; i < j + DhlNCheck; i++) {
        if (Low(i) > DHL_H[i] && AOS_Bull[i] > AOS_Bear[i]) {
            c2 = true;
            break;
        }
    }
    if (!c2) return false;

    int ih = iHighest(NULL, 0, MODE_HIGH, SwingLookBack, 1);
    double sl = High(ih) + SwingDevPoints * _Point;

    double in = Bid();
    double tp = in - TPCoef * MathAbs(in - sl);

    ea.SellOpen(sl, tp);
    return true;
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init(MagicSeed);
    ea.risk = Risk;
    ea.reverse = Reverse;

    BuffSize = AosNCheck + DhlNCheck + 2;

    AOS_handle = iCustom(NULL, 0, I_AOS);
    DHL_handle = iCustom(NULL, 0, I_DHL);

    if (AOS_handle == INVALID_HANDLE || DHL_handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        if (CopyBuffer(AOS_handle, 0, 0, BuffSize, AOS_Bull) <= 0) return;
        if (CopyBuffer(AOS_handle, 1, 0, BuffSize, AOS_Bear) <= 0) return;
        if (CopyBuffer(AOS_handle, 2, 0, BuffSize, AOS_Signal) <= 0) return;
        ArraySetAsSeries(AOS_Bull, true);
        ArraySetAsSeries(AOS_Bear, true);
        ArraySetAsSeries(AOS_Signal, true);

        if (CopyBuffer(DHL_handle, 0, 0, BuffSize, DHL_H) <= 0) return;
        if (CopyBuffer(DHL_handle, 1, 0, BuffSize, DHL_L) <= 0) return;
        ArraySetAsSeries(DHL_H, true);
        ArraySetAsSeries(DHL_L, true);

        if (!MultipleOpenPos && ea.PosTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}
//+------------------------------------------------------------------+
