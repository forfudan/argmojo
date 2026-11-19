#!/bin/bash
# run.sh — run one CI command with a timeout, retrying only when it crashes.
#
# A command that exits normally, pass or fail, is never retried, so a flaky
# test cannot hide behind a retry. A command killed by a signal (a compiler
# crash, or the timeout below) is retried up to 3 attempts, and each retry is
# reported as a GitHub warning so it shows up in the run summary.
#
# Usage:  .github/scripts/run.sh <command> [args...]
# Env:    RUN_TIMEOUT  seconds per attempt (default 600)

set -uo pipefail

timeout_s="${RUN_TIMEOUT:-600}"
max_attempts=3

for attempt in $(seq 1 "$max_attempts"); do
    # `perl -e alarm` works on both macOS and Linux runners, unlike
    # coreutils `timeout`, which macOS does not ship.
    perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' \
        "$timeout_s" "$@"
    status=$?
    if [ "$status" -lt 128 ]; then
        exit "$status"
    fi
    if [ "$status" -eq 142 ]; then
        reason="timed out after ${timeout_s}s"
    else
        reason="was killed by signal $((status - 128))"
    fi
    if [ "$attempt" -lt "$max_attempts" ]; then
        echo "::warning::'$*' $reason (attempt $attempt of $max_attempts); retrying"
        sleep 5
    else
        echo "::error::'$*' $reason on all $max_attempts attempts"
        exit "$status"
    fi
done
