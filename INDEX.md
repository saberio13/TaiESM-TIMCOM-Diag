# 📑 Repository Navigation Index

Quick links to all documentation and resources in this repository.

---

## 🚀 Start Here

**New to this project?** → [Quick Start Guide](docs/QUICKSTART.md) (5 minutes)

**Need comprehensive overview?** → [Main README](README.md) (15 minutes)

**Want technical details?** → [Repository Summary](REPOSITORY_SUMMARY.md)

---

## 📖 Documentation Map

### Getting Started
| Document | Purpose | Time | Audience |
|----------|---------|------|----------|
| [QUICKSTART.md](docs/QUICKSTART.md) | Run your first diagnostic | 5 min | Beginners |
| [README.md](README.md) | Complete project overview | 15 min | All users |
| [REPOSITORY_SUMMARY.md](REPOSITORY_SUMMARY.md) | Technical summary | 10 min | Developers |

### Deep Dive
| Document | Purpose | Time | Audience |
|----------|---------|------|----------|
| [SCRIPT_DETAILS.md](docs/SCRIPT_DETAILS.md) | Algorithm explanations | 1-2 hours | Advanced users |
| [workflow_guide.md](docs/workflow_guide.md) | Analysis workflows | 30 min | Researchers |
| [troubleshooting.md](docs/troubleshooting.md) | Problem solving | As needed | All users |

---

## 🔧 Scripts Reference

### Core Diagnostic Scripts

