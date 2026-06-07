#!/bin/bash

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color



# ---------------------------------------------------------------------
# PHASE 1: IAM NODE ROLE EXTRACTION
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
# PHASE 2: CLOUDWATCH POLICY ATTACHMENT
# ---------------------------------------------------------------------
echo -e "${BLUE}[3/4] Attaching CloudWatchAgentServerPolicy to worker nodes role...${NC}"
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR] Failed to attach IAM policy.${NC}"
  exit 1
fi
sleep 90
echo -e "${GREEN}[OK] CloudWatch policy linked successfully.${NC}\n"

# ---------------------------------------------------------------------
# PHASE 3: OBSERVABILITY ADDON INSTALLATION
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
echo -e "${GREEN}    AWS CLOUDWATCH ADDON SUCCESSFULLY INSTALLED  ${NC}"
echo -e "${GREEN}==================================================${NC}"



