#!/bin/bash

#==============================================================================
# BLOCKCHAIN UPGRADE TIME ESTIMATOR
#==============================================================================
# This script estimates when a blockchain upgrade will occur based on average
# block production times. It analyzes recent blocks to calculate timing and
# provides fallback endpoints for reliability.
#
# Dependencies: curl, jq, bc, date
# Usage: ./calculate_upgrade_time_blocks.sh
#==============================================================================

# RPC endpoint configuration with fallback system
PRIMARY_RPC="http://127.0.0.1:26657"        # Local node (preferred)
FALLBACK_RPCS=(                              # Remote RPC endpoints as backup
    "https://atomone-testnet-1-rpc.allinbits.services"
)

# REST API endpoints for comparison (currently unused but available)
FALLBACK_APIS=(
    "https://atomone-testnet-1-api.allinbits.services"
)

# Target block height for the network upgrade
UPGRADE_HEIGHT=3240000

#==============================================================================
# ENDPOINT CONNECTIVITY FUNCTIONS
#==============================================================================

# Test if an RPC endpoint is responsive and accessible
# Args: $1 - endpoint URL to test
# Returns: 0 if accessible, 1 if not
test_endpoint() {
    local endpoint=$1
    local timeout=5
    
    # Try to fetch the latest block with a timeout
    # Redirect output to /dev/null to avoid cluttering the terminal
    if curl -s --max-time $timeout "${endpoint}/block" > /dev/null 2>&1; then
        return 0  # Success
    else
        return 1  # Failed
    fi
}

# Find the best available RPC endpoint from our list
# Tries local first, then fallbacks in order
# Returns: URL of the first working endpoint
find_best_rpc() {
    # Test the primary local RPC endpoint first
    if test_endpoint "$PRIMARY_RPC"; then
        echo "$PRIMARY_RPC" >&2    # Log to stderr (for user info)
        echo "$PRIMARY_RPC"        # Return to stdout (for variable assignment)
        return 0
    fi
    
    # If local RPC is not available, try remote fallbacks
    echo "Local RPC not available, trying fallbacks..." >&2
    
    # Iterate through each fallback RPC endpoint
    for rpc in "${FALLBACK_RPCS[@]}"; do
        echo "Testing $rpc..." >&2
        if test_endpoint "$rpc"; then
            echo "Using fallback RPC: $rpc" >&2
            echo "$rpc"            # Return the working endpoint
            return 0
        fi
    done
    
    # If no endpoints work, exit with error
    echo "Error: No available RPC endpoint found!" >&2
    exit 1
}

#==============================================================================
# DATA FETCHING FUNCTIONS
#==============================================================================

# Safely fetch data from an API endpoint with retry logic
# Args: $1 - URL to fetch
# Returns: JSON response on success, error message on failure
safe_curl() {
    local url=$1
    local max_retries=3        # Maximum number of retry attempts
    local retry=0
    
    # Retry loop for handling temporary network issues
    while [ $retry -lt $max_retries ]; do
        # Attempt to fetch data with 10-second timeout
        local response=$(curl -s --max-time 10 "$url")
        
        # Check if curl succeeded AND if response is valid JSON
        if [ $? -eq 0 ] && echo "$response" | jq . > /dev/null 2>&1; then
            echo "$response"       # Return successful response
            return 0
        fi
        
        # Increment retry counter and wait before next attempt
        retry=$((retry + 1))
        echo "Retry $retry/$max_retries for $url" >&2
        sleep 2                    # Wait 2 seconds between retries
    done
    
    # All retries failed
    echo "Error: Failed to fetch data from $url after $max_retries retries" >&2
    return 1
}

#==============================================================================
# TIMESTAMP PROCESSING FUNCTIONS
#==============================================================================

