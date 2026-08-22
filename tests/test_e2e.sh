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

# This test bootstraps a makefile-module project by using the bootstrap.sh script
# and then copies the local modules into this project. After that, it runs a few
# make commands to ensure that the project is working as expected.

script_dir=$(dirname "$(realpath "$0")")

# Run script for each folder in the e2e-projects directory

for project in "${script_dir}"/e2e-projects/*; do
    if [ ! -d "${project}" ]; then
        continue
    fi

    echo "> Running e2e test for project: ${project}"

    # Create a temporary directory to work in
    tmp_dir=$(mktemp -d)
    trap '{ rm -rf "$tmp_dir"; echo "> Deleted temp dir $tmp_dir"; }' EXIT

    # Initialize the git repository
    pushd "${tmp_dir}" > /dev/null
    git init --initial-branch=main
    git config --local user.name "e2e tester"
    git config --local user.email "test@cert-manager.io"
    echo "_bin" > .gitignore
    git add .
    git commit -m "Initial commit"
    git tag --annotate --message="Initial release" v0.0.0
    popd > /dev/null

    # Run the bootstrap script
    "${script_dir}/../bootstrap.sh" "${tmp_dir}" "empty"

    # Remove the klone module to prevent generate from overwriting the local modules
    rm -rf "${tmp_dir}/make/_shared/klone"

    # Copy the test project into the temporary directory
    cp -r "${project}/." "${tmp_dir}/"

    modules_to_copy=()
    targets_to_run=()

    # Load the test configuration
    source "${project}/test-config.sh"

    # Copy the local modules
    for module in "${modules_to_copy[@]}"; do
        cp -r "${script_dir}/../modules/${module}" "${tmp_dir}/make/_shared/"
    done

    # Run the make commands
    pushd "${tmp_dir}" > /dev/null
        for target in "${targets_to_run[@]}"; do
            echo "> Running make ${target}"
            make "${target}"
        done

        # Assert that a Go toolchain version change rebuilds and re-links a
        # go_dependency tool, and that reverting re-links the cached binary
        # without rebuilding it. An isolated DOWNLOAD_DIR keeps the fake
        # toolchain key out of the shared cache.
        if printf '%s\n' "${modules_to_copy[@]}" | grep -qx "tools"; then
            echo "> Asserting Go toolchain cache invalidation for gojq"
            dl_dir="${tmp_dir}/e2e_download"

            make DOWNLOAD_DIR="${dl_dir}" _bin/tools/gojq
            original_target=$(readlink _bin/tools/gojq)

            make DOWNLOAD_DIR="${dl_dir}" GO_TOOLCHAIN_VERSION=go0.0.0-test _bin/tools/gojq
            fake_target=$(readlink _bin/tools/gojq)
            [[ "${fake_target}" == *"_go0.0.0-test_"* ]]
            [[ "${fake_target}" != "${original_target}" ]]

            # A rebuild produces a new file (new inode); the relink recipe
            # touches the existing one, so compare inodes, not mtimes.
            inode_before=$(stat -c %i "${original_target}" 2>/dev/null || stat -f %i "${original_target}")
            make DOWNLOAD_DIR="${dl_dir}" _bin/tools/gojq
            [[ "$(readlink _bin/tools/gojq)" == "${original_target}" ]]
            inode_after=$(stat -c %i "${original_target}" 2>/dev/null || stat -f %i "${original_target}")
            [[ "${inode_before}" == "${inode_after}" ]]
        fi
    popd > /dev/null
done
