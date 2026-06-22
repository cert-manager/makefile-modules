# Copyright 2023 The cert-manager Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###################################################################################

# This makefile can be used to learn hashes for the tools Makefile module.
# To upgrade the tools in the tools module:
# 1. bump the versions in the modules/tools/00_mod.mk file
# 2. run `make tools-learn-sha`

###################################################################################

# Some modules build their dependencies from variables, we want these to be 
# evaluated at the last possible moment. For this we use second expansion to 
# re-evaluate the generate and verify targets a second time.
#
# See https://www.gnu.org/software/make/manual/html_node/Secondary-Expansion.html
.SECONDEXPANSION:

# For details on some of these "prelude" settings, see:
# https://clarkgrubb.com/makefile-style-guide
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
SHELL := /usr/bin/env bash
# The `--norc` option prevents "PS1: unbound" errors.
# If Bash thinks it is being run with its standard input connected to a network
# connection (such as via SSH or via Docker), it reads and executes commands
# from ~/.bashrc, regardless of whether it thinks it is in interactive mode.
# Bash does not set PS1 in non-interactive environments. But on Ubuntu 24.04 the
# default /etc/bash.bashrc file assumes that PS1 is set.
#
# See https://www.gnu.org/software/bash/manual/bash.html#Invoked-by-remote-shell-daemon
.SHELLFLAGS := --norc -uo pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:
FORCE:

# The reason we don't use "go env GOOS" or "go env GOARCH" is that the "go"
# binary may not be available in the PATH yet when the Makefiles are
# evaluated. HOST_OS and HOST_ARCH only support Linux, *BSD and macOS (M1
# and Intel).
host_os := $(shell uname -s | tr A-Z a-z)
host_arch := $(shell uname -m)
HOST_OS ?= $(host_os)
HOST_ARCH ?= $(host_arch)

ifeq (x86_64, $(HOST_ARCH))
	HOST_ARCH = amd64
else ifeq (aarch64, $(HOST_ARCH))
	# linux reports the arm64 arch as aarch64
	HOST_ARCH = arm64
endif

bin_dir := _bin
$(bin_dir) $(bin_dir)/scratch:
	mkdir -p $@

# Variables required by the included makefile-modules
repo_name := github.com/cert-manager/makefile-modules # For `make generate-govulncheck`.
golangci_lint_config := .golangci.yaml # For `make generate-golangci-lint-config`.
# Modules that are used in this repo:
# - tools: allows us to download crane
# - generate-verify: to allow renovate to run make generate after updating the `go.mod` files in this repo.
# - boilerplate: to ensure all files have license boilerplate
# - go: so that make go-tidy is triggered by make generate.
#
# Module files must be included in number order (00,01,02) to satisfy the
# dependencies between them.
include modules/tools/00_mod.mk
include modules/generate-verify/00_mod.mk
include modules/boilerplate/00_mod.mk
include modules/boilerplate/01_mod.mk
include modules/go/01_mod.mk
include modules/generate-verify/02_mod.mk

## Upgrade targets

.PHONY: upgrade-base-images
upgrade-base-images: | $(NEEDS_CRANE)
	@CRANE=$(CRANE) \
		./scripts/upgrade_base_images.sh

# Upgrade the kind images to the latest available version from
# the kind release description. This script is useful when kind publishes
# a new kubernetes image and updates the kind release description.
.PHONY: upgrade-kind-images
upgrade-kind-images: | $(NEEDS_CRANE)
	@CRANE=$(CRANE) \
		./scripts/learn_kind_images.sh --force

## SHA learning targets

# Learn the shas for the tools in the tools module.
# This will update the tools module with the new shas, this is
# useful after bumping the versions in the tools module Makefile.
# We will also check the kind images and update them if the kind
# version has been bumped.
.PHONY: learn-tools-shas
learn-tools-shas: | $(NEEDS_CRANE)
	./scripts/learn_tools_shas.sh non-go-tools _bin/tools/go
	@CRANE=$(CRANE) \
		./scripts/learn_kind_images.sh

# Learn the shas for the vendored Go version in the go module.
# This must be run whenever the Go version is updated.
.PHONY: learn-golang-shas
learn-golang-shas:
	./scripts/learn_tools_shas.sh _bin/tools/go

.PHONY: learn-image-shas
learn-image-shas: | $(NEEDS_CRANE)
	@CRANE=$(CRANE) \
		./scripts/learn_image_shas.sh

# Test targets

.PHONY: test-e2e
test-e2e:
	@./tests/test_e2e.sh

.PHONY: help
help: ## Show this help
	@echo "Usage: make [target] ..."
	@echo
	@echo "make upgrade-base-images"
	@echo "make upgrade-kind-images"
	@echo
	@echo "make learn-golang-shas"
	@echo "make learn-tools-shas"
	@echo "make learn-image-shas"
	@echo
	@echo "make test-e2e"