| Script | Variable | Lines | Complexity | Documentation Link |
|--------|----------|-------|------------|-------------------|
| [diag_ice.ncl](scripts/diag_ice.ncl) | Sea Ice Concentration | 520 | Medium | [Details](docs/SCRIPT_DETAILS.md#sea-ice-concentration-analysis-detailed) |
| [diag_precipitation.ncl](scripts/diag_precipitation.ncl) | Precipitation | 588 | Low | [Details](docs/SCRIPT_DETAILS.md#precipitation-analysis-detailed) |
| [diag_SAT.ncl](scripts/diag_SAT.ncl) | Surface Air Temperature | 409 | Medium | [Details](docs/SCRIPT_DETAILS.md#surface-air-temperature-analysis-detailed) |
| [diag_SST.ncl](scripts/diag_SST.ncl) | Sea Surface Temperature | 543 | High | [Details](docs/SCRIPT_DETAILS.md#sea-surface-temperature-analysis-detailed) |

---

## 📚 Documentation by Topic

### Installation & Setup
- **Install NCL:** [README.md#installation--dependencies](README.md#installation--dependencies)
- **Environment Setup:** [README.md#environment-setup](README.md#environment-setup)
- **Data Organization:** [QUICKSTART.md#step-2-organize-your-data](docs/QUICKSTART.md#step-2-organize-your-data)

### Configuration
- **Script Configuration:** [README.md#configure-script-paths](README.md#configure-script-paths)
- **Configuration Templates:** [workflow_guide.md#configuration-templates](docs/workflow_guide.md#configuration-templates)
- **Customization Examples:** [REPOSITORY_SUMMARY.md#customization-examples](REPOSITORY_SUMMARY.md#customization-examples)

### Running Scripts
- **Quick Start:** [QUICKSTART.md#step-4-run-the-script](docs/QUICKSTART.md#step-4-run-the-script)
- **Batch Processing:** [workflow_guide.md#template-batch-processing-script](docs/workflow_guide.md#template-batch-processing-script)
- **Workflows:** [workflow_guide.md#recommended-workflows](docs/workflow_guide.md#recommended-workflows)

### Understanding Results
- **Output Files:** [README.md#output-files](README.md#output-files)
- **Statistics Interpretation:** [REPOSITORY_SUMMARY.md#expected-output-statistics](REPOSITORY_SUMMARY.md#expected-output-statistics)
- **Visualization Guide:** [README.md#visualization-outputs](README.md#visualization-outputs)

### Troubleshooting
- **Common Issues:** [troubleshooting.md#common-issues](docs/troubleshooting.md#common-issues)
- **Quick Fixes:** [troubleshooting.md#quick-reference-common-fixes](docs/troubleshooting.md#quick-reference-common-fixes)
- **Debug Strategies:** [troubleshooting.md#general-debugging-strategies](docs/troubleshooting.md#general-debugging-strategies)

### Advanced Topics
- **Algorithm Details:** [SCRIPT_DETAILS.md#critical-code-sections](docs/SCRIPT_DETAILS.md#critical-code-sections)
- **Performance Optimization:** [workflow_guide.md#performance-benchmarks](docs/workflow_guide.md#performance-benchmarks)
- **Best Practices:** [workflow_guide.md#best-practices-summary](docs/workflow_guide.md#best-practices-summary)

---

## 🎯 Quick Navigation by Task

### "I want to..."

#### ...get started quickly
→ [QUICKSTART.md](docs/QUICKSTART.md)

#### ...understand what each script does
→ [README.md#script-documentation](README.md#script-documentation)

#### ...see example output
→ [README.md#output-files](README.md#output-files)
→ [REPOSITORY_SUMMARY.md#expected-output-statistics](REPOSITORY_SUMMARY.md#expected-output-statistics)

#### ...configure paths
→ [QUICKSTART.md#step-3-configure-a-script](docs/QUICKSTART.md#step-3-configure-a-script)

#### ...fix an error
→ [troubleshooting.md](docs/troubleshooting.md)

#### ...understand the algorithms
→ [SCRIPT_DETAILS.md](docs/SCRIPT_DETAILS.md)

#### ...create a workflow
→ [workflow_guide.md#recommended-workflows](docs/workflow_guide.md#recommended-workflows)

#### ...modify a script
→ [SCRIPT_DETAILS.md#critical-code-sections](docs/SCRIPT_DETAILS.md#critical-code-sections)
→ [REPOSITORY_SUMMARY.md#customization-examples](REPOSITORY_SUMMARY.md#customization-examples)

#### ...compare multiple models
→ [workflow_guide.md#workflow-5-multi-model-comparison](docs/workflow_guide.md#workflow-5-multi-model-comparison)

#### ...optimize performance
→ [workflow_guide.md#performance-benchmarks](docs/workflow_guide.md#performance-benchmarks)
→ [troubleshooting.md#memory-and-performance-issues](docs/troubleshooting.md#memory-and-performance-issues)

---

## 🔍 Script Comparison

### Choose Your Script

**Analyzing sea ice?**
→ Use [diag_ice.ncl](scripts/diag_ice.ncl)
→ See [README.md#1-sea-ice-concentration-analysis](README.md#1-sea-ice-concentration-analysis)

**Evaluating precipitation?**
→ Use [diag_precipitation.ncl](scripts/diag_precipitation.ncl)
→ See [README.md#2-precipitation-analysis](README.md#2-precipitation-analysis)

**Checking surface temperature?**
→ Use [diag_SAT.ncl](scripts/diag_SAT.ncl)
→ See [README.md#3-surface-air-temperature-analysis](README.md#3-surface-air-temperature-analysis)

**Looking at ocean temperature?**
→ Use [diag_SST.ncl](scripts/diag_SST.ncl)
→ See [README.md#4-sea-surface-temperature-analysis](README.md#4-sea-surface-temperature-analysis)

**Not sure which to start with?**
→ Read [workflow_guide.md#script-selection-guide](docs/workflow_guide.md#script-selection-guide)

---

## 📊 Critical Code Sections

Quick links to the most important algorithms:

### Sea Ice Script
- [NaN Handling](docs/SCRIPT_DETAILS.md#1-nan-handling-in-grid-coordinates) (Lines 85-126)
- [Pole Hole Treatment](docs/SCRIPT_DETAILS.md#2-pole-hole-treatment) (Lines 127-155)
- [SIA Calculation](docs/SCRIPT_DETAILS.md#3-sea-ice-area-calculation-function) (Lines 38-54)

### Precipitation Script
- [Unit Conversion](docs/SCRIPT_DETAILS.md#2-unit-conversion) (Lines 103-108)
- [Grid Handling](docs/SCRIPT_DETAILS.md#3-adaptive-grid-coordinate-handling) (Lines 113-133)
- [Area Weighting](docs/SCRIPT_DETAILS.md#6-area-weighted-global-mean) (Lines 401-414)

### Temperature Script
- [Anomaly Calculation](docs/SCRIPT_DETAILS.md#5-anomaly-calculation) (Lines 194-202)
- [Monthly Climatology](docs/SCRIPT_DETAILS.md#4-monthly-climatology-calculation) (Lines 179-192)
- [Latitude Weighting](docs/SCRIPT_DETAILS.md#6-cosine-latitude-weighting) (Lines 213-227)

### SST Script
- [File Naming Convention](docs/SCRIPT_DETAILS.md#1-model-data-file-naming-convention) (Lines 71-85)
- [Volume Averaging](docs/SCRIPT_DETAILS.md#6-volume-averaged-temperature-calculation) (Lines 233-311)
- [SST Extraction](docs/SCRIPT_DETAILS.md#3-sst-extraction-from-3d-field) (Lines 142-155)

---

## 🎓 Learning Paths

### Path 1: Beginner (2-3 hours)
1. Read [QUICKSTART.md](docs/QUICKSTART.md) → 5 minutes
2. Run precipitation script → 15 minutes
3. Examine output files → 10 minutes
4. Read [README.md](README.md) main sections → 30 minutes
5. Try other scripts → 1 hour
6. Read [troubleshooting.md](docs/troubleshooting.md) → 30 minutes

### Path 2: Intermediate (1 day)
1. Complete Beginner path
2. Read [SCRIPT_DETAILS.md](docs/SCRIPT_DETAILS.md) → 2 hours
3. Modify script configurations → 1 hour
4. Run all scripts with different periods → 2 hours
5. Read [workflow_guide.md](docs/workflow_guide.md) → 1 hour

### Path 3: Advanced (1 week)
1. Complete Intermediate path
2. Deep dive into algorithms in [SCRIPT_DETAILS.md](docs/SCRIPT_DETAILS.md)
3. Customize scripts for specific needs
4. Create custom workflows
5. Optimize performance
6. Contribute improvements

---

## 🛠️ Common Tasks

### Configure and Run
1. [Choose a script](#choose-your-script)
2. [Configure paths](docs/QUICKSTART.md#step-3-configure-a-script)
3. [Run the script](docs/QUICKSTART.md#step-4-run-the-script)
4. [Check results](docs/QUICKSTART.md#step-5-check-results)

### Troubleshoot Issues
1. Check [Quick Reference](docs/troubleshooting.md#quick-reference-common-fixes)
2. Find your error in [Common Issues](docs/troubleshooting.md#common-issues)
3. Use [Debug Strategies](docs/troubleshooting.md#general-debugging-strategies)
4. Still stuck? [Get help](docs/troubleshooting.md#getting-additional-help)

### Modify Scripts
1. Understand [algorithm](docs/SCRIPT_DETAILS.md#critical-code-sections)
2. Check [customization examples](REPOSITORY_SUMMARY.md#customization-examples)
3. Test with small dataset
4. Validate results

---

## 📦 File Organization

```
Repository Root
├── README.md                    ← Start here for overview
├── REPOSITORY_SUMMARY.md        ← Technical summary
├── INDEX.md (this file)         ← Navigation guide
├── LICENSE                      ← MIT License
├── .gitignore                  ← Git configuration
│
├── scripts/                     ← Core NCL scripts
│   ├── diag_ice.ncl
│   ├── diag_precipitation.ncl
│   ├── diag_SAT.ncl
│   └── diag_SST.ncl
│
├── docs/                        ← Documentation
│   ├── QUICKSTART.md           ← 5-minute guide
│   ├── SCRIPT_DETAILS.md       ← Technical details
│   ├── troubleshooting.md      ← Problem solving
│   └── workflow_guide.md       ← Workflows
│
├── examples/                    ← Example outputs
│   ├── figures/
│   └── statistics/
│
└── .github/                     ← GitHub config
    └── workflows/
        └── documentation.yml
```

---

## 🔗 External Links

### NCL Resources
- [NCL Homepage](https://www.ncl.ucar.edu/)
- [NCL Functions](https://www.ncl.ucar.edu/Document/Functions/)
- [NCL Examples](https://www.ncl.ucar.edu/Applications/)
- [NCL Support Forum](https://www.ncl.ucar.edu/support.shtml)

### Climate Model Resources
- [CESM Documentation](https://www.cesm.ucar.edu/)
- [CMIP Information](https://www.wcrp-climate.org/wgcm-cmip)

### Observational Data
- [NOAA/NSIDC Sea Ice](https://nsidc.org/data/)
- [GPCP Precipitation](https://www.ncei.noaa.gov/products/global-precipitation-climatology-project)
- [Berkeley Earth Temperature](http://berkeleyearth.org/)
- [HadISST](https://www.metoffice.gov.uk/hadobs/hadisst/)

---

## 📧 Contact & Support

- **GitHub Issues:** Report bugs or request features
- **Documentation:** All guides in `docs/` folder
- **NCL Help:** [Official support page](https://www.ncl.ucar.edu/support.shtml)

---

## ✅ Quick Checklist

Before starting:
- [ ] NCL installed (`ncl -V`)
- [ ] Repository cloned
- [ ] Data files available
- [ ] Read QUICKSTART.md
- [ ] Configured at least one script

Ready to run:
- [ ] Paths configured correctly
- [ ] Output directory exists
- [ ] Time period valid
- [ ] Checked with `ncdump -h` for variables

After running:
- [ ] Check output directory
- [ ] Review statistics file
- [ ] Examine plots
- [ ] Document any issues

---

**Happy Analyzing! 🌍📊**

*Last Updated: January 14, 2025*
*Version: 1.0*
