#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

echo "CRITICAL WARNING: This will PERMANENTLY DELETE the database and all data. Type 'DELETE' to confirm:"
read -r confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Destroying container, network and volumes..."
docker-compose down --rmi all -v --remove-orphans

if [ -d "data" ]; then
    sudo rm -rf ./data
    echo "Data directory deleted."
fi

echo "Success: Database existence removed from host."