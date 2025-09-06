#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Thakii Lecture2PDF Service Stop Script${NC}"
echo -e "${BLUE}==========================================${NC}"

# Function to kill processes on specific ports
kill_port() {
    local port=$1
    local service_name=$2
    echo -e "${YELLOW}🔍 Stopping $service_name on port $port...${NC}"
    
    local pids=$(lsof -ti :$port 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${RED}🛑 Killing processes: $pids${NC}"
        kill -9 $pids 2>/dev/null || true
        sleep 1
        echo -e "${GREEN}✅ Stopped $service_name${NC}"
    else
        echo -e "${YELLOW}ℹ️  No $service_name running on port $port${NC}"
    fi
}

# Function to kill processes by name
kill_process() {
    local process_name=$1
    local service_name=$2
    echo -e "${YELLOW}🔍 Stopping $service_name processes...${NC}"
    
    local pids=$(pgrep -f "$process_name" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${RED}🛑 Killing $service_name processes: $pids${NC}"
        pkill -f "$process_name" 2>/dev/null || true
        sleep 1
        echo -e "${GREEN}✅ Stopped $service_name${NC}"
    else
        echo -e "${YELLOW}ℹ️  No $service_name processes running${NC}"
    fi
}

echo -e "\n${BLUE}🛑 Stopping all Thakii Lecture2PDF services...${NC}"

# Stop web interface
kill_port 3000 "Web Interface"
kill_port 3001 "Web Interface" 
kill_port 3002 "Web Interface"
kill_port 3003 "Web Interface"
kill_process "vite" "Vite Dev Server"

# Stop backend
kill_port 5001 "Flask Backend"
kill_process "app.py" "Flask Backend"

# Stop worker
kill_process "worker.py" "Worker Process"

# Clean up log files if they exist
echo -e "\n${YELLOW}🧹 Cleaning up log files...${NC}"
cd /Users/oudaykhaled/Desktop/thakii-be/lecture2pdf-service
rm -f backend.log worker.log web-interface.log nohup.out
echo -e "${GREEN}✅ Log files cleaned up${NC}"

echo -e "\n${GREEN}🎉 All services stopped successfully!${NC}"
echo -e "${BLUE}💡 To start services again, run: ./start_all_services.sh${NC}"