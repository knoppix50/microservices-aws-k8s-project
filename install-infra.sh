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
# CLUSTER CREATION
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
echo -e "${GREEN}[OK] EKS Cluster created.Stabilizing components....${NC}\n"

# Short security pause to sync local credentials
sleep 120

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}    INFRASTRUCTURE DEPLOYED SUCCESSFULLY  ${NC}"
echo -e "${GREEN}         Cluster status: Active & Ready. ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${YELLOW}You can now run your ./deploy.sh script to boot the apps.${NC}"





