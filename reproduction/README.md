# Paper Reproduction

Reproduction of simulation scenarios from:

> Gutierrez, Ponti, Neuenschwander, Yaninek, & Herren (2025).
> "Predicting natural enemy efficacy in biological control using ex-ante analyses."
> *Scientific Reports*. https://doi.org/10.1038/s41598-025-29022-1

## Scenarios

### CM biological control (1980–1990)

| ID | Description | CMB | A.lopezi | A.diversicornis | Fungi | GM |
|----|-------------|-----|----------|-----------------|-------|----|
| `cassava-only` | Potential yield baseline | F | F | F | F | F |
| `cm-only` | CM damage, no control | T | F | F | F | F |
| `cm-al` | CM + *A. lopezi* | T | T | F | F | F |
| `cm-ad` | CM + *A. diversicornis* | T | F | T | F | F |
| `cm-al-ad` | CM + both parasitoids | T | T | T | F | F |
| `cm-fungi` | CM + pathogen only | T | F | F | T | F |

### CGM biological control (1990–2000)

| ID | Description | CMB | GM | T.aripo | A.manihoti |
|----|-------------|-----|----|---------|------------|
| `cgm-only` | CGM damage, no control | F | T | F | F |
| `cgm-ta` | CGM + *T. aripo* | F | T | T | F |
| `cgm-am` | CGM + *A. manihoti* | F | T | F | T |
| `cgm-ta-am` | CGM + both predators | F | T | T | T |

## Paper settings

- **Plants**: 10, scattered distribution (type 2)
- **Cells**: 10,172 alternating lat/lon lattice cells (every other in both dimensions from the 40,656 Africa grid)
- **RNG**: randseed=0 (different sequences each run, matching legacy behavior)
- **GIS output**: annual (interval 365)
- **First year excluded** from means/analysis

## Usage

```bash
# Build the cassava binary first
cd ../cassava && fpc -Mdelphi cassava.pas

# Pilot run (10 cells, 1 scenario)
cd reproduction
python3 scripts/run_scenarios.py --pilot --scenarios cassava-only

# Pilot run (10 cells, all scenarios)
python3 scripts/run_scenarios.py --pilot

# Full run (all cells, all scenarios) — takes many hours
python3 scripts/run_scenarios.py

# Custom cell count
python3 scripts/run_scenarios.py --max-cells 100 --scenarios cm-only,cm-al

# Collect results into summary tables
python3 scripts/collect_results.py
```

## Output structure

```
output/
  <scenario>/
    cells.tsv              # Cell manifest for this run
    <wxfilename>/          # Per-cell output directory
      Cassava.ini
      GisFilesList.txt
      Cassava_*_*.txt      # Annual GIS output files
      CassavaSummaries.txt
```

## Pilot mode

Pilot mode selects 10 geographically diverse cells across Africa for quick testing.
Results go to `output/` same as full runs (cells.tsv records which cells were used).
