# Local Kubernetes on Apple silicon: apple/container + kiac
#
#   just                     list recipes
#   just up                  start runtime, create or resume the cluster, wait for Ready
#   just restart             bounce the container runtime and heal the cluster
#   just verify              kiac health checks + node/pod overview
#   just name=prod workers=2 up    override any variable below on the command line

set shell := ["bash", "-euo", "pipefail", "-c"]

name    := env("KIAC_CLUSTER", "devk8s")
workers := env("KIAC_WORKERS", "2")
distro  := env("KIAC_DISTRO", "kubeadm")   # kubeadm | k3s
k8s     := env("KIAC_K8S_VERSION", "")     # e.g. 1.34; empty = kiac default
flags   := env("KIAC_FLAGS", "--cni cilium --kernel full --observability --gateway")  # extra create flags
ctx     := "kiac-" + name
timeout := "180s"

default:
    @just --list

# --- apple/container runtime -------------------------------------------------

# Start the apple/container system service if it isn't running
runtime:
    @container system status >/dev/null 2>&1 || { echo "starting container runtime…"; container system start; }

# Stop the apple/container service (stops ALL Apple containers, not just this cluster)
[confirm("Stop the apple/container runtime and every container on it?")]
runtime-stop:
    container system stop

# Check prerequisites (macOS, container CLI, service, kubectl)
doctor:
    kiac doctor

# --- cluster lifecycle -------------------------------------------------------

# Start everything: runtime, then create the cluster or resume an existing one
up: runtime
    #!/usr/bin/env bash
    set -euo pipefail
    if kiac get clusters | awk 'NR>1 {print $1}' | grep -qx "{{name}}"; then
      echo "cluster '{{name}}' exists, resuming…"
      kiac resume cluster --name {{name}}
    else
      echo "creating cluster '{{name}}' ({{distro}}, {{workers}} worker(s))…"
      kiac create cluster --name {{name}} --workers {{workers}} --distro {{distro}} \
        {{ if k8s != "" { "--k8s-version " + k8s } else { "" } }} {{flags}}
    fi
    just wait

# Bounce the runtime and heal the cluster (fixes stale IPs, kubeconfig, networking)
restart:
    container system stop || true
    container system start
    kiac resume cluster --name {{name}}
    just wait

# Heal the cluster without touching the runtime (after a Mac reboot or sleep weirdness)
resume: runtime
    kiac resume cluster --name {{name}}
    just wait

# Delete and create from scratch
[confirm("Delete and recreate the cluster? All workloads and PVC data will be lost.")]
recreate: runtime
    kiac delete cluster --name {{name}} || true
    just up

# Delete the cluster
[confirm("Delete the cluster? All workloads and PVC data will be lost.")]
down:
    kiac delete cluster --name {{name}}

# --- verification ------------------------------------------------------------

# Wait until every node reports Ready
wait:
    kubectl --context {{ctx}} wait --for=condition=Ready nodes --all --timeout={{timeout}}

# Full health check: kiac's end-to-end checks plus a quick look at the cluster
verify:
    kiac verify cluster --name {{name}}
    @echo
    kubectl --context {{ctx}} get nodes -o wide
    @echo
    kubectl --context {{ctx}} get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded || true

# Machine-readable verify (non-zero exit on required failures, good for CI/scripts)
verify-json:
    kiac verify cluster --name {{name}} -o json

# Quick overview of runtime, clusters, and nodes
status:
    @echo "== runtime =="; container system status || true
    @echo; echo "== clusters =="; kiac get clusters -o wide
    @echo; echo "== nodes =="; kiac get nodes --name {{name}}

# Point kubectl at this cluster
use:
    kubectl config use-context {{ctx}}

# --- node chaos / images / diagnostics --------------------------------------

# Simulate a node failure, e.g. `just node-stop worker-1`
node-stop node:
    kiac stop node {{node}} --name {{name}}

# Bring a stopped node back
node-start node:
    kiac start node {{node}} --name {{name}}

# Build an image with apple/container and load it into every node
image tag ctxdir=".": runtime
    container build -t {{tag}} {{ctxdir}}
    kiac load image {{tag}} --name {{name}}

# Write a redacted diagnostic bundle for bug reports
bundle:
    kiac support bundle --name {{name}}

# Open kiac's local web console
ui:
    kiac ui
