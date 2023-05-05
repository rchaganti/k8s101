#!/bin/bash

# Firewall rules
ufw allow 22/tcp
ufw allow 2376/tcp
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

# Initialize swarm
docker swarm init

# Join swarm
docker swarm join --token <Token> <Leader-IP>:2377

# Checlk swarm nodes
docker node ls

# Enabling swarm creates an overlay network
docker network ls

# Create a service
docker service create --replicas 2 --name nginx --publish 8080:80 nginx:latest

# Create declaratively
docker stack deploy -c docker-stack.yaml voting-app

# Inspect services
docker stack services voting-app
docker service ps voting-app_vote

# Working with stack
docker stack ps voting-app
docker stack rm voting-app
