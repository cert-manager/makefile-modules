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

golangci_lint_timeout ?= 10m

.PHONY: verify-kube-api-lint
## Verify all APIs using Kube API Linter
## @category [shared] Generate/ Verify
verify-kube-api-lint: | $(NEEDS_GO) $(NEEDS_GOLANGCI-LINT-KUBE) $(bin_dir)/scratch
	@find . -name go.mod -not \( -path "./$(bin_dir)/*" -or -path "./make/_shared/*" \) \
		| while read d; do \
				target=$$(dirname $${d}); \
				echo "Running 'GOVERSION=$(VENDORED_GO_VERSION) $(bin_dir)/tools/golangci-lint run -c $(CURDIR)/$(golangci_lint_kube_config) --timeout $(golangci_lint_timeout)' in directory '$${target}'"; \
				pushd "$${target}" >/dev/null; \
				GOVERSION=$(VENDORED_GO_VERSION) $(GOLANGCI-LINT-KUBE) run -c $(CURDIR)/$(golangci_lint_kube_config) --timeout $(golangci_lint_timeout) || exit; \
				popd >/dev/null; \
				echo ""; \
			done

shared_verify_targets_dirty += verify-kube-api-lint

.PHONY: fix-kube-api-lint
## Fix all APIs using Kube API Linter
## @category [shared] Generate/ Verify
fix-kube-api-lint: | $(NEEDS_GO) $(NEEDS_GOLANGCI-LINT-KUBE) $(bin_dir)/scratch
	@find . -name go.mod -not \( -path "./$(bin_dir)/*" -or -path "./make/_shared/*" \) \
		| while read d; do \
				target=$$(dirname $${d}); \
				echo "Running 'GOVERSION=$(VENDORED_GO_VERSION) $(bin_dir)/tools/golangci-lint run --fix -c $(CURDIR)/$(golangci_lint_kube_config) --timeout $(golangci_lint_timeout)' in directory '$${target}'"; \
				pushd "$${target}" >/dev/null; \
				GOVERSION=$(VENDORED_GO_VERSION) $(GOLANGCI-LINT-KUBE) run --fix -c $(CURDIR)/$(golangci_lint_kube_config) --timeout $(golangci_lint_timeout) || exit; \
				popd >/dev/null; \
				echo ""; \
			done
