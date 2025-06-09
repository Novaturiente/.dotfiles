#!/bin/bash

# Initial content (empty array to start with)
contents="[]"

# Loop to keep asking for input and sending the request
while true; do
    # Ask the user for a question
    echo ">>"
    
    # Initialize an empty variable to collect the multiline input
    QUESTION=""
    
    # Read multiple lines until user presses Ctrl+D
    while IFS= read -r line; do
        # Append each line to the QUESTION variable
        QUESTION+="$line"$'\n'
    done
    
    echo  # Just for formatting

    # Append the user's question to the content before sending the request
    contents=$(echo "$contents" | jq --arg question "$QUESTION" \
      '. + [{"role": "user", "parts": [{"text": $question}]}]')

    # Perform the API request with the current content
    response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
      -H 'Content-Type: application/json' \
      -d '{
        "system_instruction": {
          "parts": [
            {
              "text": "You are Robin assistant of Batman. Always provide direct responses."
            }
          ]
        },
        "contents": '"$contents"'
      }')

    # Extract the model's response from the API
    content_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text')

    # Print the model's response
    echo "$content_text"
    echo

    # Append the model's response to the content after receiving the response
    contents=$(echo "$contents" | jq --arg response "$content_text" \
      '. + [{"role": "model", "parts": [{"text": $response}]}]')

done
