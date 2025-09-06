#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Thakii Lecture2PDF Service Startup Script${NC}"
echo -e "${BLUE}============================================${NC}"

# Function to kill processes on specific ports
kill_port() {
    local port=$1
    local service_name=$2
    echo -e "${YELLOW}🔍 Checking for existing processes on port $port ($service_name)...${NC}"
    
    # Find and kill processes using the port
    local pids=$(lsof -ti :$port 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${RED}🛑 Killing existing processes on port $port: $pids${NC}"
        kill -9 $pids 2>/dev/null || true
        sleep 2
    else
        echo -e "${GREEN}✅ Port $port is free${NC}"
    fi
}

# Function to kill processes by name
kill_process() {
    local process_name=$1
    local service_name=$2
    echo -e "${YELLOW}🔍 Checking for existing $service_name processes...${NC}"
    
    # Find and kill processes by name
    local pids=$(pgrep -f "$process_name" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${RED}🛑 Killing existing $service_name processes: $pids${NC}"
        pkill -f "$process_name" 2>/dev/null || true
        sleep 2
    else
        echo -e "${GREEN}✅ No existing $service_name processes found${NC}"
    fi
}

# Get script directory and change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

echo -e "\n${YELLOW}📍 Current directory: $(pwd)${NC}"

# Step 1: Stop all existing services
echo -e "\n${BLUE}🛑 STEP 1: Stopping existing services...${NC}"
kill_port 5001 "Flask Backend"
kill_port 5173 "Web Interface (Vite)"
kill_port 3000 "Web Interface"
kill_port 3001 "Web Interface"
kill_port 3002 "Web Interface"
kill_process "worker.py" "Worker Process"
kill_process "vite" "Vite Dev Server"

# Step 2: Find the correct lecture2pdf path
echo -e "\n${BLUE}🔍 STEP 2: Finding lecture2pdf repository...${NC}"
LECTURE2PDF_PATHS=(
    "/Users/oudaykhaled/Desktop/development/playground/Lecture-Video-to-PDF"
    "$PROJECT_ROOT/backend/lecture2pdf-external"
    "$PROJECT_ROOT/lecture2pdf-external"
    "/Users/oudaykhaled/Desktop/thakii-be/Lecture-Video-to-PDF"
    "/Users/oudaykhaled/Desktop/Lecture-Video-to-PDF"
)

LECTURE2PDF_PATH=""
for path in "${LECTURE2PDF_PATHS[@]}"; do
    if [ -d "$path" ]; then
        LECTURE2PDF_PATH="$path"
        echo -e "${GREEN}✅ Found lecture2pdf at: $path${NC}"
        break
    fi
done

if [ -z "$LECTURE2PDF_PATH" ]; then
    echo -e "${RED}❌ Could not find lecture2pdf repository in any of the expected locations${NC}"
    echo -e "${YELLOW}📋 Please clone https://github.com/oudaykhaled/Lecture-Video-to-PDF${NC}"
    exit 1
fi

# Step 3: Set environment variables
echo -e "\n${BLUE}⚙️ STEP 3: Setting up environment variables...${NC}"
export S3_BUCKET_NAME="thakii-video-storage-1753883631"
export AWS_DEFAULT_REGION="us-east-2"
export LECTURE2PDF_PATH="$LECTURE2PDF_PATH"
export GOOGLE_APPLICATION_CREDENTIALS="$PROJECT_ROOT/backend/firebase/firebase-service-account.json"

echo -e "${GREEN}✅ Environment variables set:${NC}"
echo -e "   S3_BUCKET_NAME: $S3_BUCKET_NAME"
echo -e "   AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
echo -e "   LECTURE2PDF_PATH: $LECTURE2PDF_PATH"
echo -e "   GOOGLE_APPLICATION_CREDENTIALS: $GOOGLE_APPLICATION_CREDENTIALS"

# Step 4: Set up Backend
echo -e "\n${BLUE}🐍 STEP 4: Setting up Backend...${NC}"
cd backend

# Check for virtual environment
if [ -d ".venv" ]; then
    echo -e "${GREEN}✅ Found existing virtual environment${NC}"
    source .venv/bin/activate
elif [ -d "venv" ]; then
    echo -e "${GREEN}✅ Found existing virtual environment${NC}"
    source venv/bin/activate
else
    echo -e "${YELLOW}⚠️ Creating new virtual environment...${NC}"
    python3 -m venv .venv
    source .venv/bin/activate
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi
fi

echo -e "${GREEN}✅ Python virtual environment activated${NC}"
echo -e "   Python: $(which python)"

# Step 5: Start Backend Service
echo -e "\n${BLUE}🖥️ STEP 5: Starting Flask Backend Service...${NC}"
echo -e "${YELLOW}📍 Starting backend on port 5001...${NC}"
export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"
nohup python api/app.py > ../backend.log 2>&1 &
BACKEND_PID=$!
sleep 3

# Check if backend started successfully
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}✅ Backend service started successfully (PID: $BACKEND_PID)${NC}"
else
    echo -e "${RED}❌ Backend service failed to start${NC}"
    echo -e "${YELLOW}📋 Check backend.log for details${NC}"
    tail -10 ../backend.log
    exit 1
fi

# Step 6: Start Worker Process
echo -e "\n${BLUE}⚙️ STEP 6: Starting Worker Process...${NC}"
nohup python worker/worker.py > ../worker.log 2>&1 &
WORKER_PID=$!
sleep 2

if ps -p $WORKER_PID > /dev/null; then
    echo -e "${GREEN}✅ Worker process started successfully (PID: $WORKER_PID)${NC}"
else
    echo -e "${RED}❌ Worker process failed to start${NC}"
    echo -e "${YELLOW}📋 Check worker.log for details${NC}"
    tail -10 ../worker.log
fi

# Step 7: Start Web Interface
echo -e "\n${BLUE}🌐 STEP 7: Starting Web Interface...${NC}"
cd ../web

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}📦 Installing web interface dependencies...${NC}"
    npm install
