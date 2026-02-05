# Argo Rollouts Demo Application

This repo contains the [Argo Rollouts](https://github.com/argoproj/argo-rollouts) demo application source code and examples. It demonstrates the
various deployment strategies and progressive delivery features of Argo Rollouts.

![img](./demo.png)

## Challenge Deployment (EKS canary)

### Images and Dockerfile

- Images (built from source, non-root, distroless):
  - `girish514/rollouts-demo:v1.0` → header `ARGO ROLLOUTS DEMO` (baseline UI).
  - `girish514/rollouts-demo:v2.0` → header `ARGO ROLLOUTS DEMO!!` (canary target UI).
- Dockerfile hardened: multi-stage Go build, distroless runtime, `USER nonroot`, exposes `8080`.
- Relevant manifests:
  - `k8s/rollout-canary.yaml` – Argo Rollouts `Rollout` (canary strategy).
  - `k8s/service.yaml` – stable `LoadBalancer` service + internal canary service.
  - `k8s/ingress.yaml` – NGINX ingress, host `rollouts-demo.example.com` (map to your DNS or use the AWS ELB hostname directly).

### Chosen strategy – Canary (high level)

- **Canary Rollout** gradually shifts traffic from v1.0 (`DEMO`) to v2.0 (`DEMO!!`):
  - Step 1: send 20% of traffic to the new ReplicaSet, pause 60 seconds.
  - Step 2: send 50% of traffic, pause 60 seconds.
  - Step 3: promote to 100% if healthy.
- Rollout uses:
  - Stable and canary services for traffic splitting.
  - NGINX ingress canary created/managed by Argo Rollouts.
  - HTTP readiness and liveness probes on `/` and `/healthz` for resilience.

### Deploy baseline (v1.0)
```bash
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/rollout-canary.yaml
kubectl apply -f k8s/ingress.yaml
kubectl get rollout rollouts-demo
```

### Start canary to v2.0
```bash
# Without kubectl plugin
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:v2.0"}]}}}}'

# Observe
kubectl describe rollout rollouts-demo
kubectl get ingress rollouts-demo
```
Steps: weight 20% → pause 60s → 50% → pause 60s → 100%. Traffic is shifted via NGINX ingress canary created by the controller.

### Demonstrate failure and rollback
```bash
# Simulate a bad version (fails probe)
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:nonexistent"}]}}}}'

# After it pauses/fails, rollback to last stable (v2.0 or v1.0)
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:v1.0"}]}}}}'
```
If you install the kubectl plugin: `kubectl argo rollouts abort rollouts-demo` or `kubectl argo rollouts undo rollouts-demo`.

### AWS/EKS mapping
- **Compute**: EKS managed node groups run the application pods; Argo Rollouts controller runs in `argo-rollouts` namespace.
- **Container registry**: Docker Hub in this demo (`girish514/rollouts-demo`), equivalent to **ECR** in a production EKS setup.
- **Traffic exposure**:
  - `Service rollouts-demo` is `type: LoadBalancer`, which provisions an AWS NLB/CLB.
  - `Ingress` can instead be configured for **AWS Load Balancer Controller (ALB)** by switching `ingressClassName` to `alb` and using `trafficRouting.alb` in the Rollout.
- **Resilience and HA**:
  - Replica count and HPA (if enabled) provide high availability across nodes.
  - Readiness/liveness probes feed into Kubernetes self-healing and Argo Rollouts’ health assessment.
- **Observability (optional)**:
  - Analysis templates can hook into Prometheus, CloudWatch, or other metrics providers for automated canary analysis (not required for this assignment).

### Short demo script (<= 5 minutes)
```bash
kubectl apply -f k8s/service.yaml -f k8s/rollout-canary.yaml -f k8s/ingress.yaml
kubectl get rollout rollouts-demo
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:v2.0"}]}}}}'
kubectl describe rollout rollouts-demo
# curl the ingress host to see UI header change; watch during weight shifts
# simulate failure then rollback:
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:nonexistent"}]}}}}'
kubectl describe rollout rollouts-demo
kubectl patch rollout/rollouts-demo --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"girish514/rollouts-demo:v1.0"}]}}}}'
```

## Examples

The following examples are provided:

| Example | Description |
|---------|-------------|
| [Canary](examples/canary) | Rollout which uses the canary update strategy |
| [Blue-Green](examples/blue-green) |  Rollout which uses the blue-green update strategy |
| [Canary Analysis](examples/analysis) | Rollout which performs canary analysis as part of the update. Uses the prometheus metric provider. |
| [Experiment](examples/experiment) | Experiment which performs an A/B test. Performs analysis against the A and B using the job metric provider |
| [Preview Stack Testing](examples/preview-testing) | Rollout which launches an experiment that tests a preview stack (which receives no production traffic) |
| [Canary with istio (1)](examples/istio) | Rollout which uses host-level traffic splitting during update |
| [Canary with istio (2)](examples/istio-subset) | Rollout which uses subset-level traffic splitting during update |

Before running an example:

1. Install Argo Rollouts

- See the document [Getting Started](https://argoproj.github.io/argo-rollouts/getting-started/)

2. Install Kubectl Plugin

- See the document [Kubectl Plugin](https://argoproj.github.io/argo-rollouts/features/kubectl-plugin/)

To run an example:

1. Apply the manifests of one of the examples:

```bash
kustomize build <EXAMPLE-DIR> | kubectl apply -f -
```

2. Watch the rollout or experiment using the argo rollouts kubectl plugin:

```bash
kubectl argo rollouts get rollout <ROLLOUT-NAME> --watch
kubectl argo rollouts get experiment <EXPERIMENT-NAME> --watch
```

3. For rollouts, trigger an update by setting the image of a new color to run:
```bash
kubectl argo rollouts set image <ROLLOUT-NAME> "*=argoproj/rollouts-demo:yellow"
```

## Images

Available images colors are: red, orange, yellow, green, blue, purple (e.g. `argoproj/rollouts-demo:yellow`). Also available are:
* High error rate images, prefixed with the word `bad` (e.g. `argoproj/rollouts-demo:bad-yellow`)
* High latency images, prefixed with the word `slow` (e.g. `argoproj/rollouts-demo:slow-yellow`)


## Releasing

To release new images:

```bash
make release IMAGE_NAMESPACE=argoproj DOCKER_PUSH=true
```
