//+------------------------------------------------------------------+
//|                                                      WinINet.mqh |
//|                                     Copyright 2023-2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023-2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.6"

#define WININET_TIMEOUT_SECS   300
#define WININET_BUFF_SIZE      16384
#define WININET_KERNEL_ERRORS  true

#define INTERNET_FLAG_PRAGMA_NOCACHE            0x00000100
#define INTERNET_FLAG_KEEP_CONNECTION           0x00400000
#define INTERNET_FLAG_SECURE                    0x00800000
#define INTERNET_FLAG_RELOAD                    0x80000000
#define INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTP   0x00008000
#define INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTPS  0x00004000
#define INTERNET_FLAG_IGNORE_CERT_DATE_INVALID  0x00002000
#define INTERNET_FLAG_IGNORE_CERT_CN_INVALID    0x00001000
#define INTERNET_FLAG_NO_AUTO_REDIRECT          0x00200000

#define INTERNET_OPTION_HTTP_DECODING           65
#define INTERNET_OPTION_SEND_TIMEOUT            5
#define INTERNET_OPTION_RECEIVE_TIMEOUT         6
#define HTTP_QUERY_CONTENT_LENGTH               5
#define HTTP_QUERY_STATUS_CODE                  19
#define HTTP_QUERY_STATUS_TEXT                  20
#define HTTP_QUERY_RAW_HEADERS                  21
#define HTTP_QUERY_RAW_HEADERS_CRLF             22

#import "kernel32.dll"
uint GetLastError(void);
#import

#import "wininet.dll"
long InternetOpenW(const ushort &lpszAgent[], int dwAccessType, const ushort &lpszProxyName[], const ushort &lpszProxyBypass[], uint dwFlags);
long InternetConnectW(long hInternet, const ushort &lpszServerName[], int nServerPort, const ushort &lpszUsername[], const ushort &lpszPassword[], int dwService, uint dwFlags, int dwContext);
long HttpOpenRequestW(long hConnect, const ushort &lpszVerb[], const ushort &lpszObjectName[], const ushort &lpszVersion[], const ushort &lpszReferer[], const ushort &lplpszAcceptTypes[][], uint dwFlags, int dwContext);
int InternetCloseHandle(long hInternet);
int InternetSetOptionW(long hInternet, int dwOption, long &lpBuffer, int dwBufferLength);
int HttpAddRequestHeadersW(long hRequest, const ushort &lpszHeaders[], int dwHeadersLength, uint dwModifiers);
int HttpSendRequestW(long hRequest, const ushort &lpszHeaders[], int dwHeadersLength, const uchar &lpOptional[], int dwOptionalLength);
int HttpSendRequestExW(long hRequest, long lpBuffersIn, long lpBuffersOut, uint dwFlags, int dwContext);
int HttpEndRequestW(long hRequest, long lpBuffersOut, uint dwFlags, int dwContext);
int HttpQueryInfoW(long hRequest, int dwInfoLevel, uchar &lpvBuffer[], int &lpdwBufferLength, int &lpdwIndex);
int InternetWriteFile(long hFile, const uchar &lpBuffer[], int dwNumberOfBytesToWrite, int &lpdwNumberOfBytesWritten);
int InternetReadFile(long hFile, uchar &lpBuffer[], int dwNumberOfBytesToRead, int &lpdwNumberOfBytesRead);
#import

struct WininetRequest {
    string           method;
    string           host;
    int              port;
    string           path;
    string           headers;
    uchar            data[];
    string           data_str;
    void             WininetRequest() {
        method = "GET";
        port = 443;
        path = "/";
        headers = "";
    }
};

struct WininetResponse {
    int              status;
    string           headers;
    uchar            data[];
    string           GetDataStr() {
        return UnicodeUnescape(data);
    }
};