fi

echo -e "${YELLOW}📍 Starting web interface on port 5173...${NC}"
nohup npm run dev > ../web-interface.log 2>&1 &
WEB_PID=$!
sleep 5

# Check if web interface started (Vite usually picks port 3000 if 5173 is unavailable)
WEB_PORT=""
for port in 3000 5173 3001 3002; do
    if curl -s "http://localhost:$port/" > /dev/null 2>&1; then
        WEB_PORT=$port
        echo -e "${GREEN}✅ Web interface started successfully on port $WEB_PORT (PID: $WEB_PID)${NC}"
        break
    fi
done

if [ -z "$WEB_PORT" ]; then
    echo -e "${RED}❌ Web interface failed to start${NC}"
    echo -e "${YELLOW}📋 Check web-interface.log for details${NC}"
    tail -10 ../web-interface.log
fi

# Step 8: Display final status
cd ..
echo -e "\n${BLUE}📊 FINAL STATUS${NC}"
echo -e "${BLUE}===============${NC}"

# Backend status
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}🖥️  Backend Service: ✅ Running on http://localhost:5001${NC}"
else
    echo -e "${RED}🖥️  Backend Service: ❌ Not responding${NC}"
fi

# Worker status
if ps -p $WORKER_PID > /dev/null 2>/dev/null; then
    echo -e "${GREEN}⚙️  Worker Process: ✅ Running (PID: $WORKER_PID)${NC}"
else
    echo -e "${RED}⚙️  Worker Process: ❌ Not running${NC}"
fi

# Web interface status
if [ -n "$WEB_PORT" ]; then
    echo -e "${GREEN}🌐 Web Interface: ✅ Running on http://localhost:$WEB_PORT${NC}"
else
    echo -e "${RED}🌐 Web Interface: ❌ Not running${NC}"
fi

echo -e "\n${BLUE}🔗 QUICK LINKS${NC}"
echo -e "${BLUE}==============${NC}"
if [ -n "$WEB_PORT" ]; then
    echo -e "${GREEN}🌐 Web Interface: http://localhost:$WEB_PORT${NC}"
fi
echo -e "${GREEN}🖥️  Backend API: http://localhost:5001${NC}"
echo -e "${GREEN}❤️  Health Check: http://localhost:5001/health${NC}"

echo -e "\n${BLUE}📋 LOG FILES${NC}"
echo -e "${BLUE}============${NC}"
echo -e "📄 Backend: backend.log"
echo -e "📄 Worker: worker.log"
echo -e "📄 Web Interface: web-interface.log"

echo -e "\n${BLUE}🛑 TO STOP ALL SERVICES${NC}"
echo -e "${BLUE}========================${NC}"
echo -e "Run: ${YELLOW}./backend/scripts/stop_all_services.sh${NC}"

echo -e "\n${GREEN}🎉 All services started successfully!${NC}"
