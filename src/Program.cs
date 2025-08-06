using System.Diagnostics;
using System.Diagnostics.Metrics;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Serilog;
using Serilog.Events;
using Serilog.Formatting.Compact;
using DotNetApi.Services;

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithEnvironmentName()
    .Enrich.WithMachineName()
    .Enrich.WithThreadId()
    .Enrich.WithProcessId()
    .Enrich.WithProcessName()
    .Enrich.WithProperty("ApplicationName", "logging-app")
    .Enrich.WithProperty("Environment", Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production")
    .WriteTo.Console(new CompactJsonFormatter())
    .CreateLogger();

try
{
    Log.Information("Starting DotNetApi application");
    
    var builder = WebApplication.CreateBuilder(args);

    // Add Serilog
    builder.Host.UseSerilog((context, services, configuration) => configuration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .Enrich.WithProperty("ApplicationName", "logging-app")
        .WriteTo.Console(new CompactJsonFormatter()));

    // Configure OpenTelemetry
    var otelEndpoint = builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "http://otel-collector:4318";
    var serviceName = "logging-app";
    var serviceVersion = "1.0.0";

    // Configure OpenTelemetry Resource
    var resourceBuilder = ResourceBuilder.CreateDefault()
        .AddService(serviceName: serviceName, serviceVersion: serviceVersion)
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = builder.Environment.EnvironmentName,
            ["host.name"] = Environment.MachineName
        });

    // Add OpenTelemetry
    builder.Services.AddOpenTelemetry()
        .ConfigureResource(resource => resource.AddService(serviceName, serviceVersion))
        .WithTracing(tracing =>
        {
            tracing
                .AddAspNetCoreInstrumentation(options =>
                {
                    options.RecordException = true;
                })
                .AddHttpClientInstrumentation()
                .AddSource(serviceName)
                .AddOtlpExporter(options =>
                {
                    options.Endpoint = new Uri($"{otelEndpoint}/v1/traces");
                });
        })
        .WithMetrics(metrics =>
        {
            metrics
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation()
                .AddProcessInstrumentation()
                .AddMeter(serviceName)
                .AddOtlpExporter(options =>
                {
                    options.Endpoint = new Uri($"{otelEndpoint}/v1/metrics");
                });
        });

    // Add services
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
    builder.Services.AddHealthChecks();
    builder.Services.AddSingleton<DataService>();
    builder.Services.AddSingleton<ActivitySource>(new ActivitySource(serviceName, serviceVersion));
    builder.Services.AddSingleton<Meter>(new Meter(serviceName, serviceVersion));
    builder.Services.AddHttpClient();

    var app = builder.Build();

    // Configure the HTTP request pipeline
    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    // Add Serilog request logging
    app.UseSerilogRequestLogging(options =>
    {
        options.MessageTemplate = "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000} ms";
        options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
        {
            diagnosticContext.Set("RequestHost", httpContext.Request.Host.Value);
            diagnosticContext.Set("RequestScheme", httpContext.Request.Scheme);
            diagnosticContext.Set("UserAgent", httpContext.Request.Headers["User-Agent"].ToString());
            diagnosticContext.Set("RemoteIpAddress", httpContext.Connection.RemoteIpAddress);
            diagnosticContext.Set("RequestId", Activity.Current?.Id ?? httpContext.TraceIdentifier);
        };
    });

    app.UseHttpsRedirection();
    app.UseAuthorization();
    app.MapControllers();
    app.MapHealthChecks("/api/health");

    // Log application startup details
    Log.Information("Application started successfully");
    Log.Information("Environment: {Environment}", app.Environment.EnvironmentName);
    Log.Information("OTEL Endpoint: {OtelEndpoint}", otelEndpoint);
    Log.Information("Service Name: {ServiceName}", serviceName);
    Log.Information("Service Version: {ServiceVersion}", serviceVersion);

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}