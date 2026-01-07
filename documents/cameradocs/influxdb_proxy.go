// pkg/api/influxdb_proxy.go
package api

import (
    "bytes"
    "encoding/csv"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "net/url"
    "os"
    "strings"
    "time"

    contextmodel "github.com/grafana/grafana/pkg/services/contexthandler/model"
    "github.com/grafana/grafana/pkg/api/response"
    "github.com/grafana/grafana/pkg/web"
)

var (
    influxURL        = getenv("INFLUXDB_URL", "https://influx.lanhc.com")
    influxToken      = getenv("INFLUXDB_TOKEN", "kcF_lnBLOpnArrmmHytfGCeo5bGh5LQJb_d6wxyBZntWUbz-KyUv8UH_3huFP5Ac3SjOwX5KniuEmgpV_WUwYQ==")
    influxOrg        = getenv("INFLUXDB_ORG", "ld6002h")
    defaultBucket    = getenv("INFLUXDB_BUCKET", "vitals_data")
    defaultDeviceID  = getenv("DEVICE_ID", "84F7035346E0")
)

func getenv(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}

type InfluxDBQueryRequest struct {
    Query    string `json:"query,omitempty"`
    Field    string `json:"field,omitempty"`
    Mode     string `json:"mode,omitempty"` // tma2m / mean5m
    Bucket   string `json:"bucket,omitempty"`
    DeviceID string `json:"deviceId,omitempty"`
}

type InfluxDBQueryResponse struct {
    Results []interface{} `json:"results,omitempty"`
    Error   string        `json:"error,omitempty"`
}

// InfluxDBQuery 处理 InfluxDB Flux 查询请求
func (hs *HTTPServer) InfluxDBQuery(c *contextmodel.ReqContext) response.Response {
    var req InfluxDBQueryRequest
    
    if err := web.Bind(c.Req, &req); err != nil {
        hs.log.Error("Failed to parse request", "error", err)
        return response.Error(http.StatusBadRequest, "Invalid request body", err)
    }

    bucket := firstNonEmpty(req.Bucket, defaultBucket)
    deviceID := firstNonEmpty(req.DeviceID, defaultDeviceID)

    if req.Query == "" {
        if req.Field == "" {
            hs.log.Warn("field missing for auto query")
            return response.Error(http.StatusBadRequest, "field is required when query is empty", nil)
        }
        switch req.Mode {
        case "tma2m":
            req.Query = fluxSampleTMA2M(bucket, deviceID, req.Field)
        case "mean5m":
            req.Query = fluxMean5m(bucket, deviceID, req.Field)
        default:
            hs.log.Warn("unsupported mode", "mode", req.Mode)
            return response.Error(http.StatusBadRequest, "unsupported mode, use tma2m or mean5m", nil)
        }
    }

    hs.log.Info("Received InfluxDB query request", "query", req.Query)

    // 构建 InfluxDB 查询 URL - 修改为 POST 端点
    queryURL, err := url.Parse(fmt.Sprintf("%s/api/v2/query", influxURL))
    if err != nil {
        hs.log.Error("Failed to parse InfluxDB URL", "error", err)
        return response.Error(http.StatusInternalServerError, "Failed to parse InfluxDB URL", err)
    }

    q := queryURL.Query()
    q.Set("org", influxOrg)
    queryURL.RawQuery = q.Encode()

    bodyBytes, err := json.Marshal(map[string]string{
        "query": req.Query,
    })
    if err != nil {
        hs.log.Error("Failed to marshal query body", "error", err)
        return response.Error(http.StatusInternalServerError, "Failed to marshal request", err)
    }

    // 创建 POST 请求
    httpReq, err := http.NewRequest("POST", queryURL.String(), bytes.NewReader(bodyBytes))
    if err != nil {
        hs.log.Error("Failed to create HTTP request", "error", err)
        return response.Error(http.StatusInternalServerError, "Failed to create request", err)
    }

    // 设置请求头
    httpReq.Header.Set("Authorization", fmt.Sprintf("Token %s", influxToken))
    httpReq.Header.Set("Accept", "text/csv")
    httpReq.Header.Set("Content-Type", "application/json")
    httpReq.Header.Set("User-Agent", "Grafana/12.3.0")

    hs.log.Debug("Querying InfluxDB", "url", queryURL.String(), "query", req.Query)

    // 发送请求
    client := &http.Client{
        Timeout: 30 * time.Second,
    }
    resp, err := client.Do(httpReq)
    if err != nil {
        hs.log.Error("Failed to query InfluxDB", "error", err, "url", queryURL.String())
        return response.Error(http.StatusInternalServerError, "Failed to query InfluxDB", err)
    }
    defer resp.Body.Close()

    // 读取响应体
    body, err := io.ReadAll(resp.Body)
    if err != nil {
        hs.log.Error("Failed to read response body", "error", err)
        return response.Error(http.StatusInternalServerError, "Failed to read response body", err)
    }

    hs.log.Info("InfluxDB response received",
        "status", resp.StatusCode,
        "contentType", resp.Header.Get("Content-Type"),
        "bodyLength", len(body))

    // 如果 InfluxDB 返回错误，转发错误响应
    if resp.StatusCode != http.StatusOK {
        hs.log.Error("InfluxDB returned error", "status", resp.StatusCode, "body", string(body))
        return response.Error(resp.StatusCode, fmt.Sprintf("InfluxDB query failed: %s", string(body)), nil)
    }

    contentType := resp.Header.Get("Content-Type")
    if strings.Contains(strings.ToLower(contentType), "text/csv") {
        parsed, err := parseFluxCSV(body)
        if err != nil {
            hs.log.Error("Failed to parse CSV response", "error", err)
            return response.Error(http.StatusInternalServerError, "Failed to parse CSV response", err)
        }
        hs.log.Info("InfluxDB query succeeded", "recordCount", len(parsed))
        return response.JSON(http.StatusOK, map[string]any{"results": parsed})
    }

    // 检查 Content-Type
    if !strings.Contains(contentType, "application/json") {
        hs.log.Error("Unexpected content type from InfluxDB",
            "contentType", contentType,
            "bodyPreview", string(body[:min(len(body), 200)]))
        return response.Error(http.StatusInternalServerError,
            fmt.Sprintf("InfluxDB returned unexpected content type: %s", contentType), nil)
    }

    // 解析 JSON 响应
    var queryResp InfluxDBQueryResponse
    if err := json.Unmarshal(body, &queryResp); err != nil {
        hs.log.Error("Failed to parse JSON response", "error", err, "body", string(body))
        return response.Error(http.StatusInternalServerError, "Failed to parse response", err)
    }

    hs.log.Info("InfluxDB query succeeded", "resultCount", len(queryResp.Results))
    return response.JSON(http.StatusOK, queryResp)
}

