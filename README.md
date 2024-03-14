# MENG-EEE-PSP
Project repository for Power System Planning module at Imperial College London

## Description
This repository contains all the necessary code and data to reproduce the results obtained in "Assessing the Economic Potential of Long Duration Energy Storage in VRE-based Power Systems".

## Data Description

The GB historical demand data from National Grid ESO, and historical wind and solar data from Renewables Ninja for 2015 are used for the case study. The capacity of wind and solar are adopted from the Powering Up Britain - Energy Security Plan. The sources of other relevant data are listed in the references.

## Data Files
- "generatorinfo.csv":  This file contains information about power generators such as their unique ID, name, minimum power output rate, fixed and variable operating costs, and ramp-up and ramp-down rates.
- "storageinfo.csv": This file contains information about storage technologies such as their unique ID, name, associated costs for power and energy under best and worst-case scenarios, and efficiency, also under best and worst-case scenarios.
- "vreinfo.csv": This file contains information about variable renewable energy (VRE) such as their unique ID, name, installed power capacity (MW), and, fixed and variable operating costs.
- "halfhourlydemand.csv": This file contains the historical half-hourly demand of Great Britain in 2015.
- "halfhourlyvrecf.csv": This file contains the historical half-hourly capacity factor of solar, onshore, and offshore wind of Great Britain in 2015. Note that the data is extended from hourly data obtained from Renewable Ninja.

## Notebooks
- "



