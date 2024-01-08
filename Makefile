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

MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
SHELL := /usr/bin/env bash
.SHELLFLAGS := -uo pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:
FORCE:

HOST_OS ?= $(shell uname -s | tr A-Z a-z)
HOST_ARCH ?= $(shell uname -m)
ifeq (x86_64, $(HOST_ARCH))
	HOST_ARCH = amd64
endif

bin_dir := _bin

$(bin_dir) $(bin_dir)/scratch:
	mkdir -p $@

include modules/**/00_mod.mk

.PHONY: images-learn-sha
images-learn-sha: $(bin_dir) | $(NEEDS_CRANE)
	rm -rf ./$(bin_dir)/downloaded/images/
	mkdir -p ./$(bin_dir)/scratch/
	
	$(eval export LEARN_FILE=$(CURDIR)/$(bin_dir)/scratch/learn_images_file)
	echo -n "" > "$(LEARN_FILE)"

	for image in $(images_amd64); do \
		image_no_digest=$$(echo -n "$${image}" | cut -d@ -f1); \
		find=$$(echo -n "$${image}" | cut -d@ -f2); \
		replace=$$($(CRANE) digest --platform "linux/amd64" "$${image_no_digest}"); \
		echo "s|$${find}|$${replace}|g" >> "$(LEARN_FILE)"; \
	done

	for image in $(images_arm64); do \
		image_no_digest=$$(echo -n "$${image}" | cut -d@ -f1); \
		find=$$(echo -n "$${image}" | cut -d@ -f2); \
		replace=$$($(CRANE) digest --platform "linux/arm64" "$${image_no_digest}"); \
		echo "s|$${find}|$${replace}|g" >> "$(LEARN_FILE)"; \
	done

	while read p; do \
		find ./modules/ -maxdepth 2 -name "00_mod.mk" -type f -exec sed -i "$$p" {} \;; \
	done <"$(LEARN_FILE)"

.PHONY: help
help: ## Show this help
	@echo "Usage: make [target] ..."
	@echo
	@echo "make tools-learn-sha"
	@echo "make images-learn-sha"
