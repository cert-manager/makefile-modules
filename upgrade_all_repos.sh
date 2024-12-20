#!/usr/bin/env bash

# Copyright 2022 The cert-manager Authors.
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

set -o errexit
set -o nounset
set -o pipefail

# This script creates upgrade PRs for the repos listed in the `repos` array.
# It can be used to create PRs when the self-upgrade logic is not working
# due to a bug or the limitations of GH Actions (which are not allowed to
# modify GH actions workflows themselves).

repos=(
    "https://github.com/cert-manager/cert-manager"
    "https://github.com/cert-manager/website"
    "https://github.com/cert-manager/istio-csr"
    "https://github.com/cert-manager/approver-policy"
    "https://github.com/cert-manager/trust-manager"
    "https://github.com/cert-manager/issuer-lib"
    "https://github.com/cert-manager/csi-driver"
    "https://github.com/cert-manager/csi-driver-spiffe"
    "https://github.com/cert-manager/openshift-routes"
    "https://github.com/cert-manager/cmctl"
    "https://github.com/cert-manager/helm-tool"
    "https://github.com/cert-manager/google-cas-issuer"
)

echo "This script will create upgrade PRs for the following repos:"
for repo in "${repos[@]}"; do
    echo "  - $repo"
done

read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting..."
    exit 1
fi

upgrade_dir="_upgrade"

for repo in "${repos[@]}"; do
    name=$(basename "$repo")

    rm -rf "$upgrade_dir/$name"
    mkdir -p "$upgrade_dir/$name"

    pushd "$upgrade_dir/$name" || exit 1
    git clone "$repo" .

    make -j upgrade-klone
    make -j generate
    
    branch_name=$(git rev-parse --abbrev-ref HEAD)
    git_status=$(git status -s)
    if [ -n "$git_status" ]; then
        git checkout -B "self-upgrade-$branch_name"
        git add -A && git commit -m "Run 'make upgrade-klone' and 'make generate'" --signoff
        git push -f origin "self-upgrade-$branch_name"
        gh pr create --title "[CI] Self-upgrade merging self-upgrade-$branch_name into $branch_name" --body "Manual run of self-upgrade logic" -l "approved" -l "lgtm" || true
    fi
    popd || exit 1
done
