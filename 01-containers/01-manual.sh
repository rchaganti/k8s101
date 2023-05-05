#!/bin/bash

# pull an image from Docker Hub
docker image pull ubuntu:latest

# List all images
docker images

# Run a container interactively
docker run -it ubuntu /bin/bash

# Run a container in the background
docker run -d ubuntu sleep 100

# List running containers
docker container ls

# List all containers on the systems
docker container ls -a

# list all networks
docker network ls

# create a network
docker network create frontend
docker network create backend

# provision voting app
docker run -d -p 6379:6379 --name redis --network backend redis
docker run -d -p 5000:80 --name vote --network frontend docker/example-voting-app-vote
docker network connect backend vote
docker run -d --name db --network=backend -e POSTGRES_HOST_AUTH_METHOD=trust postgres:9.4
docker run -d --name worker --network=backend docker/example-voting-app-worker
docker run -d --name result --network=frontend -p 5001:80 docker/example-voting-app-result
docker network connect backend result
