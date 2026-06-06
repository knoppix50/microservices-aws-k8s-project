# Microservices Deployment Pipeline on AWS EKS

This repository contains the containerization, continuous integration, and fully automated deployment architecture for a Python-based analytics microservice and a persistent Postgres SQL database deployed on **Amazon EKS (Elastic Kubernetes Service)**.

---

## 1. Repository Structure

The project layout is structured as follows:

*   **`analytics/`**: Source code of the Python API microservice, including its dependencies (`requirements.txt`) and multi-stage `Dockerfile`.
*   **`aws-eks-app-deploy/`**: Kubernetes declarative manifests (`coworking.yaml`, `configmap.yaml`, `secret.yaml`) for the application layer.
*   **`aws-eks-db-deploy/`**: Kubernetes database manifests containing deployment, networking, and volume storage settings (`pvc.yaml`, `pv.yaml`).
*   **`db/`**: Alphabetically ordered database migration and seed scripts executed automatically during initial database provisioning.
*   **`buildspec.yml`**: AWS CodeBuild pipeline configuration specification for CI container tagging based on Semantic Versioning.
*   **Automation Scripts**: Production-ready Bash utilities handling orchestration, dynamic health checks, endpoint testing, and cluster teardown.

---

## 2. Infrastructure & Automation Workflow

The deployment cycle is orchestrated using four specialized shell scripts to eliminate manual operations and ensure zero configuration drift:

### Phase 1: Environment Provisioning
Initialize the AWS EKS control plane and worker nodes, install logging telemetry, and assign policies:
```bash
./install-infra.sh
```
*   **Mechanics**: Executes `eksctl` to provision a single-node cluster architecture. It dynamically grabs the generated worker node IAM role ARN, attaches the native `CloudWatchAgentServerPolicy`, and installs the `amazon-cloudwatch-observability` addon for deep cluster telemetry metrics.

### Phase 2: Orchestrated Microservices Deployment
Deploy the persistent database layer and self-seed initial mock data records before scheduling the stateless API:
```bash
./deploy.sh
```
*   **Mechanics**: Implements a Java-like `try/catch` execution handler. It provisions the `PersistentVolume` configurations, dynamically streams the `db/` SQL scripts into an ephemeral `ConfigMap` to bypass the `kubectl.kubernetes.io/last-applied-configuration` metadata size limit (256KB), and binds it to `/docker-entrypoint-initdb.d`. 
*   **Readiness Probes**: Loops health diagnostics until the Postgres process reports `Running`, enforces a security cooldown to complete the 3,500 record insertions sequentially, and subsequently updates the application pods (`coworking`).

### Phase 3: Dynamic Integration Testing
Verify complete microservice communication, database networking, and request processing metrics:
```bash
./test-api.sh
```
*   **Mechanics**: Queries the live Kubernetes API via `jsonpath` to extract the dynamically assigned AWS Elastic Load Balancer (ELB) external DNS hostname. It automates health checking over the network and performs end-to-end `curl` integration tests against `/api/reports/user_visits` and `/api/reports/daily_usage`, validating HTTP 200 response codes and payload structures.

### Phase 4: Application Cleanup
Safely destroy deployed resources to prevent unexpected cloud computing storage charges:
```bash
./destroy.sh
```
*   **Mechanics**: Performs inverse cascade deletion. Purges application deployments, database pods, configurations, and network endpoints using `--ignore-not-found` flags. It intercepts and purges zombie processes hung in `Terminating` states due to resource finalizers by sending immediate force-deletion signals.


### Phase 5: Cluster Teardown (Final Destruction)
Permanently destroy the underlying cloud control plane and infrastructure to stop AWS billing:
```bash
./delete-cluster.sh
```
*   **Mechanics**: Prompts the administrator for an explicit `YES` security confirmation before triggering `eksctl delete cluster`. It safely de-provisions the Amazon EC2 worker nodes, removes associated IAM roles, tears down the cloud virtual network (VPC), and outputs a final green success confirmation once AWS registers the complete infrastructure purge.

---

## 3. DevOps Architecture Recommendations

*   **Resource Constraints**: Microservices explicitly declare compute boundaries within Kubernetes definitions (`requests`/`limits`) to maintain pod scheduling stability and eliminate node resource starvation.
*   **Semantic Versioning**: Images are pushed to private **AWS ECR (Elastic Container Registry)** using discrete `$IMAGE_TAG` parameters. Application updates trigger progressive *Rolling Updates* in the clúster topology ensuring zero downtime.
*   **High-Availability Scaling**: While a single worker node (`t3.small`) architecture is utilized for cost-sensitive evaluation via host storage, high-throughput production environments scale dynamically across multiple Availability Zones using the **AWS EBS CSI Driver** paired with elastic network block storages.

