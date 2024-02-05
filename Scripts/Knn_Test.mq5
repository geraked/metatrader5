//+------------------------------------------------------------------+
//|                                                     Knn_Test.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#include <Knn.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    Print("***** K-Nearest Neighbors (KNN) Library Test:");

    matrix X = {
        {0, 0},
        {-5, 0},
        {-5, 5},
        {-5, -5},
        {0, 5},
        {0, -5},
        {8, 3},
        {8, -3}
    };

    vector y = {1, 1, 1, 1, 2, 2, 2, 2};

    matrix x1 = {{5, 0}};
    matrix x2 = {{1, 1}};
    matrix x3 = {{-2, 1}};

    CKnn knn = CKnn(1, 10, DISTANCE_MANHATTAN, 0);
    knn.Fit(X, y);

    Print("Test 1:  ", knn.Predict(x1)[0] == 1);
    Print("Test 2:  ", knn.Predict(x2)[0] == 1);
    Print("Test 3:  ", knn.Predict(x3)[0] == 1);

    knn = CKnn(5, 10, DISTANCE_MANHATTAN, 0);
    knn.Fit(X, y);

    Print("Test 4:  ", knn.Predict(x1)[0] == 2);
    Print("Test 5:  ", knn.Predict(x2)[0] == 2);
    Print("Test 6:  ", knn.Predict(x3)[0] == 1);

    Print("");
}

//+------------------------------------------------------------------+
