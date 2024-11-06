//+------------------------------------------------------------------+
//|                                                          Knn.mqh |
//|                                          Copyright 2024, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.0"
#property description "K-Nearest Neighbors (K-NN) Classification Algorithm"

#include <Generic/HashMap.mqh>

enum ENUM_DISTANCE {
    DISTANCE_EUCLIDEAN, // Euclidean
    DISTANCE_MANHATTAN, // Manhattan
    DISTANCE_COSINE // Cosine
};

enum ENUM_SCALER {
    SCALER_NONE, // None
    SCALER_STD, // Standard
    SCALER_01, // Min-Max [0,1]
    SCALER_11 // Min-Max [-1,1]
};


class CScaler {
private:
    ENUM_SCALER m_type;
    ulong m_cnt;
    vector m_mean;
    vector m_ss;
    vector m_min;
    vector m_max;
public:
    CScaler(void);
    CScaler(ENUM_SCALER type);
    void Init(ulong cols = 0);
    void Fit(const matrix &X);
    matrix Transform(const matrix &X);
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CScaler::CScaler(void) {
    m_type = SCALER_STD;
    Init();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CScaler::CScaler(ENUM_SCALER type) {
    m_type = type;
    Init();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CScaler::Init(ulong cols = 0) {
    m_cnt = 0;
    if (cols == 0) return;
    m_mean = vector::Full(cols, 0);
    m_ss = vector::Full(cols, 0);
    m_min = vector::Full(cols, DBL_MAX);
    m_max = vector::Full(cols, -DBL_MAX);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CScaler::Fit(const matrix &X) {
    if (m_cnt == 0)
        Init(X.Cols());
    ulong i, j;
    double x, prev_mean;
    for (i = 0; i < X.Rows(); i++) {
        m_cnt++;
        for (j = 0; j < X.Cols(); j++) {
            x = X[i][j];
            prev_mean = m_mean[j];
            m_mean[j] += (x - m_mean[j]) / m_cnt;
            m_ss[j] += (x - prev_mean) * (x - m_mean[j]);
            if (x < m_min[j])
                m_min[j] = x;
            if (x > m_max[j])
                m_max[j] = x;
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
matrix CScaler::Transform(const matrix &X) {
    matrix XT = X;
    ulong i, j;
    double x, d, std;
    for (i = 0; i < X.Rows(); i++) {
        for (j = 0; j < X.Cols(); j++) {
            x = X[i][j];
            d = m_max[j] - m_min[j];
            std = MathSqrt(m_ss[j] / m_cnt);
            if (d == 0) d = DBL_EPSILON;
            if (std == 0) std = DBL_EPSILON;
            if (m_type == SCALER_01)
                XT[i][j] = (x - m_min[j]) / d;
            else if (m_type == SCALER_11)
                XT[i][j] = (x - m_min[j]) / d * 2 - 1;
            else if (m_type == SCALER_STD)
                XT[i][j] = (x - m_mean[j]) / std;
            else
                XT[i][j] = x;
        }
    }
    return XT;
}

class CKnn {
private:
    ENUM_DISTANCE m_distance;
    int m_k;
    int m_window_size;
    ulong m_cnt;
    vector weights;
    matrix X_window;
    vector y_window;
    CScaler scaler;
    double calcDistance(vector &u, vector &v);
    double getMode(vector &u);
    void sort(vector &u);
public:
    CKnn(void);
    CKnn(int k, int window_size = 1000, ENUM_DISTANCE distance_type = DISTANCE_EUCLIDEAN, ENUM_SCALER scaler_type = SCALER_STD);
    void Init(ulong cols = 0);
    void Fit(const matrix &X, const vector &y);
    vector Predict(const matrix &X, bool trace_print = false);
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CKnn::CKnn(void) {
    m_k = 5;
    m_window_size = 1000;
    m_distance = DISTANCE_EUCLIDEAN;
    Init();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CKnn::CKnn(int k, int window_size = 1000, ENUM_DISTANCE distance_type = DISTANCE_EUCLIDEAN, ENUM_SCALER scaler_type = SCALER_STD) {
    m_k = k;
    m_window_size = window_size;
    m_distance = distance_type;
    scaler = CScaler(scaler_type);
    Init();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CKnn::Init(ulong cols = 0) {
    m_cnt = 0;
    scaler.Init();
    if (cols == 0) return;
    weights = vector::Full(cols, 1.0);
    X_window = matrix::Full(m_window_size, cols, 0);
    y_window = vector::Full(m_window_size, 0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CKnn::Fit(const matrix &X, const vector &y) {
    if (m_cnt == 0)
        Init(X.Cols());
    scaler.Fit(X);
    ulong i, iw;
    for (i = 0; i < X.Rows(); i++) {
        iw = m_cnt % m_window_size;
        X_window.Row(X.Row(i), iw);
        y_window[iw] = y[i];
        m_cnt++;
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CKnn::calcDistance(vector &u, vector &v) {
    double dist = 0;
    if (m_distance == DISTANCE_EUCLIDEAN) {
        vector d = (u - v) * weights;
        dist = d.Norm(VECTOR_NORM_P, 2);
    } else if (m_distance == DISTANCE_MANHATTAN) {
        vector d = (u - v) * weights;
        dist = d.Norm(VECTOR_NORM_P, 1);
    } else if (m_distance == DISTANCE_COSINE) {
        double u_norm = (u * weights).Norm(VECTOR_NORM_P, 2);
        double v_norm = (v * weights).Norm(VECTOR_NORM_P, 2);
        double u_v = u_norm * v_norm;
        if (u_v == 0) u_v = DBL_EPSILON;
        double sim = (u * weights).Dot(v * weights) / u_v;
        dist = 1 - sim;
    }
    return dist;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CKnn::getMode(vector &u) {
    CHashMap<int, int> hm;
    double mode;
    int key;
    int val;
    for (ulong i = 0; i < u.Size(); i++) {
        key = (int) u[i];
        val = 0;
        if (!hm.ContainsKey(key)) {
            hm.Add(key, val);
        }
        hm.TryGetValue(key, val);
        hm.TrySetValue(key, val + 1);
    }
    int keys[], vals[];
    hm.CopyTo(keys, vals);
    mode = keys[ArrayMaximum(vals)];
    return mode;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CKnn::sort(vector &u) {
    double arr[];
    ulong n = ArrayResize(arr, (int) u.Size());
    for (ulong i = 0; i < n; i++)
        arr[i] = u[i];
    ArraySort(arr);
    for (ulong i = 0; i < n; i++)
        u[i] = arr[i];
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CKnn::Predict(const matrix &X, bool trace_print = false) {
    vector y_pred(X.Rows());
    matrix X_scal = scaler.Transform(X);
    matrix X_window_scal = scaler.Transform(X_window);
    ulong n = MathMin(m_window_size, m_cnt);
    vector d_window(n);
    vector labels(MathMin(m_k, n));
    vector u, v;
    ulong i, j, i_min;
    for (i = 0; i < X.Rows(); i++) {
        u = X_scal.Row(i);
        for (j = 0; j < n; j++) {
            v = X_window_scal.Row(j);
            d_window[j] = calcDistance(u, v);
        }
        if (trace_print) {
            Print("***** KNN Predict: ");
            Print("x = ", X.Row(i));
        }
        for (j = 0; j < labels.Size(); j++) {
            i_min = d_window.ArgMin();
            labels[j] = y_window[i_min];
            if (trace_print) PrintFormat("NN%2d: window_id = %5d  distance = %.8f  label = %.0f", j + 1, i_min, d_window[i_min], y_window[i_min]);
            d_window[i_min] = DBL_MAX;
        }
        sort(labels);
        y_pred[i] = getMode(labels);
        if (trace_print) PrintFormat("y = %.0f\n", y_pred[i]);
    }
    return y_pred;
}

//+------------------------------------------------------------------+
