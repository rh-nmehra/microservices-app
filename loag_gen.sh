#!/bin/bash

# Configuration
URL="http://your-app-route-url" # Replace with your actual Route
TARGET_TPS=500
DURATION=60 # seconds

echo "Starting load generation: $TARGET_TPS TPS to $URL"
echo "---------------------------------------------------"

# Function to perform a single request and format the output
do_request() {
    # 1. Get Status Code
    # 2. Extract <title> using grep/sed
    # 3. Output in one line
    res=$(curl -s -w "%{http_code}" "$1")
    status="${res: -3}"
    body="${res::-3}"
    title=$(echo "$body" | grep -oP '(?<=<title>).*?(?=</title>)' || echo "No Title")
    
    echo "Status: $status | Title: $title"
}

export -f do_request

# We use GNU Parallel to maintain the rate. 
# -j sets concurrency. To hit 500 TPS, we'll need high concurrency.
seq $((TARGET_TPS * DURATION)) | parallel -j 50 --delay $(bc -l <<< "1/$TARGET_TPS") do_request "$URL" | \
awk -v tps="$TARGET_TPS" '
    BEGIN { start=systime(); count=0 }
    { 
        count++; 
        now=systime();
        elapsed=now-start;
        if (elapsed >= 1) {
            current_tps = count/elapsed;
            printf "\r[LIVE STATS] Current TPS: %.2f | Last %s", current_tps, $0;
        }
    }'
