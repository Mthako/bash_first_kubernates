#!/bin/bash
set -x 
# Read the entire HTTP request from stdin into REQUEST
REQUEST=$(cat)

# Extract body after blank line
BODY=$(echo "$REQUEST" | sed -n '/^\r*$/,$p' | tail -n +2)

# Extract "user" value from JSON body
USER_INPUT=$(echo "$BODY" | sed -E 's/.*"user"[ ]*:[ ]*"([^"]*)".*/\1/')

# Lowercase and trim
TEXT=$(echo "$USER_INPUT" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')

RESPONSE=""

if [[ "$TEXT" == list\ pods* ]]; then
  RESPONSE='{"reply":"You requested list pods"}'
elif [[ "$TEXT" == scale* ]]; then
  RESPONSE='{"reply":"You requested scale"}'
else
  RESPONSE='{"reply":"Command not understood"}'
fi

# Send HTTP response headers and body
echo -e "HTTP/1.1 200 OK\r"
echo -e "Content-Type: application/json\r"
echo -e "Content-Length: ${#RESPONSE}\r"
echo -e "\r"
echo -e "$RESPONSE"
