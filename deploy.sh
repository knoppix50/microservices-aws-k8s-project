#!/bin/bash

# Pro terminal colors for readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

# =====================================================================
# TRY...CATCH SIMULATION FUNCTION (Java-like structure)
# =====================================================================
try_command() {
  local COMMAND="$1"
  local DESCRIPTION="$2"

  echo -e "${BLUE}--> Attempting (Try): ${DESCRIPTION}...${NC}"
  eval "$COMMAND"
  local EXIT_CODE=$?

  if [ $EXIT_CODE -ne 0 ]; then
    echo -e "\n${RED}====================================================${NC}"
    echo -e "${RED}[CATCH] CRITICAL ERROR DETECTED IN DEPLOYMENT!${NC}"
    echo -e "${RED}Affected phase:${NC} $DESCRIPTION"
    echo -e "${RED}Failed command:${NC} \`$COMMAND\`"
    echo -e "${RED}Linux exit code:${NC} $EXIT_CODE"
    echo -e "\n${RED}====================================================${NC}"
    echo -e "${RED}Aborting deployment safely. Exiting script...${NC}"
    exit $EXIT_CODE
  fi
  echo -e "${GREEN}[OK] Phase completed successfully.${NC}\n"
}

echo -e "${BLUE}=============================================== ${NC}"
echo -e "${BLUE}     LAUNCHING FULL DEPLOYMENT ON AWS EKS       ${NC}"
echo -e "${BLUE}=============================================== ${NC}\n"

# ---------------------------------------------------------------------
# BLOCK 1: DATABASE INFRASTRUCTURE (POSTGRES)
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 1: PERSISTENCE LAYER (POSTGRES) ===${NC}"

# Create static physical volume on AWS node to prevent failures
try_command "kubectl apply -f aws-eks-db-deploy/pv.yaml" "Create static PersistentVolume (PV)"

try_command "kubectl delete configmap postgres-init-script 2>/dev/null; kubectl create -f aws-eks-db-deploy/postgres-configmap.yaml" "Create massive SQL ConfigMap (Bypassing Annotation limit)"

try_command "kubectl apply -f aws-eks-db-deploy/pvc.yaml" "Create PersistentVolumeClaim (PVC)"

echo -e "${YELLOW}Waiting for PVC to bind with the static PV (Bound status)...${NC}"
while true; do
  STATUS=$(kubectl get pvc postgresql-pvc -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$STATUS" == "Bound" ]; then
    echo -e "${GREEN}Storage linked successfully!${NC}\n"
    break
  else
    echo "PVC status: $STATUS. Retrying in 5 seconds..."
    sleep 5
  fi
done

try_command "kubectl apply -f aws-eks-db-deploy/postgresql-service.yaml" "Launch Postgres network service"

try_command "kubectl apply -f aws-eks-db-deploy/postgresql-deployment.yaml" "Deploy Postgres 17 engine"

# ---------------------------------------------------------------------
# BLOCK 2: POSTGRES HEALTH CHECK & SECURITY PAUSE
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 2: READINESS TESTS (15s INTERVALS) ===${NC}"
while true; do
  echo "Running test: Verifying if Postgres Pod is in Running status..."
  
  # Search for any pod matching "postgresql" and check if it is "Running"
  if kubectl get pods 2>/dev/null | grep postgresql | grep -q "Running"; then
    echo -e "${GREEN}Postgres pod is running confirmed!${NC}"
    echo -e "${YELLOW}Waiting an extra 15 seconds to ensure 3500 inserts finished seeding...${NC}\n"
    sleep 15
    break
  else
    echo -e "Postgres is still booting or processing data. Waiting 15 seconds for next test..."
    sleep 15
  fi
done

# ---------------------------------------------------------------------
# BLOCK 3: APPLICATION API INFRASTRUCTURE (APP)
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 3: APPLICATION LAYER (PYTHON API) ===${NC}"

try_command "kubectl apply -f aws-eks-app-deploy/configmap.yaml" "Apply API environment variables ConfigMap"

try_command "kubectl apply -f aws-eks-app-deploy/secret.yaml" "Apply application confidential secrets"

try_command "kubectl apply -f aws-eks-app-deploy/coworking.yaml" "Deploy Python API (Coworking Deployment & Service)"

# ---------------------------------------------------------------------
# BLOCK 4: FINAL SYSTEM VERIFICATION
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 4: FINAL CLUSTER HEALTH CHECK ===${NC}"
echo -e "Waiting 15 seconds for final cluster stabilization..."
sleep 15

echo -e "${GREEN}=== CURRENT DEPLOYMENT STATUS ===${NC}"
kubectl get deployments,pods,svc,pvc

echo -e "\n${GREEN}Congratulations! The entire project has been deployed 100% automated without errors.${NC}"