// 辅助函数
func min(a, b int) int {
    if a < b {
        return a
    }
    return b
}

func firstNonEmpty(values ...string) string {
    for _, v := range values {
        if strings.TrimSpace(v) != "" {
            return v
        }
    }
    return ""
}

func fluxSampleTMA2M(bucket, deviceID, field string) string {
    return fmt.Sprintf(`from(bucket: "%s")
  |> range(start: -12h)
  |> filter(fn: (r) => r["device_id"] == "%s")
  |> filter(fn: (r) => r["_field"] == "%s")
  |> filter(fn: (r) => r._value != 0)
  |> timedMovingAverage(every: 5m, period: 10m)
  |> filter(fn: (r) => r._value != 0)`, bucket, deviceID, field)
}

func fluxMean5m(bucket, deviceID, field string) string {
    return fmt.Sprintf(`from(bucket: "%s")
  |> range(start: -2m)
  |> filter(fn: (r) => r["device_id"] == "%s")
  |> filter(fn: (r) => r["_field"] == "%s")
  |> filter(fn: (r) => r._value != 0)
  |> mean()`, bucket, deviceID, field)
}

func parseFluxCSV(body []byte) ([]map[string]string, error) {
    reader := csv.NewReader(bytes.NewReader(body))
    reader.FieldsPerRecord = -1

    var (
        headers []string
        rows    []map[string]string
    )

    for {
        record, err := reader.Read()
        if err == io.EOF {
            break
        }
        if err != nil {
            return nil, err
        }
        if len(record) == 0 {
            continue
        }
        if strings.HasPrefix(record[0], "#") {
            headers = nil
            continue
        }
        if headers == nil {
            headers = record
            continue
        }
        row := make(map[string]string, len(headers))
        for i, h := range headers {
            if i < len(record) {
                row[h] = record[i]
            }
        }
        rows = append(rows, row)
    }
    return rows, nil
}