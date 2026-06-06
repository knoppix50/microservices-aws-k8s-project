#!/bin/bash

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}        AWS EKS INFRASTRUCTURE AUTOMATION         ${NC}"
echo -e "${BLUE}==================================================${NC}\n"

# ---------------------------------------------------------------------
# PHASE 1: EKS CLUSTER CREATION
# ---------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Starting EKS cluster creation in AWS...${NC}"
echo -e "${YELLOW}Note: This process takes 15 to 20 minutes. Grab a coffee...${NC}"

eksctl create cluster \
  --name my-cluster \
  --region us-east-1 \
  --nodegroup-name my-nodes \
  --node-type t3.small \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 2

if [ $? -ne 0 ]; then
  echo -e "\n${RED}[ERROR] EKS cluster creation failed in AWS. Aborting script.${NC}"
  exit 1
fi
echo -e "${GREEN}[OK] EKS Cluster created and ready to operate.${NC}\n"

# Short security pause to sync local credentials
sleep 90

# ---------------------------------------------------------------------
# PHASE 2: IAM NODE ROLE EXTRACTION
# ---------------------------------------------------------------------
echo -e "${BLUE}[2/4] Extracting IAM Node Role from AWS...${NC}"
NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name my-cluster --nodegroup-name my-nodes --query "nodegroup.nodeRole" --output text 2>/dev/null)

if [ -z "$NODE_ROLE_ARN" ] || [ "$NODE_ROLE_ARN" == "None" ]; then
  echo -e "${RED}[ERROR] Could not get IAM Role ARN. Are you authenticated in AWS?${NC}"
  exit 1
fi

ROLE_NAME=$(echo $NODE_ROLE_ARN | cut -d'/' -f2)
echo -e "${GREEN}[OK] IAM Role detected successfully:${NC} $ROLE_NAME\n"

# ---------------------------------------------------------------------
# PHASE 3: CLOUDWATCH POLICY ATTACHMENT
# ---------------------------------------------------------------------
echo -e "${BLUE}[3/4] Attaching CloudWatchAgentServerPolicy to worker nodes role...${NC}"
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR] Failed to attach IAM policy.${NC}"
  exit 1
fi
echo -e "${GREEN}[OK] CloudWatch policy linked successfully.${NC}\n"

# ---------------------------------------------------------------------
# PHASE 4: OBSERVABILITY ADDON INSTALLATION
# ---------------------------------------------------------------------
echo -e "${BLUE}[4/4] Installing CloudWatch Observability Addon on EKS...${NC}"
aws eks create-addon \
  --addon-name amazon-cloudwatch-observability \
  --cluster-name my-cluster

if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR] CloudWatch Addon deployment failed.${NC}"
  exit 1
fi

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}    INITIAL INFRASTRUCTURE SUCCESSFULLY DEPLOYED  ${NC}"
echo -e "${GREEN}    Active Cluster and CloudWatch telemetry ready. ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${YELLOW}You can now run your ./deploy.sh script to boot the apps.${NC}"

