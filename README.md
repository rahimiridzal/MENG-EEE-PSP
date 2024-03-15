# MENG-EEE-PSP
Project repository for Power System Planning module at Imperial College London

## Description
This repository contains all the necessary code and data to reproduce the results obtained in "Cost Mitigation of VRE-based Systems using Long Duration Energy Storage".

## Folder Structure

1. **data**:
   - `vreinfo.csv`: Cleaned data about variable renewable energy (VRE) sources.
   - `generatorinfo.csv`: Cleaned data about conventional generators.
   - `storageinfo.csv`: Cleaned data about long duration energy storage (LDES).
   - `halfhourlydemand.csv`: Cleaned half-hourly demand data.
   - `halfhourlyvrecf.csv`: Cleaned half-hourly VRE capacity factors.

2. **raw**:
   - `demanddata_2015.csv`: Raw half-hourly demand data.
   - `ninja_pv_country_GB_merra-2_corrected.csv`: Raw solar data from renewables.ninja.
   - `ninja_wind_country_GB_current-merra-2_corrected.csv`: Raw wind data from renewables.ninja.

## Code Files

- `CEM.jl`: Julia script containing two functions `CEM()` and `CEMnoLDES()` for analysis.
- `book1_res.ipynb`: Jupyter notebook for simulating Operation Cost under different Reserve Requirements. Two cases are considered: Case 1 with no storage using `CEMnoLDES()` and Case 2 with storage using `CEM()`.
- `book2_eff.ipynb`: Jupyter notebook for simulating the Efficiency of selected LDES versus Operation Cost. It uses the `CEM()` model based on Case 2 "all" scenario from `book1_res.ipynb`.

## References

- [National Grid ESO](https://www.nationalgrideso.com/)
- [Renewables.ninja](https://www.renewables.ninja)
- Powering Up Britain: Energy Security Plan (2023). Policy paper. Updated 4 April 2023.
- Sepulveda, N.A., Jenkins, J.D., Edington, A. et al. "The design space for long-duration energy storage in decarbonized power systems." *Nat Energy* 6, 506–516 (2021). [https://doi.org/10.1038/s41560-021-00796-8](https://doi.org/10.1038/s41560-021-00796-8)
- Grubb, M., Ferguson, T., Musat, A., Maximov, S., Zhang, Z., Price, J., & Drummond, P. (2022). "Navigating the crises in European energy: Price Inflation, Marginal Cost Pricing, and principles for electricity market redesign in an era of low-carbon transition." UCL Institute for Sustainable Resources, Navigating the Energy-Climate Crises Working Paper #3, 5 September 2022.
- "Electricity Generation Costs" (2023). Technical Annex: Additional LCOE estimates for generation technologies. © Crown copyright 2023. [https://www.gov.uk/government/publications/electricity-generation-costs-2023](https://www.gov.uk/government/publications/electricity-generation-costs-2023)