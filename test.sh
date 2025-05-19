#!/bin/bash

 COMMAND="$1"

 if [ -z "$COMMAND" ]; then
   swaync-client -t -i face-angry "No command provided!" 😡
   exit 1
 fi

 echo "Executing: $COMMAND"

 # Execute the command
 $COMMAND

 # Check the exit status
 if [ $? -eq 0 ]; then
   swaync-client -t -i face-smile "Command '$COMMAND' executed successfully! 👍"
 else
   swaync-client -t -i face-angry "Command '$COMMAND' failed! 👎"
 fi

 exit 0
