#!/bin/bash
# Run all 11 scenarios across the full grid with 8 parallel workers.
# Each scenario is run separately so partial progress is preserved.
# Supports resume: cells with existing GIS output are skipped.

set -e
cd "$(dirname "$0")"

WORKERS=8
LOG=run_full.log

echo "=== Full grid run started at $(date) ===" | tee -a "$LOG"

for scenario in cassava-only cm-only cm-al cm-ad cm-al-ad cm-fungi \
                cassava-only-cgm cgm-only cgm-ta cgm-am cgm-ta-am; do
    echo "--- Starting $scenario at $(date) ---" | tee -a "$LOG"
    python3 -u scripts/run_scenarios.py -j "$WORKERS" --scenario "$scenario" 2>&1 | tee -a "$LOG"
    echo "--- Finished $scenario at $(date) ---" | tee -a "$LOG"
done

echo "=== Full grid run completed at $(date) ===" | tee -a "$LOG"

# Collect results
echo "Collecting results..." | tee -a "$LOG"
python3 scripts/collect_results.py 2>&1 | tee -a "$LOG"

echo "Generating report..." | tee -a "$LOG"
python3 scripts/analyze_results.py 2>&1 | tee -a "$LOG"

echo "All done." | tee -a "$LOG"
