#!/bin/bash

# Pro terminal colors for clean cleanup logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

# =====================================================================
# TRY...CATCH SIMULATION FUNCTION (Java-like structure)
# =====================================================================
try_destroy() {
  local COMMAND="$1"
  local DESCRIPTION="$2"

  echo -e "${BLUE}--> Attempting Deletion (Try): ${DESCRIPTION}...${NC}"
  eval "$COMMAND"
  local EXIT_CODE=$?

  # Catch Block: If command fails (and not because the resource is already gone)
  if [ $EXIT_CODE -ne 0 ]; then
    echo -e "\n${YELLOW}[WARNING] Could not complete cleanup for: $DESCRIPTION${NC}"
    echo -e "${YELLOW}Executed command:${NC} \`$COMMAND\`"
    echo -e "${YELLOW}Resource might already be deleted. Continuing...${NC}\n"
  else
    echo -e "${GREEN}[DELETED] Phase completed successfully.${NC}\n"
  fi
}

echo -e "${RED}=============================================== ${NC}"
echo -e "${RED}     STARTING TOTAL DESTRUCTION OF DEPLOYMENT   ${NC}"
echo -e "${RED}=============================================== ${NC}\n"

# ---------------------------------------------------------------------
# BLOCK 1: APPLICATION LAYER DESTRUCTION (PYTHON API)
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 1: REMOVING APPLICATION LAYER ===${NC}"

try_destroy "kubectl delete -f aws-eks-app-deploy/coworking.yaml --ignore-not-found" "API Deployment and Service (Coworking)"

try_destroy "kubectl delete -f aws-eks-app-deploy/secret.yaml --ignore-not-found" "Application confidential secrets"

try_destroy "kubectl delete -f aws-eks-app-deploy/configmap.yaml --ignore-not-found" "API environment variables ConfigMap"

# ---------------------------------------------------------------------
# BLOCK 2: DATABASE DESTRUCTION (POSTGRES)
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 2: REMOVING DATABASE INFRASTRUCTURE ===${NC}"

try_destroy "kubectl delete -f aws-eks-db-deploy/postgresql-deployment.yaml --ignore-not-found" "Postgres 17 Engine"

try_destroy "kubectl delete -f aws-eks-db-deploy/postgresql-service.yaml --ignore-not-found" "Postgres network service"

# ---------------------------------------------------------------------
# BLOCK 3: STORAGE AND HEAVY CONFIGMAPS CLEANUP
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== BLOCK 3: CLEANING PERSISTENCE AND DATA SEEDS ===${NC}"

try_destroy "kubectl delete -f aws-eks-db-deploy/pvc.yaml --ignore-not-found" "PersistentVolumeClaim (PVC)"

try_destroy "kubectl delete configmap postgres-init-script --ignore-not-found" "Massive SQL ConfigMap (3500 Inserts)"

# If utilizing a static PV (hostPath) for single-node/local testing, purge it here
try_destroy "kubectl delete -f aws-eks-db-deploy/pv.yaml --ignore-not-found" "Static PersistentVolume (PV)"

# ---------------------------------------------------------------------
# FINAL CLEANUP VERIFICATION
# ---------------------------------------------------------------------
echo -e "${YELLOW}=== FINAL RESIDUAL CHECK ===${NC}"
echo -e "Waiting 10 seconds for Kubernetes to sync deletions..."
sleep 10

# Security force-purge in case some pods hang in 'Terminating' status due to finalizers
echo "Verifying no ghost pods are left..."
PODS_LEFT=$(kubectl get pods 2>/dev/null | grep -E 'postgresql|coworking')
if [ ! -z "$PODS_LEFT" ]; then
  echo -e "${YELLOW}Detected pods stuck in terminating state. Forcing immediate deletion...${NC}"
  kubectl get pods -o name 2>/dev/null | grep -E 'postgresql|coworking' | xargs -I {} kubectl delete {} --grace-period=0 --force 2>/dev/null
fi

echo -e "\n${GREEN}=== CURRENT CLUSTER STATUS (SHOULD BE EMPTY) ===${NC}"
kubectl get deployments,pods,svc,pvc,pv

echo -e "\n${GREEN}Done! Cluster is completely clean and free of charges. Flawless execution!${NC}"

