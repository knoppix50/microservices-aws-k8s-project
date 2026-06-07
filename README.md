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
The deployment cycle is split into independent, single-purpose scripts. This modular approach prevents AWS IAM propagation delays and optimizes execution within the limited lifespan of federated session tokens.

### Phase 1: Environment Provisioning
Initialize the AWS EKS control plane and worker nodes without telemetry attachments:
```bash
./install-infra.sh
```
*   **Mechanics**: Executes `eksctl` to provision a single-node cluster architecture and creates the underlying Node Group CloudFormation stack.


### Phase 2: Orchestrated Microservices Deployment
Deploy the persistent database layer, execute seeding scripts, and schedule the stateless Python API:
```bash
./deploy.sh
```
*   **Mechanics**: Provisions `PersistentVolume` resources, injects SQL migration scripts via a `ConfigMap` to bypass metadata size limits, and schedules the application pods (`coworking`).


### Phase 3: Dynamic Integration Testing
Generate live network traffic and verify microservice endpoint communication:
```bash
./test-api.sh
```
*   **Mechanics**: Extracts the dynamic AWS Elastic Load Balancer (ELB) DNS hostname via `jsonpath` and runs automated `curl` tests against `/api/reports/` to validate HTTP 200 responses.


### Phase 4: CloudWatch Telemetry Installation
Install cluster observability only after verifying that the application layer is stable and active:
```bash
./install-cloudwatch.sh
```
* **Mechanics**: Dynamically fetches the active worker node IAM role ARN from CloudFormation, attaches the `CloudWatchAgentServerPolicy`, and deploys the `amazon-cloudwatch-observability` addon.


### Phase 5: Log Verification & Maintenance
Manually verify data ingestion in the AWS Management Console:
1. Navigate to **CloudWatch** > **Logs** > **Log groups**.
2. Select `/aws/containerinsights/<cluster-name>/application`.
3. Inspect active Log Streams to confirm receipt of Flask microservice container logs.


### Phase 6: Application Cleanup
Safely destroy deployed application resources to clean the Kubernetes state:
```bash
./destroy.sh
```
*   **Mechanics**: Performs an inverse cascade deletion of application deployments, database pods, and network services using `--ignore-not-found` flags.


### Phase 7: Cluster Teardown (Final Destruction)
Permanently destroy cloud infrastructure to stop AWS billing before token expiration:
```bash
./delete-cluster.sh
```
*   **Mechanics**: Triggers `eksctl delete cluster` to de-provision Amazon EC2 worker nodes, remove associated IAM roles, and delete the virtual network (VPC).

---

## 3. DevOps Architecture Recommendations

*   **Resource Constraints**: Microservices explicitly declare compute boundaries within Kubernetes definitions (`requests`/`limits`) to maintain pod scheduling stability and eliminate node resource starvation.
*   **Semantic Versioning**: Images are pushed to private **AWS ECR (Elastic Container Registry)** using discrete `$IMAGE_TAG` parameters. Application updates trigger progressive *Rolling Updates* in the clúster topology ensuring zero downtime.
*   **High-Availability Scaling**: While a single worker node (`t3.small`) architecture is utilized for cost-sensitive evaluation via host storage, high-throughput production environments scale dynamically across multiple Availability Zones using the **AWS EBS CSI Driver** paired with elastic network block storages.

