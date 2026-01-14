#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

echo "WARNING: This will wipe all data in $DB_CONTAINER_NAME. Are you sure? (y/n)"
read -r confirm

if [ "$confirm" != "y" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Stopping container and cleaning data..."
docker-compose down

if [ -d "data" ]; then
    sudo rm -rf ./data/*
    echo "Data directory cleared."
fi

echo "Clean operation finished. Run deploy.sh to re-initialize."