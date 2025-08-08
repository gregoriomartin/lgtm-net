<#
.SYNOPSIS
    Uninstalls the LGTM Stack from Kubernetes
.PARAMETER Namespace
    The Kubernetes namespace where the stack is installed (default: monitoring)
#>

param(
    [string]$Namespace = "monitoring"
)

# ========================================
# LGTM Stack Uninstallation Script
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "LGTM Stack Uninstallation Script" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Uninstalling from namespace: $Namespace" -ForegroundColor Yellow

# ========================================
# STEP 1: Uninstall .NET API Application
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Uninstalling .NET API Application" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$appPath = Join-Path $PSScriptRoot ".." "manifests" "src"
if (Test-Path $appPath) {
    Write-Host "Removing .NET API application..." -ForegroundColor Cyan
    kubectl delete -f $appPath -n $Namespace 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ .NET API application removed" -ForegroundColor Green
    } else {
        Write-Host "  ✓ .NET API application not found or already removed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✓ .NET API application manifests not found" -ForegroundColor Yellow
}

# ========================================
# STEP 2: Uninstall OpenTelemetry Collector
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Uninstalling OpenTelemetry Collector" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$otelFile = Join-Path $PSScriptRoot ".." "manifests" "otel-collector.yaml"
if (Test-Path $otelFile) {
    Write-Host "Removing OpenTelemetry Collector..." -ForegroundColor Cyan
    kubectl delete -f $otelFile -n $Namespace 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ OpenTelemetry Collector removed" -ForegroundColor Green
    } else {
        Write-Host "  ✓ OpenTelemetry Collector not found or already removed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✓ OpenTelemetry Collector manifest not found" -ForegroundColor Yellow
}

# ========================================
# STEP 3: Uninstall Alloy
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Uninstalling Alloy" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$alloyFile = Join-Path $PSScriptRoot ".." "manifests" "alloy.yaml"
if (Test-Path $alloyFile) {
    Write-Host "Removing Alloy..." -ForegroundColor Cyan
    kubectl delete -f $alloyFile 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Alloy removed" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Alloy not found or already removed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✓ Alloy manifest not found" -ForegroundColor Yellow
}

# ========================================
# STEP 4: Uninstall LGTM Stack
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Uninstalling LGTM Stack" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "Removing LGTM Stack Helm release..." -ForegroundColor Cyan
helm uninstall lgtm -n $Namespace 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ LGTM Stack removed" -ForegroundColor Green
} else {
    Write-Host "  ✓ LGTM Stack not found or already removed" -ForegroundColor Yellow
}

# ========================================
# STEP 5: Uninstall Prometheus Operator
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Uninstalling Prometheus Operator" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "Removing Prometheus Operator Helm release..." -ForegroundColor Cyan
helm uninstall prometheus-operator -n $Namespace 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Prometheus Operator removed" -ForegroundColor Green
} else {
    Write-Host "  ✓ Prometheus Operator not found or already removed" -ForegroundColor Yellow
}

# ========================================
# STEP 6: Clean up remaining resources
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Cleaning up remaining resources" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "Checking for remaining resources in namespace '$Namespace'..." -ForegroundColor Cyan
$remainingResources = kubectl get all -n $Namespace --ignore-not-found 2>$null
if ($remainingResources) {
    Write-Host "  ⚠ Some resources may still exist in the namespace" -ForegroundColor Yellow
    Write-Host "  Run 'kubectl get all -n $Namespace' to check remaining resources" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ No resources remaining in namespace" -ForegroundColor Green
}

# Note about namespace deletion (optional)
Write-Host ""
Write-Host "Note: The namespace '$Namespace' has not been deleted." -ForegroundColor Yellow
Write-Host "To delete the namespace completely, run:" -ForegroundColor Yellow
Write-Host "  kubectl delete namespace $Namespace" -ForegroundColor Yellow

# ========================================
# Uninstallation Complete!
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Uninstallation Complete!" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "LGTM Stack uninstalled successfully!" -ForegroundColor Green