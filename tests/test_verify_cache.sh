#!/usr/bin/env bash

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

set -o errexit
set -o nounset
set -o pipefail

script_dir=$(dirname "$(realpath "$0")")
verify_cache="${script_dir}/../modules/tools/util/verify_cache.sh"
hash_script="${script_dir}/../modules/tools/util/hash.sh"

echo "Testing verify_cache.sh"

# Test 1: Empty cache passes
echo "Test 1: Empty cache"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools"
"${verify_cache}" "${tmp_dir}" file1=abc123 file2=def456 && echo "✓ pass" || echo "✗ fail"
rm -rf "${tmp_dir}"

# Test 2: Valid files pass
echo "Test 2: Valid files"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools"
echo "content1" > "${tmp_dir}/tools/file1"
echo "content2" > "${tmp_dir}/tools/file2"
hash1=$("${hash_script}" "${tmp_dir}/tools/file1")
hash2=$("${hash_script}" "${tmp_dir}/tools/file2")
"${verify_cache}" "${tmp_dir}" "file1=${hash1}" "file2=${hash2}" && echo "✓ pass" || echo "✗ fail"
rm -rf "${tmp_dir}"

# Test 3: Unknown file in tools/ removed
echo "Test 3: Unknown file removed"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools"
echo "content1" > "${tmp_dir}/tools/file1"
echo "trojan" > "${tmp_dir}/tools/evil"
hash1=$("${hash_script}" "${tmp_dir}/tools/file1")
if "${verify_cache}" "${tmp_dir}" "file1=${hash1}" 2>/dev/null; then
    echo "✗ fail - should have exited 1"
    rm -rf "${tmp_dir}"
    exit 1
fi
[[ ! -f "${tmp_dir}/tools/evil" ]] && echo "✓ pass" || echo "✗ fail - evil not removed"
rm -rf "${tmp_dir}"

# Test 4: Wrong hash removed
echo "Test 4: Wrong hash removed"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools"
echo "content1" > "${tmp_dir}/tools/file1"
if "${verify_cache}" "${tmp_dir}" "file1=wronghash" 2>/dev/null; then
    echo "✗ fail - should have exited 1"
    rm -rf "${tmp_dir}"
    exit 1
fi
[[ ! -f "${tmp_dir}/tools/file1" ]] && echo "✓ pass" || echo "✗ fail - file1 not removed"
rm -rf "${tmp_dir}"

# Test 5: Empty hash is rejected
echo "Test 5: Empty hash rejected"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools"
echo "content" > "${tmp_dir}/tools/etcd"
if "${verify_cache}" "${tmp_dir}" "etcd=" 2>/dev/null; then
    echo "✗ fail - should have exited non-zero"
    rm -rf "${tmp_dir}"
    exit 1
fi
echo "✓ pass - empty hash rejected"
rm -rf "${tmp_dir}"

# Test 6: Mixed scenario in tools/
echo "Test 6: Mixed scenario"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools"
echo "good" > "${tmp_dir}/tools/kind"
echo "bad" > "${tmp_dir}/tools/helm"
echo "trojan" > "${tmp_dir}/tools/evil"
hash_kind=$("${hash_script}" "${tmp_dir}/tools/kind")
if "${verify_cache}" "${tmp_dir}" "kind=${hash_kind}" "helm=wronghash" 2>/dev/null; then
    echo "✗ fail - should have exited 1"
    rm -rf "${tmp_dir}"
    exit 1
fi
[[ -f "${tmp_dir}/tools/kind" ]] && echo "✓ pass - kind kept" || echo "✗ fail - kind removed"
[[ ! -f "${tmp_dir}/tools/helm" ]] && echo "✓ pass - helm removed" || echo "✗ fail - helm kept"
[[ ! -f "${tmp_dir}/tools/evil" ]] && echo "✓ pass - evil removed" || echo "✗ fail - evil kept"
rm -rf "${tmp_dir}"

# Test 7: Removes untrusted files/dirs from cache root
echo "Test 7: Cache root cleanup"
tmp_dir=$(mktemp -d)
mkdir -p "${tmp_dir}/tools" "${tmp_dir}/evil_dir"
echo "good" > "${tmp_dir}/tools/kind"
echo "trojan1" > "${tmp_dir}/trojan_root"
echo "trojan2" > "${tmp_dir}/evil_dir/payload"
hash_kind=$("${hash_script}" "${tmp_dir}/tools/kind")
if "${verify_cache}" "${tmp_dir}" "kind=${hash_kind}" 2>/dev/null; then
    echo "✗ fail - should have exited 1"
    rm -rf "${tmp_dir}"
    exit 1
fi
[[ -f "${tmp_dir}/tools/kind" ]] && echo "✓ pass - kind kept" || echo "✗ fail - kind removed"
[[ ! -f "${tmp_dir}/trojan_root" ]] && echo "✓ pass - trojan_root removed" || echo "✗ fail - trojan_root kept"
[[ ! -d "${tmp_dir}/evil_dir" ]] && echo "✓ pass - evil_dir removed" || echo "✗ fail - evil_dir kept"
rm -rf "${tmp_dir}"

echo "All tests passed"
