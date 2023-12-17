//+------------------------------------------------------------------+
//|                                                 WinINet_Test.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.00"

#include <WinINet.mqh>

//+------------------------------------------------------------------+
//| Get GMT time.                                                    |
//+------------------------------------------------------------------+
void Test1() {
    PrintFormat("********** %s:", __FUNCTION__);

    WininetRequest req;
    WininetResponse res;

    req.host = "worldtimeapi.org";
    req.path = "/api/timezone/Europe/London.txt";

    WebReq(req, res);

    Print("status: ", res.status);
    Print(res.GetDataStr());
    Print("\n");
}

//+------------------------------------------------------------------+
//| Echo back the POST request.                                      |
//+------------------------------------------------------------------+
void Test2() {
    PrintFormat("********** %s:", __FUNCTION__);

    WininetRequest req;
    WininetResponse res;

    req.method = "POST";
    req.host = "httpbin.org";
    req.path = "/post";
    req.port = 80;
    req.headers = "Accept: application/json\r\n"
                  "Content-Type: application/json; charset=UTF-8\r\n";

    req.data_str = "{'id': 10, 'title': 'foo', 'message': 'bar'}";
    StringReplace(req.data_str, "'", "\"");

    WebReq(req, res);

    Print("status: ", res.status);
    Print(res.GetDataStr());
    Print("");
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    Test1();
    Test2();
}
//+------------------------------------------------------------------+
