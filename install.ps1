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

# Color functions for output
function Write-Success {
    Write-Host $args[0] -ForegroundColor Green
}

function Write-Info {
    Write-Host $args[0] -ForegroundColor Cyan
}

function Write-Warning {
    Write-Host $args[0] -ForegroundColor Yellow
}

function Write-Error {
    Write-Host $args[0] -ForegroundColor Red
}

function Write-Header {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host $args[0] -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
}

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    $prerequisites = @{
        "kubectl" = "Kubernetes CLI tool for managing clusters"
        "helm" = "Kubernetes package manager"
    }
    
    $missingTools = @()
    
    foreach ($tool in $prerequisites.Keys) {
        Write-Info "Checking for $tool..."
        
        try {
            $version = & $tool version --short 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "  ✓ $tool is installed: $version"
            } else {
                throw
            }
        }
        catch {
            Write-Error "  ✗ $tool is not installed or not in PATH"
            Write-Warning "    Description: $($prerequisites[$tool])"
            $missingTools += $tool
        }
    }
    
    # Check Kubernetes connectivity
    Write-Info "Checking Kubernetes cluster connectivity..."
    try {
        $clusterInfo = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "  ✓ Connected to Kubernetes cluster"
            kubectl version --short
        } else {
            throw
        }
    }
    catch {
        Write-Error "  ✗ Cannot connect to Kubernetes cluster"
        Write-Warning "    Ensure you have a valid kubeconfig and cluster access"
        $missingTools += "kubernetes-connection"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Host ""
        Write-Error "Prerequisites check failed!"
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
    
    Write-Success "`n✓ All prerequisites met!"
}

# Add Helm repositories
function Add-HelmRepositories {
    Write-Header "Adding Helm Repositories"
    
    $repositories = @{
        "prometheus-community" = "https://prometheus-community.github.io/helm-charts"
        "grafana" = "https://grafana.github.io/helm-charts"
    }
    
    foreach ($repo in $repositories.Keys) {
        Write-Info "Adding $repo repository..."
        helm repo add $repo $repositories[$repo] 2>&1 | Out-String | Write-Verbose
        if ($LASTEXITCODE -eq 0) {
            Write-Success "  ✓ Added $repo repository"
        } else {
            Write-Error "  ✗ Failed to add $repo repository"
            exit 1
        }
    }
    
    Write-Info "Updating Helm repositories..."
    helm repo update 2>&1 | Out-String | Write-Verbose
    Write-Success "  ✓ Repositories updated"
}

# Create namespace
function New-Namespace {
    param([string]$Namespace)
    
    Write-Header "Creating Namespace"
    
    Write-Info "Checking if namespace '$Namespace' exists..."
    $nsExists = kubectl get namespace $Namespace --ignore-not-found 2>&1
    
    if ($nsExists) {
        Write-Warning "  Namespace '$Namespace' already exists"
    } else {
        Write-Info "Creating namespace '$Namespace'..."
        kubectl create namespace $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Success "  ✓ Created namespace '$Namespace'"
        } else {
            Write-Error "  ✗ Failed to create namespace"
            exit 1
        }
    }
}

# Install Prometheus Operator
function Install-PrometheusOperator {
    param([string]$Namespace)
    
    Write-Header "Installing Prometheus Operator"
    
    $valuesFile = Join-Path $PSScriptRoot ".." "helm" "values-prometheus.yaml"
    
    if (-not (Test-Path $valuesFile)) {
        Write-Warning "  values-prometheus.yaml not found, using default values"
        $valuesParam = ""
    } else {
        $valuesParam = "-f `"$valuesFile`""
    }
    
    Write-Info "Installing Prometheus Operator..."
    $installCmd = "helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack --version 66.3.1 -n $Namespace $valuesParam --wait --timeout 10m"
    
    Invoke-Expression $installCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "  ✓ Prometheus Operator installed successfully"
    } else {
        Write-Error "  ✗ Failed to install Prometheus Operator"
        exit 1
    }
}

# Install LGTM Stack
function Install-LGTMStack {
    param([string]$Namespace)
    
    Write-Header "Installing LGTM Stack"
    
    $valuesFile = Join-Path $PSScriptRoot ".." "helm" "values-lgtm.local.yaml"
    
    if (-not (Test-Path $valuesFile)) {
        Write-Warning "  values-lgtm.local.yaml not found, using default values"
        $valuesParam = ""
    } else {
        $valuesParam = "-f `"$valuesFile`""
    }
    
    Write-Info "Installing LGTM Stack (this may take several minutes)..."
    $installCmd = "helm upgrade --install lgtm grafana/lgtm-distributed --version 2.1.0 -n $Namespace $valuesParam --wait --timeout 15m"
    
    Invoke-Expression $installCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "  ✓ LGTM Stack installed successfully"
    } else {
        Write-Error "  ✗ Failed to install LGTM Stack"
        exit 1
    }
}

# Deploy additional components
function Deploy-AdditionalComponents {
    param([string]$Namespace)
    
    Write-Header "Deploying Additional Components"
    
    $manifestsPath = Join-Path $PSScriptRoot ".." "manifests"
    
    # Deploy OpenTelemetry Collector
    $otelFile = Join-Path $manifestsPath "otel-collector.yaml"
    if (Test-Path $otelFile) {
        Write-Info "Deploying OpenTelemetry Collector..."
        kubectl apply -f $otelFile -n $Namespace
        Write-Success "  ✓ OpenTelemetry Collector deployed"
    }
    
    # Deploy Promtail
    $promtailFile = Join-Path $manifestsPath "promtail.docker.yaml"
    if (Test-Path $promtailFile) {
        Write-Info "Deploying Promtail..."
        kubectl apply -f $promtailFile
        Write-Success "  ✓ Promtail deployed"
    }
    
    # Deploy .NET API application
    $appPath = Join-Path $manifestsPath "src"
    if (Test-Path $appPath) {
        Write-Info "Deploying .NET API application..."
        kubectl apply -f $appPath -n $Namespace
        Write-Success "  ✓ .NET API application deployed"
    }
}

# Main execution
function Main {
    Write-Header "LGTM Stack Installation Script"
    Write-Info "Installing to namespace: $Namespace"
    
    if (-not $SkipPrerequisites) {
        Test-Prerequisites
    }
    
    Add-HelmRepositories
    New-Namespace -Namespace $Namespace
    Install-PrometheusOperator -Namespace $Namespace
    Install-LGTMStack -Namespace $Namespace
    Deploy-AdditionalComponents -Namespace $Namespace
    
    Write-Header "Installation Complete!"
    
    Write-Success "The LGTM Stack has been successfully installed!"
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Get Grafana admin password:"
    Write-Host "     kubectl get secret --namespace $Namespace lgtm-grafana -o jsonpath=`"{.data.admin-password}`" | Out-String | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$_)) }"
    Write-Host ""
    Write-Host "  2. Access Grafana:"
    Write-Host "     kubectl port-forward svc/lgtm-grafana 3000:80 -n $Namespace"
    Write-Host "     Open browser: http://localhost:3000"
    Write-Host "     Username: admin"
    Write-Host ""
    Write-Host "  3. Test services:"
    Write-Host "     .\test-services.ps1"
}

# Run main function
Main