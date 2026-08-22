# Copyright 2026 The cert-manager Authors.
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

.PHONY: verify-pinact
## Verify all actions have pinned digests with matching version comment
## @category [shared] Generate/ Verify
verify-pinact: | $(NEEDS_PINACT)
	$(PINACT) run --check --verify-comment

shared_verify_targets += verify-pinact

.PHONY: fix-pinact
## Fix all actions have pinned digests with matching version comment
## @category [shared] Generate/ Verify
fix-pinact: | $(NEEDS_PINACT)
	$(PINACT) run --fix --verify-comment

generate_gh_workflows_base_dir := $(dir $(lastword $(MAKEFILE_LIST)))/base/

.PHONY: generate-gh-workflows
## Generate base files in the repository
## @category [shared] Generate/ Verify
generate-gh-workflows:
	cp -r $(generate_gh_workflows_base_dir)/. ./

shared_generate_targets += generate-gh-workflows
