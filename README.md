# Argo Rollouts Demo (Canary on EKS)

This repo contains the application source, Dockerfile, and Kubernetes manifests for an **Argo Rollouts canary deployment** on EKS. Two app versions are used: **v1.0** (header: *ARGO ROLLOUTS DEMO*) and **v2.0** (header: *ARGO ROLLOUTS DEMO!!*). You can add a screenshot of your deployed app (e.g. `docs/demo-screenshot.png`) and reference it here if you like.

---

## Deliverables overview

| Item | Location |
|------|----------|
| **Dockerfile** | [`Dockerfile`](./Dockerfile) (multi-stage, distroless, non-root) |
| **Built image tags** | `girish514/rollouts-demo:v1.0`, `girish514/rollouts-demo:v2.0` |
| **Kubernetes manifests** | [`k8s/`](./k8s/): `rollout-canary.yaml`, `service.yaml`, `ingress.yaml` |

---

## Chosen strategy: Canary

Traffic is shifted gradually from the stable version to the new version:

1. **20%** traffic to canary → pause 60s  
2. **50%** traffic to canary → pause 60s  
3. **100%** (full promotion) when healthy  

The Rollout uses two services (stable + canary), NGINX ingress for traffic splitting, and HTTP readiness/liveness probes (`/`, `/healthz`) for resilience.

---

## Deploy and run

**Prerequisites:** Kubernetes cluster (e.g. EKS) with [Argo Rollouts](https://argoproj.github.io/argo-rollouts/getting-started/) and NGINX Ingress Controller installed.

```bash
# Deploy (baseline v1.0)
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/rollout-canary.yaml
kubectl apply -f k8s/ingress.yaml

# Trigger canary to v2.0
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:v2.0"}]}}}}'

# Watch
kubectl describe rollout rollouts-demo
```

Use the LoadBalancer hostname from `kubectl get svc rollouts-demo` (or your ingress host) to open the app in a browser and confirm the header change from *DEMO* to *DEMO!!* as the canary completes.

---

## Rollback (failure handling)

To simulate a bad release and then roll back to the last good version:

```bash
# Simulate bad image
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:nonexistent"}]}}}}'

# Roll back to v1.0
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:v1.0"}]}}}}'
```

---

## AWS/EKS mapping

| This solution | AWS/EKS equivalent |
|---------------|---------------------|
| Application pods | EKS managed node groups / Fargate |
| `girish514/rollouts-demo` on Docker Hub | ECR repository |
| Service `type: LoadBalancer` | NLB/CLB (or ALB via AWS Load Balancer Controller) |
| NGINX Ingress | ALB Ingress Controller + `ingressClassName: alb` (adjust Rollout `trafficRouting` to `alb`) |
| Argo Rollouts controller | Runs in cluster (e.g. `argo-rollouts` namespace) |
| Readiness/liveness probes | Kubernetes self-healing + Rollouts health checks |

---

## Source and image build

- **Source:** Go backend and static assets in this repo; images built from this source (no pre-built image use).
- **Build and push:**
  ```bash
  docker build -t girish514/rollouts-demo:v1.0 .
  docker push girish514/rollouts-demo:v1.0
  # After changes for v2 (e.g. UI), tag and push v2.0
  docker build -t girish514/rollouts-demo:v2.0 .
  docker push girish514/rollouts-demo:v2.0
  ```