# Convert blockchain timestamp to Unix timestamp
# Handles both GNU date (Linux) and BSD date (macOS) formats
# Args: $1 - ISO timestamp from blockchain (e.g., "2024-01-15T10:30:45.123456789Z")
# Returns: Unix timestamp (seconds since epoch)
to_unix_timestamp() {
    local timestamp=$1
    
    # Remove microseconds from timestamp, keep only up to seconds
    # This handles the precision difference between blockchain and system timestamps
    local clean_timestamp=$(echo "$timestamp" | sed 's/\.[0-9]*Z$/Z/')
    
    # Detect which date command we're using (GNU vs BSD)
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux) - uses -d flag for input parsing
        date -d "$clean_timestamp" +%s 2>/dev/null
    else
        # BSD date (macOS) - uses -j flag and explicit format
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$clean_timestamp" +%s 2>/dev/null
    fi
}

#==============================================================================
# MAIN EXECUTION STARTS HERE
#==============================================================================

# Find and establish connection to the best available RPC endpoint
RPC_URL=$(find_best_rpc)
echo "Using RPC: $RPC_URL"
echo "----------------------------------------"

#==============================================================================
# DYNAMIC RANGE CALCULATION CONFIGURATION
#==============================================================================

# Configuration parameters for calculating the optimal analysis range
TARGET_HOURS=24                # Analyze blocks from the last 24 hours
MIN_RANGE=1000                 # Minimum number of blocks to analyze (safety limit)
MAX_RANGE=50000                # Maximum number of blocks to analyze (performance limit)

# Calculate the optimal number of blocks to analyze (RANGE) dynamically
# This replaces the fixed RANGE=10000 with a time-based calculation
# Returns: Number of blocks representing approximately TARGET_HOURS of blockchain history
calculate_dynamic_range() {
    echo "Calculating dynamic RANGE for last ${TARGET_HOURS} hours..." >&2
    
    # Get the current (latest) block information
    local current_response=$(safe_curl "${RPC_URL}/block")
    if [ $? -ne 0 ]; then
        echo "Failed to get current block" >&2
        echo "$MIN_RANGE"          # Return minimum range as fallback
        return 1
    fi
    
    # Extract current block height and timestamp
    local current_height=$(echo "$current_response" | jq -r '.result.block.header.height')
    local current_time=$(echo "$current_response" | jq -r '.result.block.header.time')
    
    # Validate that we got valid data (not null)
    if [ "$current_height" == "null" ] || [ "$current_time" == "null" ]; then
        echo "Invalid response format" >&2
        echo "$MIN_RANGE"
        return 1
    fi
    
    # Use a sample of recent blocks to estimate average block time
    local sample_size=200         # Number of blocks to sample for time estimation
    local sample_height=$((current_height - sample_size))
    
    # Get the sample block information
    local sample_response=$(safe_curl "${RPC_URL}/block?height=${sample_height}")
    if [ $? -ne 0 ]; then
        echo "Failed to get sample block" >&2
        echo "$MIN_RANGE"
        return 1
    fi
    
    # Extract timestamp from the sample block
    local sample_time=$(echo "$sample_response" | jq -r '.result.block.header.time')
    
    # Validate sample data
    if [ "$sample_time" == "null" ]; then
        echo "Invalid sample response format" >&2
        echo "$MIN_RANGE"
        return 1
    fi
    
    # Convert blockchain timestamps to Unix timestamps
    local current_unix=$(to_unix_timestamp "$current_time")
    local sample_unix=$(to_unix_timestamp "$sample_time")
    
    # Check if timestamp conversion was successful
    if [ -z "$current_unix" ] || [ -z "$sample_unix" ]; then
        echo "Failed to parse timestamps" >&2
        echo "$MIN_RANGE"
        return 1
    fi
    
    # Calculate average block production time
    local time_diff=$((current_unix - sample_unix))          # Total seconds elapsed
    local avg_block_time=$(echo "scale=3; $time_diff / $sample_size" | bc -l)  # Seconds per block
    
    echo "Estimated avg block time from sample: ${avg_block_time}sec" >&2
    
    # Calculate how many blocks represent our target time period
    local target_seconds=$((TARGET_HOURS * 3600))            # Convert hours to seconds
    local calculated_range=$(echo "scale=0; $target_seconds / $avg_block_time" | bc -l)  # Blocks needed
    
    # Apply safety limits to the calculated range
    local final_range
    if (( $(echo "$calculated_range < $MIN_RANGE" | bc -l) )); then
        # Use minimum if calculated range is too small
        final_range=$MIN_RANGE
        echo "Using minimum range: $final_range" >&2
    elif (( $(echo "$calculated_range > $MAX_RANGE" | bc -l) )); then
        # Use maximum if calculated range is too large  
        final_range=$MAX_RANGE
        echo "Using maximum range: $final_range" >&2
    else
        # Use calculated range (rounded to integer)
        final_range=$(echo "scale=0; $calculated_range/1" | bc -l)
        echo "Using calculated range: $final_range" >&2
    fi
    
    echo "$final_range"           # Return the final range value
}

