#
# Copyright 2016 The Symphony Software Foundation
#
# Licensed to The Symphony Software Foundation (SSF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#
#!/bin/bash

# oc-deploy.sh
#
# This scripts installs Openshift CLI (oc), logs into https://api.preview.openshift.com
# and starts an image build, passing the binaries from file.
# More info on https://docs.openshift.org/latest/dev_guide/builds.html#binary-source

# Environment variables needed:
# - OC_TOKEN - The Openshift Online token
# - OC_ENDPOINT - Defaults to https://api.starter-us-east-1.openshift.com
# - OC_PROJECT_NAME - The Openshift Online project to use; default is botfarm
# - OC_BINARY_FOLDER - contains the local path to the binary folder to upload to the container as source
# - OC_BINARY_ARCHIVE - contains the local path to the binary archive to upload to the container as source
# - OC_BUILD_CONFIG_NAME - the name of the BuildConfig registered in Openshift
# - OC_TEMPLATE - the path of an OpenShift template to execute; if resolved, it will process and create it 
# before the start-build; defaults to '.openshift-template.yaml', if the file exists

# Environment variables overrides:
# - OC_VERSION
# - OC_RELEASE

# Fail if no mandatory vars are missing
if [[ -z "$OC_TOKEN" ]]; then
  echo "Missing OC_TOKEN. Failing."
  exit -1
fi
if [[ -z "$OC_BINARY_FOLDER" && -z "$OC_BINARY_ARCHIVE" ]]; then
  echo "Missing OC_BINARY_FOLDER or OC_BINARY_ARCHIVE. Failing."
  exit -1
fi
if [[ -z "$OC_BUILD_CONFIG_NAME" ]]; then
  echo "Missing OC_BUILD_CONFIG_NAME. Failing."
  exit -1
fi

if [[ -z "$OC_PROJECT_NAME" ]]; then
  export OC_PROJECT_NAME=botfarm
fi
echo "Using Openshift Online project $OC_PROJECT_NAME"

# Define oc defaults
if [[ -z "$OC_ENDPOINT" ]]; then
  OC_ENDPOINT="https://api.starter-us-east-1.openshift.com"
fi
if [[ -z "$OC_VERSION" ]]; then
  OC_VERSION=v1.5.1
fi
if [[ -z "$OC_RELEASE" ]]; then
  OC_RELEASE=7b451fc-linux-64bit
fi

OC_FOLDER_NAME=openshift-origin-client-tools-$OC_VERSION-$OC_RELEASE
if [[ "$OC_VERSION" == "v1.4.1" ]]; then
  OC_FOLDER_NAME=openshift-origin-client-tools-$OC_VERSION+$OC_RELEASE
fi

OC_URL="https://github.com/openshift/origin/releases/download/$OC_VERSION/openshift-origin-client-tools-$OC_VERSION-$OC_RELEASE.tar.gz"
PATH=$PWD/$OC_FOLDER_NAME:$PATH

# Download and unpack oc
curl -Ls $OC_URL | tar xvz

# Log into Openshift Online and use project botfarm
oc login $OC_ENDPOINT --token=$OC_TOKEN ; oc project $OC_PROJECT_NAME
echo "Logged into $OC_ENDPOINT"

if [[ -f ".openshift-template.yaml" ]]; then
  export OC_TEMPLATE=".openshift-template.yaml"
  echo "Found $OC_TEMPLATE OpenShift template"
fi

# Create the DeploymentConfig template, if configured
if [[ -n "$OC_TEMPLATE" ]]; then
  oc process -f $OC_TEMPLATE | oc create -f -
  echo "$OC_TEMPLATE template created"
fi

# Start the folder build
if [[ -n "$OC_BINARY_FOLDER" ]]; then
  oc start-build $OC_BUILD_CONFIG_NAME --from-dir=$OC_BINARY_FOLDER --wait=true
  echo "Build of $OC_BUILD_CONFIG_NAME from folder $OC_BINARY_FOLDER completed"
fi

# Start the archive build
if [[ -n "$OC_BINARY_ARCHIVE" ]]; then
  oc start-build $OC_BUILD_CONFIG_NAME --from-archive=$OC_BINARY_ARCHIVE --wait=true
  echo "Build of $OC_BUILD_CONFIG_NAME from archive $OC_BINARY_ARCHIVE completed"
fi
