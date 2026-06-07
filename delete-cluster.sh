#!/bin/bash

# Pro terminal colors for readable output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

echo -e "${RED}==================================================${NC}"
echo -e "${RED}       CRITICAL: AWS EKS CLUSTER DELETION         ${NC}"
echo -e "${RED}==================================================${NC}\n"

echo -e "${RED}[WARNING] This action will permanently destroy 'my-cluster' and all its underlying resources.${NC}"
echo -e "${YELLOW}To proceed, please type ${RED}YES${YELLOW} and press Enter:${NC}"

# Read user confirmation input
read -r CONFIRMATION

if [ "$CONFIRMATION" == "YES" ]; then
  echo -e "\n${YELLOW}--> Confirmation approved. Initiating AWS EKS cluster teardown...${NC}"
  
  # ---------------------------------------------------------------------
  # PHASE 0: CLEANUP EXTERNAL IAM POLICIES (Prevents CloudFormation lock)
  # ---------------------------------------------------------------------
  echo -e "${BLUE}[1/2] Detaching CloudWatch policies from Node Group to avoid deletion locks...${NC}"
  NODE_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name my-cluster --nodegroup-name my-nodes --query "nodegroup.nodeRole" --output text 2>/dev/null)
  
  if [ ! -z "$NODE_ROLE_ARN" ] && [ "$NODE_ROLE_ARN" != "None" ]; then
    ROLE_NAME=$(echo $NODE_ROLE_ARN | cut -d'/' -f2)
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy 2>/dev/null
    echo -e "${GREEN}[OK] IAM Node Group role isolated successfully.${NC}\n"
  else
    echo -e "${YELLOW}[INFO] Node Group role not found or already deleted. Proceeding...${NC}\n"
  fi

sleep 45
  # ---------------------------------------------------------------------
  # PHASE 1: INFRASTRUCTURE PURGE
  # ---------------------------------------------------------------------
  echo -e "${RED}[2/2] Launching cluster destruction via eksctl...${NC}"
  echo -e "${YELLOW}Note: This process takes around 15 minutes. Please wait...${NC}\n"
  
  # Execute the blocking eksctl deletion command
  eksctl delete cluster --name my-cluster --region us-east-1
  
  # Check if the deletion command completed successfully
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}==================================================${NC}"
    echo -e "${GREEN}  SUCCESS: AWS EKS CLUSTER COMPLETELY PURGED     ${NC}"
    echo -e "${GREEN}  All cloud compute instances have been deleted.  ${NC}"
    echo -e "${GREEN}==================================================${NC}"
  else
    echo -e "\n${RED}[ERROR] Something went wrong during cluster deletion. Please check AWS Console.${NC}"
    exit 1
  fi
else
  echo -e "\n${GREEN}[CANCELLED] Deletion aborted. Your EKS cluster remains safe and active.${NC}"
  exit 0
fi

