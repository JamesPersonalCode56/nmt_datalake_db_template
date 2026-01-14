#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file missing."
    exit 1
fi

STATUS=$(docker inspect -f '{{.State.Running}}' $DB_CONTAINER_NAME 2>/dev/null)

if [ "$STATUS" == "true" ]; then
    echo "Container $DB_CONTAINER_NAME is already running."
else
    echo "Container $DB_CONTAINER_NAME is down. Starting..."
    docker-compose start
    
    if [ $? -eq 0 ]; then
        echo "Successfully started $DB_CONTAINER_NAME."
    else
        echo "Failed to start. Attempting docker-compose up -d..."
        docker-compose up -d
    fi
fi