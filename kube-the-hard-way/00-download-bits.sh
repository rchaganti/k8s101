#!/bin/bash
CONTAINERD_VERSION=${CONTAINERD_VERSION:-"2.0.2"}
RUNC_VERSION=${RUNC_VERSION:-"1.2.4"}
CNI_PLUGINS_VERSION=${CNI_PLUGINS_VERSION:-"1.6.2"}

# Download the necessary binaries
curl -Lo /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz \
         https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

curl -Lo /tmp/runc.amd64 https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64

curl -Lo /tmp/cni-plugins-amd64-v${CNI_PLUGINS_VERSION}.tgz \
         https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz

