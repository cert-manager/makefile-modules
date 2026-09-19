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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Verify the integrity of a restored cache directory before it is trusted.
#
# Intended to run after restoring a cache in CI from a low-trust source
# (e.g. a node-local hostPath shared with presubmit jobs that could plant
# trojan binaries). It performs three checks:
#
#   1. For each file directly under <cache-dir>/tools/: if the file name is
#      not in the supplied allow-list, it is removed; otherwise its SHA-256
#      (via hash.sh) must match the expected hash or the file is removed.
#   2. Anything in <cache-dir>/ other than the tools/ directory is removed
#      outright — only the tools/ subtree is considered part of the cache.
#   3. If go, go.mod and go.sum are present in the working directory, run
#      `go mod verify` to validate the Go module cache. NOTE: `go mod verify`
#      checks the modules in $GOMODCACHE (defaults to $GOPATH/pkg/mod); the
#      caller must point GOMODCACHE at the restored cache for this to
#      verify it.
#
# Exits 0 if nothing was removed (cache was clean), 1 if any file or
# directory was removed (cache was corrupted/tampered and CI should treat
# the restore as a miss).
#
# Usage: verify_cache.sh <cache-dir> [<file>=<hash> ...]
#   <cache-dir>   Path to an existing cache directory containing tools/.
#   <file>=<hash> Allow-listed file under tools/ and its expected SHA-256.
#                 <hash> must be non-empty; every allow-listed file is
#                 hash-checked.

if [[ $# -lt 1 ]]; then
	echo "Usage: $(basename "$0") <cache-dir> [<file>=<hash> ...]" >&2
	exit 2
fi

cache_dir="$1"
shift

if [[ ! -d "${cache_dir}" ]]; then
	echo "error: cache directory does not exist: ${cache_dir}" >&2
	exit 2
fi

tools_dir="${cache_dir}/tools"

declare -A hashes
for pair in "$@"; do
	if [[ "${pair}" != *=* ]]; then
		echo "error: expected <file>=<hash>, got: ${pair}" >&2
		exit 2
	fi
	name="${pair%%=*}"
	hash="${pair#*=}"
	if [[ -z "${name}" ]]; then
		echo "error: empty file name in argument: ${pair}" >&2
		exit 2
	fi
	if [[ -z "${hash}" ]]; then
		echo "error: empty hash for file '${name}'; every allow-listed file must have a hash" >&2
		exit 2
	fi
	hashes["${name}"]="${hash}"
done

removed=0

# Verify tools/ directory
for file in "${tools_dir}"/*; do
	[[ -f "${file}" ]] || continue
	name=$(basename "${file}")

	# Remove unknown files
	if [[ ! -v hashes["${name}"] ]]; then
		rm -f "${file}"
		removed=1
		continue
	fi

	# Remove files with wrong hash
	if [[ $("${SCRIPT_DIR}/hash.sh" "${file}") != "${hashes[${name}]}" ]]; then
		rm -f "${file}"
		removed=1
	fi
done

# Remove all unexpected files/directories in cache root (not tools/)
for item in "${cache_dir}"/*; do
	[[ -e "${item}" ]] || continue
	[[ "$(basename "${item}")" == "tools" ]] && continue
	rm -rf "${item}"
	removed=1
done

if [[ -f go.mod ]] && [[ -f go.sum ]] && command -v go >/dev/null 2>&1; then
	echo "## Verifying Go module cache"
	go mod verify
fi

exit "${removed}"
