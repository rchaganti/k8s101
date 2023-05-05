#!/bin/bash

# Check if kubectl is working
kubectl version --output=json

# Get help
kubectl explain pods