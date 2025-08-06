using Serilog;
using Serilog.Events;
using System.Diagnostics;

namespace LoggingApp.Services;

public class LogGeneratorService : BackgroundService
{
    private readonly ILogger<LogGeneratorService> _logger;
    private readonly ActivitySource _activitySource;
    private readonly Random _random = new();
    private int _logCounter = 0;

    // Realistic data for log generation
    private readonly string[] _users = { "alice.smith", "bob.jones", "carol.brown", "david.wilson", "emma.davis" };
    private readonly string[] _operations = { "GetUser", "CreateOrder", "UpdateProfile", "DeleteItem", "SearchProducts", "ProcessPayment", "SendEmail", "UploadFile" };
    private readonly string[] _services = { "UserService", "OrderService", "PaymentService", "NotificationService", "FileService", "SearchService" };
    private readonly string[] _databases = { "UserDB", "OrderDB", "ProductDB", "LoggingDB", "CacheDB" };
    private readonly string[] _apiEndpoints = { "/api/users", "/api/orders", "/api/products", "/api/payments", "/api/notifications" };

    public LogGeneratorService(ILogger<LogGeneratorService> logger, ActivitySource activitySource)
    {
        _logger = logger;
        _activitySource = activitySource;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("ContinuousLogService started - generating logs every 5 seconds");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                GenerateContinuousLogs();
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in ContinuousLogService");
                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            }
        }
    }

    private void GenerateContinuousLogs()
    {
        using var activity = _activitySource.StartActivity("GenerateContinuousLogs");
        _logCounter++;
        
        activity?.SetTag("log.counter", _logCounter);
        
        // Generate different types of logs in rotation
        var logType = _logCounter % 8;
        var logTypeName = logType switch
        {
            0 => "Info",
            1 => "Warning", 
            2 => "Error",
            3 => "Debug",
            4 => "Performance",
            5 => "Security",
            6 => "Business",
            7 => "System",
            _ => "Unknown"
        };
        
        activity?.SetTag("log.type", logTypeName);
        
        switch (logType)
        {
            case 0:
                GenerateInfoLog();
                break;
            case 1:
                GenerateWarningLog();
                break;
            case 2:
                GenerateErrorLog();
                break;
            case 3:
                GenerateDebugLog();
                break;
            case 4:
                GeneratePerformanceLog();
                break;
            case 5:
                GenerateSecurityLog();
                break;
            case 6:
                GenerateBusinessLog();
                break;
            case 7:
                GenerateSystemLog();
                break;
        }
    }

    private void GenerateInfoLog()
    {
        var user = _users[_random.Next(_users.Length)];
        var operation = _operations[_random.Next(_operations.Length)];
        var service = _services[_random.Next(_services.Length)];
        var requestId = Guid.NewGuid().ToString("N")[..8];
        var duration = _random.Next(50, 500);

        _logger.LogInformation("User {User} performed {Operation} via {Service} - RequestId: {RequestId} Duration: {Duration}ms Status: Success", 
            user, operation, service, requestId, duration);
    }

    private void GenerateWarningLog()
    {
        var warningScenarios = new[]
        {
            () => _logger.LogWarning("High memory usage detected: {MemoryUsage}% - Threshold: 80%", _random.Next(80, 95)),
            () => _logger.LogWarning("Slow database query detected: {Database} took {Duration}ms - Query: {Query}", 
                _databases[_random.Next(_databases.Length)], _random.Next(2000, 5000), "SELECT * FROM large_table"),
            () => _logger.LogWarning("API rate limit approaching: {Endpoint} has {RequestCount} requests in last minute", 
                _apiEndpoints[_random.Next(_apiEndpoints.Length)], _random.Next(800, 950)),
            () => _logger.LogWarning("Disk space running low: {DiskUsage}% used on volume {Volume}", 
                _random.Next(85, 95), "/data"),
            () => _logger.LogWarning("Connection pool exhaustion: {ActiveConnections}/{MaxConnections} connections active", 
                _random.Next(18, 20), 20)
        };

        var scenario = warningScenarios[_random.Next(warningScenarios.Length)];
        scenario();
    }

    private void GenerateErrorLog()
    {
        var errorScenarios = new[]
        {
            () => {
                var ex = new HttpRequestException($"HTTP 503 Service Unavailable");
                _logger.LogError(ex, "External API call failed: {Endpoint} - Retry attempt {AttemptNumber}", 
                    _apiEndpoints[_random.Next(_apiEndpoints.Length)], _random.Next(1, 4));
            },
            () => {
                var ex = new TimeoutException("Operation timed out");
                _logger.LogError(ex, "Database operation timeout: {Database} - Operation: {Operation} Duration: {Duration}ms", 
                    _databases[_random.Next(_databases.Length)], _operations[_random.Next(_operations.Length)], _random.Next(5000, 10000));
            },
            () => {
                var ex = new InvalidOperationException("Validation failed");
                _logger.LogError(ex, "Input validation error for user {User} - Field: {Field} Value: {Value}", 
                    _users[_random.Next(_users.Length)], "email", "invalid-email-format");
            },
            () => {
                var ex = new UnauthorizedAccessException("Access denied");
                _logger.LogError(ex, "Unauthorized access attempt: User {User} tried to access {Resource}", 
                    _users[_random.Next(_users.Length)], "/admin/users");
            }
        };

        var scenario = errorScenarios[_random.Next(errorScenarios.Length)];
        scenario();
    }

    private void GenerateDebugLog()
    {
        var debugScenarios = new[]
        {
            () => _logger.LogDebug("Cache hit for key: {CacheKey} - TTL: {TTL}s", 
                $"user_{_random.Next(1000, 9999)}", _random.Next(300, 3600)),
            () => _logger.LogDebug("SQL query executed: {Query} - Parameters: {Parameters} Rows: {RowCount}", 
                "SELECT * FROM users WHERE active = @active", new { active = true }, _random.Next(1, 100)),
            () => _logger.LogDebug("HTTP request received: {Method} {Path} - UserAgent: {UserAgent}", 
                "GET", _apiEndpoints[_random.Next(_apiEndpoints.Length)], "Mozilla/5.0 (compatible; ApiClient/1.0)"),
            () => _logger.LogDebug("Configuration loaded: {ConfigSection} - Values: {ConfigCount} items", 
                "DatabaseSettings", _random.Next(5, 15))
        };

        var scenario = debugScenarios[_random.Next(debugScenarios.Length)];
        scenario();
    }

    private void GeneratePerformanceLog()
    {
        var operation = _operations[_random.Next(_operations.Length)];
        var service = _services[_random.Next(_services.Length)];
        var duration = _random.Next(10, 3000);
        var memoryUsage = _random.Next(50, 200);
        var cpuUsage = _random.Next(10, 80);

        var level = duration switch
        {
            > 2000 => LogLevel.Warning,
            > 1000 => LogLevel.Information,
            _ => LogLevel.Debug
        };
        
        _logger.Log(level, "Performance metrics: {Service}.{Operation} - Duration: {Duration}ms CPU: {CpuUsage}% Memory: {MemoryUsage}MB", 
            service, operation, duration, cpuUsage, memoryUsage);
    }

    private void GenerateSecurityLog()
    {
        var securityEvents = new[]
        {
            () => {
                var user = _users[_random.Next(_users.Length)];
                var ip = $"192.168.{_random.Next(1, 255)}.{_random.Next(1, 255)}";
                _logger.LogInformation("Authentication successful: User {User} from IP {IpAddress} - Method: JWT", user, ip);
            },
            () => {
                var ip = $"10.0.{_random.Next(1, 255)}.{_random.Next(1, 255)}";
                _logger.LogWarning("Failed login attempt: IP {IpAddress} - Attempt: {AttemptNumber}/5 - Reason: Invalid credentials", 
                    ip, _random.Next(1, 6));
            },
            () => {
                var user = _users[_random.Next(_users.Length)];
                _logger.LogInformation("Password changed: User {User} - Method: Self-service - Previous login: {LastLogin}", 
                    user, DateTime.UtcNow.AddDays(-_random.Next(1, 30)));
            },
            () => {
                var user = _users[_random.Next(_users.Length)];
                var resource = _apiEndpoints[_random.Next(_apiEndpoints.Length)];
                _logger.LogWarning("Permission denied: User {User} attempted to access {Resource} - Role: User Required: Admin", 
                    user, resource);
            },
            () => {
                var sessionId = Guid.NewGuid().ToString("N")[..16];
                _logger.LogInformation("Session created: SessionId {SessionId} - User {User} - Expires: {ExpiresAt}", 
                    sessionId, _users[_random.Next(_users.Length)], DateTime.UtcNow.AddHours(8));
            }
        };

        var scenario = securityEvents[_random.Next(securityEvents.Length)];
        scenario();
    }

    private void GenerateBusinessLog()
    {
        var businessEvents = new[]
        {
            () => {
                var orderId = $"ORD-{_random.Next(100000, 999999)}";
                var amount = _random.Next(1000, 50000) / 100.0;
                var user = _users[_random.Next(_users.Length)];
                _logger.LogInformation("Order created: OrderId {OrderId} by {User} - Amount: ${Amount:F2} Items: {ItemCount}", 
                    orderId, user, amount, _random.Next(1, 5));
            },
            () => {
                var paymentId = $"PAY-{_random.Next(100000, 999999)}";
                var amount = _random.Next(500, 20000) / 100.0;
                var method = new[] { "CreditCard", "PayPal", "BankTransfer", "ApplePay" }[_random.Next(4)];
                var success = _random.Next(1, 100) > 3; // 97% success rate
                
                if (success)
                {
                    _logger.LogInformation("Payment processed: PaymentId {PaymentId} - Amount: ${Amount:F2} Method: {PaymentMethod} Status: Success", 
                        paymentId, amount, method);
                }
                else
                {
                    _logger.LogError("Payment failed: PaymentId {PaymentId} - Amount: ${Amount:F2} Method: {PaymentMethod} Reason: Declined", 
                        paymentId, amount, method);
                }
            },
            () => {
                var productId = $"PROD-{_random.Next(1000, 9999)}";
                var quantity = _random.Next(1, 100);
                _logger.LogInformation("Inventory updated: ProductId {ProductId} - Quantity changed by {QuantityChange} New stock: {NewStock}", 
                    productId, quantity > 50 ? $"+{quantity}" : $"-{quantity}", _random.Next(0, 500));
            },
            () => {
                var user = _users[_random.Next(_users.Length)];
                var searchTerm = new[] { "laptop", "smartphone", "headphones", "keyboard", "monitor" }[_random.Next(5)];
                var resultCount = _random.Next(0, 150);
                _logger.LogInformation("Search performed: User {User} searched for '{SearchTerm}' - Results: {ResultCount} Duration: {Duration}ms", 
                    user, searchTerm, resultCount, _random.Next(50, 300));
            }
        };

        var scenario = businessEvents[_random.Next(businessEvents.Length)];
        scenario();
    }

    private void GenerateSystemLog()
    {
        var systemEvents = new[]
        {
            () => {
                var serviceName = _services[_random.Next(_services.Length)];
                _logger.LogInformation("Service health check: {ServiceName} - Status: Healthy Response time: {ResponseTime}ms", 
                    serviceName, _random.Next(10, 100));
            },
            () => {
                var jobName = new[] { "DataBackup", "LogCleanup", "IndexRebuild", "ReportGeneration" }[_random.Next(4)];
                var duration = _random.Next(30, 300);
                _logger.LogInformation("Scheduled job completed: {JobName} - Duration: {Duration}s Items processed: {ItemCount}", 
                    jobName, duration, _random.Next(100, 5000));
            },
            () => {
                var threshold = _random.Next(70, 90);
                var current = _random.Next(threshold, 100);
                _logger.LogWarning("Resource threshold exceeded: CPU usage {CpuUsage}% > {Threshold}% - Node: worker-{NodeId}", 
                    current, threshold, _random.Next(1, 5));
            },
            () => {
                var version = $"v{_random.Next(1, 3)}.{_random.Next(0, 10)}.{_random.Next(0, 20)}";
                _logger.LogInformation("Configuration reloaded: Version {ConfigVersion} - Changes detected in {ConfigFile}", 
                    version, "appsettings.Production.json");
            },
            () => {
                var database = _databases[_random.Next(_databases.Length)];
                var connectionCount = _random.Next(5, 25);
                _logger.LogDebug("Database connection pool status: {Database} - Active: {ActiveConnections} Available: {AvailableConnections}", 
                    database, connectionCount, 30 - connectionCount);
            }
        };

        var scenario = systemEvents[_random.Next(systemEvents.Length)];
        scenario();
    }
}