//+------------------------------------------------------------------+
//| HTTP request using wininet.dll                                   |
//+------------------------------------------------------------------+
int WebReq(
    const string  method,           // HTTP method
    const string  host,             // host name
    const string  path,             // URL path
    int           port,             // port number
    bool          secure,           // use HTTPS
    const string  headers,          // HTTP request headers
    const uchar   &data[],          // HTTP request body
    uchar         &result[],        // server response data
    string        &result_headers   // headers of server response
) {

//- Declare the variables.
    ushort buff[WININET_BUFF_SIZE / 2], buff2[WININET_BUFF_SIZE / 2];
    uchar cbuff[WININET_BUFF_SIZE];
    int n, bLen, bLen2, bIdx;
    long lval;
    long session, connection, request;
    int status;
    uint flags;
    string head;

//- Create the NULL string.
    ushort nill[2] = {0, 0};
    ushort nill2[2][2] = {{0, 0}, {0, 0}};

//- Create a session.
    StringToShortArray(GetUserAgent(), buff);
    session = InternetOpenW(buff, 0, nill, nill, 0);
    if (session <= 0)
        return _wininetErr("InternetOpen");

//- Enable automatically decoding from gzip and deflate.
    lval = 1;
    if (!InternetSetOptionW(session, INTERNET_OPTION_HTTP_DECODING, lval, sizeof(int)))
        return _wininetErr("InternetSetOption, DECODING", session);

//- Set timeouts.
    lval = WININET_TIMEOUT_SECS * 1000;
    if (!InternetSetOptionW(session, INTERNET_OPTION_SEND_TIMEOUT, lval, sizeof(int)))
        return _wininetErr("InternetSetOption, SEND_TIMEOUT", session);
    lval = WININET_TIMEOUT_SECS * 1000;
    if (!InternetSetOptionW(session, INTERNET_OPTION_RECEIVE_TIMEOUT, lval, sizeof(int)))
        return _wininetErr("InternetSetOption, RECEIVE_TIMEOUT", session);

//- Create a connection.
    StringToShortArray(host, buff);
    connection = InternetConnectW(session, buff, port, nill, nill, 3, 0, 0);
    if (connection <= 0)
        return _wininetErr("InternetConnect", session);

//- Open a request.
    StringToShortArray(method, buff);
    StringToShortArray(path, buff2);
    flags = INTERNET_FLAG_RELOAD | INTERNET_FLAG_PRAGMA_NOCACHE;
    flags |= INTERNET_FLAG_IGNORE_CERT_CN_INVALID | INTERNET_FLAG_IGNORE_CERT_DATE_INVALID;
    if (port == 443 || (secure && port != 80)) flags |= INTERNET_FLAG_SECURE;
    if (method == "GET") flags |= INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTP | INTERNET_FLAG_IGNORE_REDIRECT_TO_HTTPS;
    if (method != "GET") flags |= INTERNET_FLAG_NO_AUTO_REDIRECT;
    request = HttpOpenRequestW(connection, buff, buff2, nill, nill, nill2, flags, 0);
    if (request <= 0)
        return _wininetErr("HttpOpenRequest", session, connection);

//- Add request headers.
    n = ArraySize(data);
    if (n > 0 && data[n - 1] == 0) n--;
    head = StringFormat("Accept-Encoding: gzip, deflate\r\n"
                        "Content-Length: %d\r\n", n);
    bLen = StringToShortArray(head + headers, buff);
    if (bLen > 0 && buff[bLen - 1] == 0) bLen--;
    if (!HttpAddRequestHeadersW(request, buff, bLen, 0x80000000))
        return _wininetErr("HttpAddRequestHeaders", session, connection, request);

//- Send the request.
    int cnt = 1;
    while (!HttpSendRequestExW(request, 0, 0, 0, 0)) {
        if (cnt == 5)
            return _wininetErr("HttpSendRequestEx", session, connection, request);
        Sleep(1000);
        cnt++;
    }
    bIdx = 0;
    bLen2 = 0;
    while (true) {
        bLen = MathMin(WININET_BUFF_SIZE, n - bIdx);
        if (bLen <= 0) break;
        ArrayCopy(cbuff, data, 0, bIdx, bLen);
        if (!InternetWriteFile(request, cbuff, bLen, bLen2))
            return _wininetErr("InternetWriteFile", session, connection, request);
        bIdx += bLen2;
    }
    if (!HttpEndRequestW(request, 0, 0, 0))
        return _wininetErr("HttpEndRequest", session, connection, request);

//- Fetch the status code from the response header.
    bLen = WININET_BUFF_SIZE;
    bIdx = 0;
    if (!HttpQueryInfoW(request, HTTP_QUERY_STATUS_CODE, cbuff, bLen, bIdx))
        return _wininetErr("HttpQueryInfo, STATUS_CODE", session, connection, request);
    status = (int) UnicodeUnescape(cbuff, bLen);

//- Fetch the entire response header.
    bLen = WININET_BUFF_SIZE;
    bIdx = 0;
    if (!HttpQueryInfoW(request, HTTP_QUERY_RAW_HEADERS_CRLF, cbuff, bLen, bIdx))
        return _wininetErr("HttpQueryInfo, HEADER", session, connection, request);
    result_headers = UnicodeUnescape(cbuff, bLen);

//- Fetch the response body.
    bLen = 0;
    while (true) {
        if (!InternetReadFile(request, cbuff, WININET_BUFF_SIZE, bLen))
            return _wininetErr("InternetReadFile", session, connection, request);
        if (bLen <= 0) break;
        ArrayCopy(result, cbuff, ArraySize(result), 0, bLen);
    }

//- Close the request, connection, and session.
    if (!InternetCloseHandle(request))
        _wininetErr("InternetCloseRequest");
    if (!InternetCloseHandle(connection))
        _wininetErr("InternetCloseConnection");
    if (!InternetCloseHandle(session))
        _wininetErr("InternetCloseSession");

    return status;
}

