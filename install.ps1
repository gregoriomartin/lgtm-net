<#
.SYNOPSIS
    Installs the LGTM Stack (Loki, Grafana, Tempo, Mimir) with Prometheus Operator on Kubernetes
.DESCRIPTION
    This script automates the installation of the complete LGTM observability stack
.PARAMETER Namespace
    The Kubernetes namespace to install the stack (default: monitoring)
.PARAMETER SkipPrerequisites
    Skip prerequisite checks
#>

param(
    [string]$Namespace = "monitoring",
    [switch]$SkipPrerequisites
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ========================================
# LGTM Stack Installation Script
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "LGTM Stack Installation Script" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Installing to namespace: $Namespace" -ForegroundColor Cyan

# ========================================
# STEP 1: Check Prerequisites
# ========================================

if (-not $SkipPrerequisites) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "Checking Prerequisites" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    $prerequisites = @{
        "kubectl" = "Kubernetes CLI tool for managing clusters"
        "helm" = "Kubernetes package manager"
    }
    
    $missingTools = @()
    
    foreach ($tool in $prerequisites.Keys) {
        Write-Host "Checking for $tool..." -ForegroundColor Cyan
        
        try {
            $version = & $tool version
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $tool is installed: $version" -ForegroundColor Green
            } else {
                throw
            }
        }
        catch {
            Write-Host "  ✗ $tool is not installed or not in PATH" -ForegroundColor Red
            Write-Host "    Description: $($prerequisites[$tool])" -ForegroundColor Yellow
            $missingTools += $tool
        }
    }
    
    # Check Kubernetes connectivity
    Write-Host "Checking Kubernetes cluster connectivity..." -ForegroundColor Cyan
    try {
        $clusterInfo = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Connected to Kubernetes cluster" -ForegroundColor Green
            kubectl version --short
        } else {
            throw
        }
    }
    catch {
        Write-Host "  ✗ Cannot connect to Kubernetes cluster" -ForegroundColor Red
        Write-Host "    Ensure you have a valid kubeconfig and cluster access" -ForegroundColor Yellow
        $missingTools += "kubernetes-connection"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Host ""
        Write-Host "Prerequisites check failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Installation instructions:" -ForegroundColor Yellow
        
        if ($missingTools -contains "kubectl") {
            Write-Host "  kubectl: https://kubernetes.io/docs/tasks/tools/"
        }
        if ($missingTools -contains "helm") {
            Write-Host "  helm: https://helm.sh/docs/intro/install/"
        }
        if ($missingTools -contains "kubernetes-connection") {
            Write-Host "  Configure kubectl: https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/"
        }
        
        exit 1
    }
    
    Write-Host "`n✓ All prerequisites met!" -ForegroundColor Green
}

# ========================================
# STEP 2: Add Helm Repositories
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Adding Helm Repositories" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$repositories = @{
    "prometheus-community" = "https://prometheus-community.github.io/helm-charts"
    "grafana" = "https://grafana.github.io/helm-charts"
}

foreach ($repo in $repositories.Keys) {
    Write-Host "Adding $repo repository..." -ForegroundColor Cyan
    helm repo add $repo $repositories[$repo] 2>&1 | Out-String | Write-Verbose
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Added $repo repository" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to add $repo repository" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Updating Helm repositories..." -ForegroundColor Cyan
helm repo update 2>&1 | Out-String | Write-Verbose
Write-Host "  ✓ Repositories updated" -ForegroundColor Green

# ========================================
# STEP 3: Create Namespace
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Creating Namespace" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "Checking if namespace '$Namespace' exists..." -ForegroundColor Cyan
$nsExists = kubectl get namespace $Namespace --ignore-not-found 2>&1

if ($nsExists) {
    Write-Host "  Namespace '$Namespace' already exists" -ForegroundColor Yellow
} else {
    Write-Host "Creating namespace '$Namespace'..." -ForegroundColor Cyan
    kubectl create namespace $Namespace
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Created namespace '$Namespace'" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to create namespace" -ForegroundColor Red
        exit 1
    }
}

# ========================================
# STEP 4: Install Prometheus Operator
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Installing Prometheus Operator" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$valuesFile = Join-Path $PSScriptRoot "helm-values" "prometheus.yaml"

