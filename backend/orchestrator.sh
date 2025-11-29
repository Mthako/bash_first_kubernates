#!/bin/bash

MCP_URL="http://127.0.0.1:9001/call"

while true; do
  # Listen for one connection, read full HTTP request into variable
  REQUEST=$(ncat -l -p 8000 --keep-open --recv-only)

  # Extract HTTP body (after first empty line)
  BODY=$(echo "$REQUEST" | sed -n '/^\r*$/,$p' | tail -n +2)

  # Extract "user" field value from JSON
  USER_INPUT=$(echo "$BODY" | sed -E 's/.*"user"[ ]*:[ ]*"([^"]*)".*/\1/')

  # Normalize input
  TEXT=$(echo "$USER_INPUT" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')

  RESPONSE=""

  if [[ "$TEXT" == list\ pods* ]]; then
      NS="default"
      if [[ "$TEXT" == *namespace* ]]; then
         NS=$(echo "$TEXT" | awk '{for(i=1;i<=NF;i++) if($i=="namespace") print $(i+1)}')
      fi
      PAYLOAD="{\"tool\":\"list_pods\", \"args\":{\"namespace\":\"$NS\"}}"
      MCP_REPLY=$(curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$MCP_URL")
      RESPONSE="{\"reply\":\"Called MCP list_pods\",\"mcp\":$MCP_REPLY}"

  elif [[ "$TEXT" == scale* ]]; then
      DEPLOY=$(echo "$TEXT" | awk '{print $3}')
      REPL=$(echo "$TEXT" | awk '{print $5}')
      NS="default"
      if [[ "$TEXT" == *namespace* ]]; then
         NS=$(echo "$TEXT" | awk '{for(i=1;i<=NF;i++) if($i=="namespace") print $(i+1)}')
      fi
      PAYLOAD="{\"tool\":\"scale\",\"args\":{\"deployment\":\"$DEPLOY\",\"replicas\":$REPL,\"namespace\":\"$NS\"}}"
      MCP_REPLY=$(curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$MCP_URL")
      RESPONSE="{\"reply\":\"Requested scale $DEPLOY to $REPL\",\"mcp\":$MCP_REPLY}"

  else
      RESPONSE="{\"reply\":\"I didn't understand. Try 'list pods' or 'scale deployment <name> to <N>'\"}"
  fi

  # Send HTTP response headers and body
  {
    echo -e "HTTP/1.1 200 OK\r"
    echo -e "Content-Type: application/json\r"
    echo -e "Content-Length: ${#RESPONSE}\r"
    echo -e "\r"
    echo -e "$RESPONSE"
  } | ncat localhost 8000

done