#==============================================================================
# CALCULATE DYNAMIC RANGE
#==============================================================================

# Calculate the optimal number of blocks to analyze
RANGE=$(calculate_dynamic_range)
echo "Dynamic RANGE set to: $RANGE blocks"
echo "----------------------------------------"

#==============================================================================
# COLLECT BLOCKCHAIN DATA FOR ANALYSIS
#==============================================================================

# Fetch current block information (this is our endpoint for analysis)
current_response=$(safe_curl "${RPC_URL}/block")
if [ $? -ne 0 ]; then
    echo "Failed to get current block data"
    exit 1
fi

# Extract current block details
current_height=$(echo "$current_response" | jq -r '.result.block.header.height')
current_datetime=$(echo "$current_response" | jq -r '.result.block.header.time')

# Validate current block data
if [ "$current_height" == "null" ] || [ "$current_datetime" == "null" ]; then
    echo "Invalid current block data"
    exit 1
fi

# Convert current block timestamp to Unix format
current_unixtime=$(to_unix_timestamp "$current_datetime")

# Calculate the starting block height for our analysis range
start_height=$((current_height - RANGE))

# Fetch the starting block information (this is our starting point for analysis)
start_response=$(safe_curl "${RPC_URL}/block?height=${start_height}")
if [ $? -ne 0 ]; then
    echo "Failed to get start block data"
    exit 1
fi

# Extract starting block timestamp
start_datetime=$(echo "$start_response" | jq -r '.result.block.header.time')
if [ "$start_datetime" == "null" ]; then
    echo "Invalid start block data"
    exit 1
fi

# Convert starting block timestamp to Unix format
start_unixtime=$(to_unix_timestamp "$start_datetime")

# Validate that we have both timestamps
if [ -z "$current_unixtime" ] || [ -z "$start_unixtime" ]; then
    echo "Failed to parse block timestamps"
    exit 1
fi

#==============================================================================
# CALCULATE AVERAGE BLOCK TIME AND UPGRADE ESTIMATES
#==============================================================================

# Calculate the total time elapsed over our analysis range
time_diff=$((current_unixtime - start_unixtime))

# Calculate average block production time over the full range
avg=$(echo "scale=3; $time_diff / $RANGE" | bc -l)

echo "Average block time for ${RANGE} blocks range (${start_height} - ${current_height}) is ${avg}sec"

# Calculate how many blocks remain until the upgrade
blocks_to_update=$((UPGRADE_HEIGHT - current_height))

# Estimate how many seconds until the upgrade (blocks remaining * average time per block)
seconds_to_update=$(echo "scale=0; ${blocks_to_update} * ${avg}" | bc -l)

# Display the estimated time remaining in human-readable format
echo "Estimated time to upgrade at ${UPGRADE_HEIGHT} (based on $RANGE blocks) is:" 
eval "echo $(date -ud "@$seconds_to_update" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')"

# Display the estimated date and time when the upgrade will occur
echo "Estimated upgrade block time is:" 
date --date="+${seconds_to_update} seconds" '+%d %b %Y %T'

#==============================================================================
# FETCH ADDITIONAL NETWORK INFORMATION
#==============================================================================

# Try to get network information for context
network_response=$(safe_curl "${RPC_URL}/status")
if [ $? -eq 0 ]; then
    # Extract network name/chain-id
    network_info=$(echo "$network_response" | jq -r '.result.node_info.network')
    echo "Network: $network_info"
else
    echo "Network: Unable to fetch"
fi

#==============================================================================
# SUMMARY OUTPUT
#==============================================================================

echo "----------------------------------------"
echo "Endpoint used: $RPC_URL"

#==============================================================================
# SCRIPT END
#==============================================================================