if (-not (Test-Path $valuesFile)) {
    Write-Host "  prometheus.yaml not found, using default values" -ForegroundColor Yellow
    $valuesParam = ""
} else {
    $valuesParam = "-f `"$valuesFile`""
}

Write-Host "Installing Prometheus Operator..." -ForegroundColor Cyan
$installCmd = "helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack --version 66.3.1 -n $Namespace $valuesParam --wait --timeout 10m"

Invoke-Expression $installCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Prometheus Operator installed successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to install Prometheus Operator" -ForegroundColor Red
    exit 1
}

# ========================================
# STEP 5: Install LGTM Stack
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Installing LGTM Stack" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$valuesFile = Join-Path $PSScriptRoot  "helm-values" "lgtm.yaml"

if (-not (Test-Path $valuesFile)) {
    Write-Host "  lgtm.yaml not found, using default values" -ForegroundColor Yellow
    $valuesParam = ""
} else {
    $valuesParam = "-f `"$valuesFile`""
}

Write-Host "Installing LGTM Stack (this may take several minutes)..." -ForegroundColor Cyan
$installCmd = "helm upgrade --install lgtm grafana/lgtm-distributed --version 2.1.0 -n $Namespace $valuesParam --wait --timeout 15m"

Invoke-Expression $installCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ LGTM Stack installed successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to install LGTM Stack" -ForegroundColor Red
    exit 1
}

# ========================================
# STEP 6: Deploy Additional Components
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Deploying Additional Components" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$manifestsPath = Join-Path $PSScriptRoot "manifests"

# Deploy OpenTelemetry Collector
$otelFile = Join-Path $manifestsPath "otel-collector.yaml"
if (Test-Path $otelFile) {
    Write-Host "Deploying OpenTelemetry Collector..." -ForegroundColor Cyan
    kubectl apply -f $otelFile
    Write-Host "  ✓ OpenTelemetry Collector deployed" -ForegroundColor Green
}

# Deploy Alloy
$alloyFile = Join-Path $manifestsPath "alloy.yaml"
if (Test-Path $alloyFile) {
    Write-Host "Deploying Alloy..." -ForegroundColor Cyan
    kubectl apply -f $alloyFile
    Write-Host "  ✓ Alloy deployed" -ForegroundColor Green
}

# ========================================
# STEP 7: Build and Deploy Logging Application
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Building and Deploying Logging Application" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# Build Docker image from src folder
$srcPath = Join-Path $PSScriptRoot "src"
if (Test-Path $srcPath) {
    Write-Host "Building Docker image from src folder..." -ForegroundColor Cyan
    
    # Change to src directory to build the image
    Push-Location $srcPath
    try {
        docker build -t logging-app:latest .
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Docker image built successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to build Docker image" -ForegroundColor Red
            Pop-Location
            exit 1
        }
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "  ✗ src folder not found" -ForegroundColor Red
    exit 1
}

# Deploy logging application
$appPath = Join-Path $manifestsPath "app"
$loggingAppFile = Join-Path $appPath "logging-app.yaml"
if (Test-Path $loggingAppFile) {
    Write-Host "Deploying logging application..." -ForegroundColor Cyan
    kubectl apply -f $loggingAppFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Logging application deployed" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to deploy logging application" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✗ logging-app.yaml not found in manifests/app/" -ForegroundColor Red
    exit 1
}

# Deploy PodMonitor for metrics collection
$podMonitorFile = Join-Path $appPath "podmonitor.yaml"
if (Test-Path $podMonitorFile) {
    Write-Host "Deploying PodMonitor for metrics collection..." -ForegroundColor Cyan
    kubectl apply -f $podMonitorFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ PodMonitor deployed" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to deploy PodMonitor" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✗ podmonitor.yaml not found in manifests/app/" -ForegroundColor Red
    exit 1
}

# ========================================
# Installation Complete!
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Installation Complete!" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "The LGTM Stack has been successfully installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Get Grafana admin password:"
Write-Host "     kubectl get secret --namespace $Namespace lgtm-grafana -o jsonpath=`"{.data.admin-password}`" | Out-String | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$_)) }"
Write-Host ""
Write-Host "  2. Access Grafana:"
Write-Host '     [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret --namespace monitoring lgtm-grafana -o jsonpath="{.data.admin-password}")))'
Write-Host "     kubectl port-forward svc/lgtm-grafana 3000:80 -n $Namespace"
Write-Host "     Open browser: http://localhost:3000"
Write-Host "     Username: admin"
Write-Host ""
Write-Host "  3. Test services:"
Write-Host "     .\test-services.ps1"