//+------------------------------------------------------------------+
//|                                                      Storage.mqh |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Geraked"
#property link      "https://github.com/geraked"
#property version   "1.0"

#include <SysTime.mqh>

#define STORAGE_DB_PATH "Geraked\\storage.db"

enum ENUM_STORAGE_TIME {
    STORAGE_TIME_SYSTEM, // TimeSystem
    STORAGE_TIME_TRADESERVER // TimeTradeServer
};

//+------------------------------------------------------------------+
//| Returns the value of a global variable.                          |
//+------------------------------------------------------------------+
template<typename T>
T StorageGet(string key, T default_value) {
    int db = _storageInitDb(DATABASE_OPEN_READONLY | DATABASE_OPEN_COMMON);
    if (db == INVALID_HANDLE) return default_value;

    string val;
    string sql = StringFormat("SELECT value FROM T WHERE key='%s' LIMIT 1", key);
    int dp = DatabasePrepare(db, sql);
    while (DatabaseRead(dp) && !IsStopped()) {
        DatabaseColumnText(dp, 0, val);
    }
    DatabaseFinalize(dp);
    DatabaseClose(db);

    if (val == NULL)
        return default_value;
    if (typename(T) == "datetime" || typename(T) == "color")
        return (T)((long) val);

    return (T) val;
}

//+------------------------------------------------------------------+
//| Sets the new value to a global variable.                         |
//+------------------------------------------------------------------+
template<typename T>
bool StorageSet(string key, T value) {
    int db = _storageInitDb();
    if (db == INVALID_HANDLE) return false;

    string sql = "INSERT OR REPLACE INTO T (key, value, time_system, time_server) VALUES (";
    sql += StringFormat("'%s', ", key);

    if (typename(T) == "datetime" || typename(T) == "color")
        sql += StringFormat("'%d', ", value);
    else
        sql += StringFormat("'%s', ", (string) value);

    sql += StringFormat("%d, ", TimeSystem());
    sql += StringFormat("%d);", TimeTradeServer());

    if (!DatabaseExecute(db, sql)) {
        PrintFormat("Error (%s, Upsert): #%d", __FUNCTION__, GetLastError());
        DatabaseClose(db);
        return false;
    }
    DatabaseClose(db);

    return true;
}

//+------------------------------------------------------------------+
//| Deletes a global variable.                                       |
//+------------------------------------------------------------------+
bool StorageDel(string key) {
    int db = _storageInitDb();
    if (db == INVALID_HANDLE) return false;

    string sql = StringFormat("DELETE FROM T WHERE key='%s'", key);
    if (!DatabaseExecute(db, sql)) {
        PrintFormat("Error (%s, Delete): #%d", __FUNCTION__, GetLastError());
        DatabaseClose(db);
        return false;
    }
    DatabaseClose(db);

    return true;
}

//+------------------------------------------------------------------+
//| Deletes global variables with specified prefix in their names.   |
//+------------------------------------------------------------------+
bool StorageDeleteAll(string prefix = NULL) {
    if (prefix == NULL || prefix == "") {
        if (FileIsExist(STORAGE_DB_PATH, FILE_COMMON) && !FileDelete(STORAGE_DB_PATH, FILE_COMMON)) {
            PrintFormat("Error (%s, FileDelete): #%d", __FUNCTION__, GetLastError());
            return false;
        }
        return true;
    }

    int db = _storageInitDb();
    if (db == INVALID_HANDLE) return false;

    string sql = StringFormat("DELETE FROM T WHERE key LIKE '%s%%'", prefix);
    if (!DatabaseExecute(db, sql)) {
        PrintFormat("Error (%s, Delete): #%d", __FUNCTION__, GetLastError());
        DatabaseClose(db);
        return false;
    }
    DatabaseClose(db);
    return true;
}

//+------------------------------------------------------------------+
//| Returns time of the last updating the global variable.           |
//+------------------------------------------------------------------+
datetime StorageLastUpdate(string key, ENUM_STORAGE_TIME time = STORAGE_TIME_SYSTEM) {
    int db = _storageInitDb(DATABASE_OPEN_READONLY | DATABASE_OPEN_COMMON);
    if (db == INVALID_HANDLE) return -1;

    string time_col = "time_system";
    if (time == STORAGE_TIME_TRADESERVER)
        time_col = "time_server";

    datetime val = 0;
    string sql = StringFormat("SELECT %s FROM T WHERE key='%s' LIMIT 1", time_col, key);
    int dp = DatabasePrepare(db, sql);
    while (DatabaseRead(dp) && !IsStopped()) {
        DatabaseColumnLong(dp, 0, val);
    }
    DatabaseFinalize(dp);
    DatabaseClose(db);

    return val;
}

//+------------------------------------------------------------------+
//| Initialize the storage DB and return the handle.                 |
//+------------------------------------------------------------------+
int _storageInitDb(uint flags = DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON) {
    int db;
    string sql;
    string db_path = STORAGE_DB_PATH;

    if (!FileIsExist(db_path, FILE_COMMON))
        flags = DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON;

    db = DatabaseOpen(db_path, flags);
    if (db == INVALID_HANDLE) {
        PrintFormat("Error (%s, DatabaseOpen): #%d", __FUNCTION__, GetLastError());
        return INVALID_HANDLE;
    }

    if (!DatabaseTableExists(db, "T")) {
        sql = "CREATE TABLE T ("
              "key TEXT,"
              "value TEXT,"
              "time_system INT,"
              "time_server INT,"
              "PRIMARY KEY(key)"
              ");";

        if (!DatabaseExecute(db, sql)) {
            PrintFormat("Error (%s, CreateTable, T): #%d", __FUNCTION__, GetLastError());
            DatabaseClose(db);
            return INVALID_HANDLE;
        }
    }

    return db;
}

//+------------------------------------------------------------------+
