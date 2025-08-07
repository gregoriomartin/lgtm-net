# lgtm-net
Install lgtm stack and a .net application to a Kubernetes cluster using lgtm helm chart.

## Logging App - Log Analysis Guide

### Overview

The Logging App is a .NET application that generates structured logs for testing and demonstration purposes. It produces various types of logs including informational, warning, error, debug, performance, security, business, and system logs.

### Log Generation

The application generates logs every 5 seconds through the `LogGeneratorService`, rotating through 8 different log types:

- **Info Logs** (Type 0): User operations and successful transactions
- **Warning Logs** (Type 1): Resource usage alerts and performance warnings
- **Error Logs** (Type 2): API failures, timeouts, validation errors, and authorization issues
- **Debug Logs** (Type 3): Cache operations, SQL queries, HTTP requests, and configuration loading
- **Performance Logs** (Type 4): Service performance metrics with CPU and memory usage
- **Security Logs** (Type 5): Authentication events, login attempts, and access control
- **Business Logs** (Type 6): Orders, payments, inventory changes, and search activities
- **System Logs** (Type 7): Health checks, scheduled jobs, resource monitoring, and configuration changes

### Log Formats

#### Console Logs
Logs are displayed in the console with this format:
```
[HH:mm:ss LVL] Message<s:SourceContext>{Properties}{NewLine}{Exception}
```

#### JSON File Logs
Structured JSON logs are written to `app/logs/logging-app-{date}.json` using Compact JSON format.

### Log Fields and Enrichment

Each log entry includes these enriched fields:

- **MachineName**: Container hostname
- **EnvironmentUserName**: Application user context
- **EnvironmentName**: Environment (Development/Production)
- **ProcessName**: Process name (dotnet)
- **Application**: "LoggingApp"
- **Environment**: Application environment
- **RequestId**: HTTP request correlation ID
- **ConnectionId**: HTTP connection identifier
- **ExceptionDetail**: Detailed exception information when errors occur

### Reading and Analyzing Logs

#### 1. Console Output
Monitor real-time logs using kubectl:
```powershell
kubectl logs -f deployment/logging-app
```

#### 2. File-based Logs
Access JSON logs from the container:
```powershell
$date = Get-Date -Format "yyyyMMdd"
kubectl exec -it deployment/logging-app -- cat /app/logs/logging-app-$date.json
```

#### 3. Log Patterns to Look For

##### Performance Issues
- Look for logs with `Duration > 1000ms` in Performance logs
- Warning messages about high memory usage (>80%)
- Slow database queries (>2000ms)

##### Security Events
- Failed login attempts with IP addresses
- Permission denied messages
- Authentication successful/failed patterns

##### Business Metrics
- Order creation and processing
- Payment success/failure rates
- Inventory changes and search patterns

##### System Health
- Service health check failures
- Resource threshold violations
- Configuration reload events

#### 4. Common Log Queries

##### Filter by Log Level
```powershell
# Errors only
kubectl logs deployment/logging-app | Select-String "\[.*ERR\]"

# Warnings and above
kubectl logs deployment/logging-app | Select-String -Pattern "\[(.*ERR|.*WRN)\]"
```

##### Filter by Context
```powershell
# Security-related logs
kubectl logs deployment/logging-app | Select-String -Pattern "authentication|login|password|permission" -CaseSensitive:$false

# Performance logs
kubectl logs deployment/logging-app | Select-String -Pattern "performance|duration|memory|cpu" -CaseSensitive:$false

# Business events
kubectl logs deployment/logging-app | Select-String -Pattern "order|payment|inventory|search" -CaseSensitive:$false
```

### Integration with Observability Stack

The application integrates with:

- **OpenTelemetry**: Sends traces and metrics to OTEL collector
- **Serilog**: Structured logging with multiple sinks
- **Prometheus**: Metrics collection via /metrics endpoint
- **Grafana**: Log visualization and alerting (if configured)

### Health Monitoring

The application exposes health checks at `/api/health` which return:
- HTTP 200: Application is healthy
- HTTP 503: Application has issues

Monitor health using:
```powershell
kubectl get pods -l app=logging-app
Invoke-RestMethod -Uri "http://localhost:30080/api/health"
```

### Troubleshooting

#### Common Issues

1. **404 Health Check Errors**: Ensure probes point to `/api/health` not `/health`
2. **TaskCanceledException**: Normal during application shutdown
3. **Connection Refused**: Check if service is running and ports are correct
4. **Missing Logs**: Verify volume mounts for log persistence

#### Log Volume Management

Logs rotate daily automatically. For long-term storage:
- Configure persistent volumes for log retention
- Set up log forwarding to external systems
- Implement log cleanup policies
