#!/bin/bash
# =============================================================================
# REStake Monitoring Script with Telegram Notifications
# by AviaOne.com
# =============================================================================
# This script monitors REStake autostaking operations by parsing live output
# from npm run autostake and sends formatted reports via Telegram.
#
# Key Features:
# - Parses modern REStake JSON logs in real-time
# - Displays accurate token balances (including fee tokens like PHOTON)
# - Handles both 6-decimal and 18-decimal blockchain denominations
# - Sends formatted HTML reports to Telegram with status summaries
# - Tracks delegator counts and transaction outcomes
#
# Author: Enhanced version for modern REStake JSON log parsing
# =============================================================================
# Get script directory and name for relative path resolution
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_NAME=$(basename "$BASH_SOURCE")
# =============================================================================
# CONFIGURATION LOADING
# =============================================================================
# Load configuration variables from .ini file with same name as script
# Format: KEY=VALUE (one per line, no spaces around =)
IFS="="
while read -r name value || [[ $name && $value ]]; 
do
  if [[ -n "${name}" && "${name}" != [[:blank:]#]* ]]; then
    eval ${name}="${value}"
  fi
done < $SCRIPT_DIR/${SCRIPT_NAME%.*}.ini
# Parse ETH_CHAINS configuration into array for 18-decimal blockchain detection
# ETH_CHAINS should contain blockchain names that use 18 decimal places
# Example: ETH_CHAINS="Dymension Fetch.ai"
IFS=" " read -a ethChainsArray <<< $ETH_CHAINS
# =============================================================================
# FILE SETUP
# =============================================================================
# Initialize output files for state tracking and message formatting
FILE_STATE=$SCRIPT_DIR/restake_state.txt      # Stores chain:delegator_count pairs
FILE_MESSAGE=$SCRIPT_DIR/restake_message.txt  # Stores formatted Telegram message
# Clean previous state and initialize message with header
rm -f $FILE_STATE
echo -e "\xF0\x9F\x93\xAB <b>RESTAKE</b> | $(date +'%a %d %b %Y %T %Z')\n" > $FILE_MESSAGE
# =============================================================================
# MAIN PROCESSING LOOP
# =============================================================================
# Execute REStake and process output line by line in real-time
# This replaces the original journalctl approach with direct npm execution
# =============================================================================
# IF Restake is working directly with NPM
# =============================================================================
cd restake
npm run autostake |
# =============================================================================
# IF Restake is working with SERVICES  /etc/systemd/system
# journalctl -u restake --since today -o cat --no-pager |
# =============================================================================
while IFS="" read -r line || [ -n "$line" ]
do
  # Clean timestamp from beginning of each log line
  # REStake logs format: [timestamp] level: message
  line=$(awk '{$1=""}1' <<< $line)
  line="${line:1}"
  # =============================================================================
  # CHAIN LOADING DETECTION
  # =============================================================================
  # Detect when REStake loads a new blockchain
  # Modern REStake logs: "Loaded chain chain=chainname module=autostake prettyName=DisplayName"
  if grep -q "Loaded chain" <<< "$line" && [ -z "${ATTEMPT}" ]; then
    ATTEMPT=1                    # Initialize attempt counter for this chain
    TX=""                        # Reset transaction status
    DELEGATORS_CALCULATED=0      # Reset delegator calculation flag
    
    # Extract pretty name from log line (this is the display name we want)
    # Example: "Loaded chain chain=atomone prettyName=AtomOne" -> "AtomOne"
    CHAIN=$(echo "$line" | sed -n 's/.*prettyName=\([^ ]*\).*/\1/p')
    
    # Store chain name for state summary
    echo -n "${CHAIN}:," >> $FILE_STATE
    
    # Add formatted chain header to message
    echo -e "\nLoaded <b>${CHAIN}</b>" >> $FILE_MESSAGE
    continue
  fi
  # =============================================================================
  # OPERATOR STATUS CHECK
  # =============================================================================
  # Handle case where bot is not registered as operator for this chain
  if grep -q "Not an operator" <<< "$line" && (( ATTEMPT == 1 )); then
    echo "-" >> $FILE_STATE
    echo "${line}" >> $FILE_MESSAGE
    continue
  fi
  # =============================================================================
  # BALANCE PARSING AND CALCULATION
  # =============================================================================
  # Parse the bot's balance from REStake logs
  # Modern REStake logs: "Fetched bot balance chain=X module=network_runner denom=TOKEN amount=NUMBER"
  if grep -q "Fetched bot balance" <<< "$line" && (( ATTEMPT == 1 )); then
    
    # Determine denomination divisor based on blockchain type
    # Default: 6 decimals (1,000,000) for most Cosmos chains
    # ETH-type: 18 decimals (1,000,000,000,000,000,000) for Ethereum-like chains
    denom=1000000  
    for ethchain in ${ethChainsArray[@]}; do
      # Case-insensitive comparison to match chain names
      # Also check partial matches for flexibility
      if [[ "${CHAIN,,}" == "${ethchain,,}" ]] || [[ "${CHAIN,,}" == *"${ethchain,,}"* ]]; then
        denom=1000000000000000000  # 18 decimal places
      fi
    done
    
    # Extract raw amount and token denomination from log line
    # Example: "denom=uphoton amount=48466853" -> amount=48466853, token_denom=uphoton
    amount=$(echo "$line" | sed -n 's/.*amount=\([0-9]*\).*/\1/p')
    token_denom=$(echo "$line" | sed -n 's/.*denom=\([^ ]*\).*/\1/p')
    
    # Calculate human-readable balance using the proven awk method
    # This approach handles very large numbers without scientific notation
    balance=$(awk -v amount="$amount" -v denom="$denom" 'BEGIN{print amount/denom}')
    
    # Convert raw denomination to display token name
    # Remove common prefixes and convert to uppercase
    # Examples: uphoton -> PHOTON, uatone -> ATONE, adym -> DYM, afet -> FET
    if [[ "$token_denom" == u* ]]; then
      # Remove 'u' prefix (common in Cosmos ecosystem)
      token="${token_denom#u}"
      token="${token^^}"  # Convert to uppercase
    else
      # For tokens like 'adym' or 'afet', remove first letter
      token="${token_denom#?}"
      token="${token^^}"  # Convert to uppercase
    fi
    
    # Check if balance is below alert threshold
    alert=""
    if (( ${balance%.*} < BALANCE_ALERT )); then
      alert="\xE2\x9A\xA0"  # Warning emoji for low balance
    fi
    
    # Add formatted balance line to message
    echo -e "Bot balance is <b>$balance $token</b> $alert" >> $FILE_MESSAGE
    continue
  fi
  # =============================================================================
  # DELEGATOR COUNT TRACKING
  # =============================================================================
  # Parse number of addresses with valid grants
  # Modern REStake logs: "Found addresses with valid grants... count=NUMBER"
  if grep -q "Found addresses with valid grants" <<< "$line" && (( DELEGATORS_CALCULATED == 0 )); then
    # Extract delegator count from log line
    DELEGATORS=$(echo "$line" | sed -n 's/.*count=\([0-9]*\).*/\1/p')
    
    # Store count in state file and add to message
    echo "${DELEGATORS} delegators" >> $FILE_STATE
    echo "Found ${DELEGATORS} addresses with valid grants..." >> $FILE_MESSAGE
    DELEGATORS_CALCULATED=1  # Mark as calculated to avoid duplicates
    continue
  fi
  # =============================================================================
  # OPERATION STATUS TRACKING AND ALERTS SIMPLIFIED
  # =============================================================================
  # Ignore verbose detailed failed attempts and retries
  if grep -q "Failed attempt" <<< "$line" ; then
    ATTEMPT=2
    # Do not add detailed retry info to message, ignore
    continue
  fi
  
  # Show concise success message with attempts count
  if grep -q "Autostake completed" <<< "$line" ; then
    attempts=${ATTEMPT:-1}
    echo "Autostake completed after ${attempts} attempt(s)" >> $FILE_MESSAGE
    continue
  fi
  
  # Final finish status with green dot alert
  if grep -q "Autostake finished" <<< "$line" ; then
    ATTEMPT=""
    echo -e "Autostake finished" >> $FILE_MESSAGE
    echo -e "\xF0\x9F\x9F\xA2 Autostake <b>${CHAIN}</b> finished" >> $FILE_MESSAGE  # 🟢
    continue
  fi
  
  # Ignore detailed autostake failed after retry messages
  if grep -q "Autostake failed after" <<< "$line" ; then
    continue
  fi
  
  # Critical failure with red alert
  if grep -q "Autostake failed" <<< "$line" ; then  
    ATTEMPT=""
    echo -e "\xF0\x9F\x94\xB4 Autostake <b>${CHAIN}</b> failed" >> $FILE_MESSAGE  # 🔴
    continue
  fi
   
  # =============================================================================
  # ERROR HANDLING
  # =============================================================================
  # Handle specific transaction failures and errors
  # Transaction failure with details
  if grep -q "TX 1: Failed" <<< "$line" && [ -z "${TX}" ]; then
    TX=1  # Mark transaction as processed
    echo "${line}" | awk -F ';' '{print "<pre>"substr($2,2),$3"</pre>"}' >> $FILE_MESSAGE
    continue
  fi
  # Generic error with cleanup (remove ANSI color codes)
  if grep -q "Failed with error" <<< "$line" && [ -z "${TX}" ]; then
    TX=1  # Mark transaction as processed
    # Clean up error message by removing ANSI color codes for cleaner Telegram display
    clean_line=$(echo "$line" | sed 's/\[[0-9;]*m//g')
    echo "Failed with error: ${clean_line#*Failed with error: }" >> $FILE_MESSAGE
    continue
  fi
  # Clean up specific retry messages that contain ANSI codes
  if grep -q "Failed attempt.*retrying in.*seconds" <<< "$line"; then
    clean_line=$(echo "$line" | sed 's/\[[0-9;]*m//g')
    echo "$clean_line" >> $FILE_MESSAGE
    continue
  fi
done 
# =============================================================================
# FINAL LOG CLEANUP
# =============================================================================
# Remove any remaining ANSI color codes from the final message file
# This catches any lines that slipped through the filtering process
sed -i 's/\[[0-9;]*m//g' $FILE_MESSAGE 
# =============================================================================
# MESSAGE FINALIZATION AND DELIVERY
# =============================================================================
# Compile final message and send via Telegram
# Read the accumulated message content
MESSAGE=$(cat $FILE_MESSAGE)
# Add state summary table if chains were processed
if [ -f $FILE_STATE ]; then
  # Format state data as aligned table using column command
  # This creates a neat summary: "ChainName: DelegatorCount delegators"
  MESSAGE+=$'\n\n'"<pre>"$(cat $FILE_STATE | column -s "," -t)"</pre>"
else
  # No chains processed - likely an error condition
  MESSAGE+=$(echo -e "\n\n\xF0\x9F\x94\xB4 No logs since today ")
fi
# Send message to Telegram if token is configured
if [ -n "${TG_TOKEN}" ]; then
  # Send formatted HTML message to specified Telegram chat
  # Uses Telegram Bot API with HTML parsing for rich formatting
  curl -s --data "text=${MESSAGE}" \
       --data "chat_id=${TG_CHAT_ID}" \
       --data "parse_mode=html" \
       'https://api.telegram.org/bot'${TG_TOKEN}'/sendMessage' > /dev/null
fi
# =============================================================================
# CONFIGURATION REFERENCE
# =============================================================================
# Required .ini file variables:
# TG_TOKEN=your_telegram_bot_token
# TG_CHAT_ID=your_telegram_chat_id  
# BALANCE_ALERT=minimum_balance_threshold
# ETH_CHAINS="Chain1 Chain2"  # Chains using 18 decimal places
#
# Example .ini file:
# TG_TOKEN=123456789:ABCDEF...
# TG_CHAT_ID=-100123456789
# BALANCE_ALERT=1
# ETH_CHAINS="Dymension Fetch.ai"
# =============================================================================
