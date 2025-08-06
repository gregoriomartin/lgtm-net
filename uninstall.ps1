<#
.SYNOPSIS
    Uninstalls the LGTM Stack from Kubernetes
.PARAMETER Namespace
    The Kubernetes namespace where the stack is installed (default: monitoring)
#>

param(
    [string]$Namespace = "monitoring"
)

Write-Host "Uninstalling LGTM Stack..." -ForegroundColor Yellow

# Uninstall .NET API app
kubectl delete -f ../manifests/app -n $Namespace 2>$null

# Uninstall OpenTelemetry Collector
kubectl delete -f ../manifests/otel-collector.yaml -n $Namespace 2>$null

# Uninstall Promtail
kubectl delete -f ../manifests/promtail.docker.yaml 2>$null

# Uninstall LGTM Stack
helm uninstall lgtm -n $Namespace 2>$null

# Uninstall Prometheus Operator
helm uninstall prometheus-operator -n $Namespace 2>$null

# Delete namespace (optional - commented out by default)
# kubectl delete namespace $Namespace

Write-Host "LGTM Stack uninstalled successfully!" -ForegroundColor Green