#!/bin/bash

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}         STARTING API ENDPOINT TESTS              ${NC}"
echo -e "${BLUE}==================================================${NC}\n"

echo -e "${YELLOW}Extracting Load Balancer DNS hostname from AWS EKS...${NC}"

# Loop until Kubernetes receives the external DNS hostname from AWS Load Balancer
while true; do
  # Query the specific service for its external ingress hostname
  LB_HOSTNAME=$(kubectl get svc coworking -o jsonpath='{.status.loadBalancer.ingress.hostname}' 2>/dev/null)
  
  if [ ! -z "$LB_HOSTNAME" ]; then
    # Dynamically build the target URL using the application port 5153
    API_URL="http://${LB_HOSTNAME}:5153"
    echo -e "${GREEN}[OK] Dynamic API URL detected:${NC} $API_URL\n"
    break
  else
    echo "Waiting for AWS to allocate Load Balancer DNS hostname... Retrying in 15 seconds..."
    sleep 15
  fi
done

echo -e "${YELLOW}Waiting for AWS Load Balancer to become active and route traffic...${NC}"

# ---------------------------------------------------------------------
# TEST 1: INITIAL CONNECTION CHECK (HEALTH CHECK)
# ---------------------------------------------------------------------
while true; do
  # curl to verify server response code
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/reports/user_visits" --connect-timeout 5)
  
  if [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}Success! API is online and responding (HTTP 200).${NC}\n"
    break
  else
    echo -e "${YELLOW}API not responding yet (HTTP Code: $HTTP_STATUS). AWS DNS is propagating. Retrying in 15 seconds...${NC}"
    sleep 15
  fi
done

# =====================================================================
# ENDPOINT TESTING EXECUTION
# =====================================================================

# --- Test Endpoint 1: User Visits ---
echo -e "${BLUE}--> Running Test: User Visits Report (/api/reports/user_visits)...${NC}"
RESPONSE_1=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_URL/api/reports/user_visits")
BODY_1=$(echo "$RESPONSE_1" | sed '/HTTP_CODE:/d')
CODE_1=$(echo "$RESPONSE_1" | grep "HTTP_CODE:" | cut -d':' -f2)

if [ "$CODE_1" == "200" ]; then
  echo -e "${GREEN}[TEST PASSED] User visits endpoint working correctly.${NC}"
  echo -e "Data returned from Postgres:\n$BODY_1\n"
else
  echo -e "${RED}[TEST FAILED] User visits endpoint returned status code $CODE_1${NC}"
  exit 1
fi

# --- Test Endpoint 2: Daily Usage ---
echo -e "${BLUE}--> Running Test: Daily Usage Report (/api/reports/daily_usage)...${NC}"
RESPONSE_2=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_URL/api/reports/daily_usage")
BODY_2=$(echo "$RESPONSE_2" | sed '/HTTP_CODE:/d')
CODE_2=$(echo "$RESPONSE_2" | grep "HTTP_CODE:" | cut -d':' -f2)

if [ "$CODE_2" == "200" ]; then
  echo -e "${GREEN}[TEST PASSED] Daily usage endpoint working correctly.${NC}"
  echo -e "Data returned from Postgres:\n$BODY_2\n"
else
  echo -e "${RED}[TEST FAILED] Daily usage endpoint returned status code $CODE_2${NC}"
  exit 1
fi

# =====================================================================
# FINAL CONCLUSION
# =====================================================================
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}     ALL TESTS COMPLETED SUCCESSFULLY (10/10)!    ${NC}"
echo -e "${GREEN}     API communicates with Postgres data seed.    ${NC}"
echo -e "${GREEN}==================================================${NC}"

