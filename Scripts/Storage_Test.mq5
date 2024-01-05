//+------------------------------------------------------------------+
//|                                                 Storage_Test.mq5 |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#include <Storage.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    Print("***** Storage Library Test:");

    datetime time = TimeCurrent();
    datetime stime = TimeSystem();
    StorageDeleteAll("test_");

    Print("Test 1:  ", StorageGet("test_long", LONG_MAX) == LONG_MAX);
    Print("Test 2:  ", StorageGet("test_double", DBL_MAX) == DBL_MAX);
    Print("Test 3:  ", StorageGet("test_string", "Hello World") == "Hello World");
    Print("Test 4:  ", StorageGet("test_time", time) == time);

    StorageSet("test_long", LONG_MAX);
    StorageSet("test_double", DBL_MAX);
    StorageSet("test_string", "Hello World");
    StorageSet("test_time", time);

    Print("Test 5:  ", StorageGet("test_long", (long) 0) == LONG_MAX);
    Print("Test 6:  ", StorageGet("test_double", (double) 0) == DBL_MAX);
    Print("Test 7:  ", StorageGet("test_string", "") == "Hello World");
    Print("Test 8:  ", StorageGet("test_time", (datetime) 0) == time);

    StorageSet("test_long", -LONG_MAX);

    Print("Test 9:  ", StorageGet("test_long", (long) 0) == -LONG_MAX);

    StorageDel("test_long");
    StorageDel("test_test");

    Print("Test 10: ", StorageGet("test_long", (long) 0) == 0);
    Print("Test 11: ", StorageLastUpdate("test_long") == 0);
    Print("Test 12: ", StorageLastUpdate("test_double") - stime <= 1);

    StorageDeleteAll("test_");
    Print("");
}

//+------------------------------------------------------------------+