//+------------------------------------------------------------------+
//| Overload                                                         |
//+------------------------------------------------------------------+
bool WebReq(WininetRequest &req, WininetResponse &res) {
    if (req.method == NULL || req.method == "") req.method = "GET";
    if (req.path == NULL || req.path == "") req.path = "/";
    if (req.headers == NULL) req.headers = "";
    if (req.port == 0) req.port = 443;
    if (ArraySize(req.data) > 0 || req.data_str == NULL)
        res.status = WebReq(req.method, req.host, req.path, req.port, false, req.headers, req.data, res.data, res.headers);
    else {
        uchar data_arr[];
        StringToCharArray(req.data_str, data_arr, 0, WHOLE_ARRAY, CP_UTF8);
        res.status = WebReq(req.method, req.host, req.path, req.port, false, req.headers, data_arr, res.data, res.headers);
    }
    if (res.status == -1) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Generate User-Agent for the HTTP request header.                 |
//+------------------------------------------------------------------+
string GetUserAgent() {
    return StringFormat(
               "%s/%d (%s; %s; %s %d Cores; %dMB RAM) WinINet/1.6",
               TerminalInfoString(TERMINAL_NAME),
               TerminalInfoInteger(TERMINAL_BUILD),
               TerminalInfoString(TERMINAL_OS_VERSION),
               TerminalInfoInteger(TERMINAL_X64) ? "x64" : "x32",
               TerminalInfoString(TERMINAL_CPU_NAME),
               TerminalInfoInteger(TERMINAL_CPU_CORES),
               TerminalInfoInteger(TERMINAL_MEMORY_PHYSICAL)
           );
}

//+------------------------------------------------------------------+
//| Remove 0 characters from the fixed size array.                   |
//+------------------------------------------------------------------+
template<typename T>
int ArrayRemoveGaps(T &arr[], int n) {
    int i, j, k;
    T c;
    k = 0;
    for (i = 0; i < n; i++) {
        if (arr[i] != 0) {
            k++;
            continue;
        }
        c = 0;
        for (j = i + 1; j < n; j++) {
            if (arr[j] != 0) {
                c = arr[j];
                arr[j] = 0;
                break;
            }
        }
        if (c == 0) break;
        arr[i] = c;
        k++;
    }
    if (k < n)
        arr[k] = 0;
    return k;
}

//+------------------------------------------------------------------+
//| Unescape Unicode characters from the string.                     |
//+------------------------------------------------------------------+
string UnicodeUnescape(string str) {
    ushort s[];
    ushort c1, c2, c, x;
    int n, i, j, k;
    n = StringLen(str);
    ArrayResize(s, n);
    i = 0;
    j = 0;
    while (i < n) {
        c1 = str[i];
        c2 = i + 1 < n ? str[i + 1] : 0;
        if (c1 == '\\' && (c2 == 'u' || c2 == 'U')) {
            if (i + 5 < n) {
                c = 0;
                for (k = i + 2; k < i + 6; k++) {
                    x = str[k];
                    if (x >= '0' && x <= '9') x = x - '0';
                    else if (x >= 'a' && x <= 'f') x = x - 'a' + 10;
                    else if (x >= 'A' && x <= 'F') x = x - 'A' + 10;
                    else break;
                    c = (c << 4) | (x & 0xF);
                }
                if (k == i + 6) {
                    if (c != 0) s[j++] = c;
                    i += 6;
                } else {
                    s[j++] = c1;
                    i++;
                }
            } else {
                s[j++] = c1;
                i++;
            }
        } else {
            s[j++] = c1;
            i++;
        }
    }
    return ShortArrayToString(s, 0, j);
}

//+------------------------------------------------------------------+
//| Overload                                                         |
//+------------------------------------------------------------------+
string UnicodeUnescape(ushort &arr[], int n = 0) {
    if (n == 0) n = ArraySize(arr);
    n = ArrayRemoveGaps(arr, n);
    return UnicodeUnescape(ShortArrayToString(arr, 0, n));
}

//+------------------------------------------------------------------+
//| Overload                                                         |
//+------------------------------------------------------------------+
string UnicodeUnescape(uchar &arr[], int n = 0) {
    if (n == 0) n = ArraySize(arr);
    n = ArrayRemoveGaps(arr, n);
    return UnicodeUnescape(CharArrayToString(arr, 0, n, CP_UTF8));
}

//+------------------------------------------------------------------+
//| Handle WinINet errors.                                           |
//+------------------------------------------------------------------+
int _wininetErr(string title = "", long session = 0, long connection = 0, long request = 0) {
    uint err = kernel32::GetLastError();
    if (WININET_KERNEL_ERRORS)
        PrintFormat("Error (%s, %s): #%d", "WinINet", title, err);
    if (request > 0) InternetCloseHandle(request);
    if (connection > 0) InternetCloseHandle(connection);
    if (session > 0) InternetCloseHandle(session);
    return -1;
}

//+------------------------------------------------------------------+
