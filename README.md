# lgtm-net

A Kubernetes-ready .NET application that demonstrates **structured logging**, **metrics**, and **tracing** with the LGTM observability stack.

## Prerequisites
- Kubernetes cluster (K3s, Minikube, or any K8s 1.24+)
- [Helm](https://helm.sh/) installed and configured
- `kubectl` configured to access your cluster
- PowerShell (Windows) or PowerShell Core (cross-platform)

## Installation
Deploy the LGTM stack and the .NET logging app:
```powershell
.\install.ps1
```


## Uninstallation
Remove all deployed components:
```powershell
.\uninstall.ps1
```