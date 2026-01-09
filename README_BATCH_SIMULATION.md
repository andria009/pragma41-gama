# Batch Simulation Guide

## Overview
The model now includes a **batch_simulation** experiment that automatically runs multiple simulations with different parameter combinations to find the optimal and worst-case scenarios for evacuation planning.

## How to Run

1. Open the model file `models/model1.gaml` in GAMA
2. Select the **batch_simulation** experiment (instead of main or limited_info)
3. Click the "Run" button
4. Wait for all simulations to complete

## Parameters Tested

The batch simulation will automatically test all combinations of:
- **Number of shelters**: 1 to 100 (step: 1) = 100 values
- **Flood speed**: 0.1 to 5.0 km/h (step: 0.1) = 49 values
- **Flood direction**: bottom, top, left, right = 4 values

**Total simulations**: 100 × 49 × 4 = **19,600 simulations**

## Output

### Console Report
At the end of all simulations, you'll see a summary report showing:
- **Best Configuration** (minimum casualties) with:
  - Number of shelters
  - Flood speed
  - Flood direction
  - Number of casualties and survivors
  - Survival rate percentage

- **Worst Configuration** (maximum casualties) with the same metrics

### CSV File
All simulation results are saved to `results/simulation_results.csv` with columns:
- nb_shelters
- flood_speed
- flood_direction
- nb_casualties
- nb_survivors
- survival_rate (%)

You can analyze this file in Excel, Python, or R for deeper insights.

## Performance Note

Running 19,600 simulations will take considerable time depending on your computer's performance.
Each simulation runs until either:
- All people reach shelters or die
- The flood covers the entire simulation area

## Customizing the Batch

To modify the parameter ranges, edit lines 308-310 in `model1.gaml`:

```gaml
parameter "Number of shelters" var: nb_shelters min: 1 max: 100 step: 1;
parameter "Flood speed (km/h)" var: flood_speed min: 0.1 max: 5.0 step: 0.1;
parameter "Flood direction" var: flood_direction among: ["bottom", "top", "left", "right"];
```

For faster testing, you can:
- Increase the step size (e.g., `step: 5` for shelters, `step: 0.5` for flood speed)
- Reduce the max values
- Comment out one parameter to fix its value

## Analysis Tips

After running the batch simulation, you can:
1. Sort the CSV by casualties to see the full ranking
2. Plot survival rate vs. number of shelters to find the optimal shelter count
3. Analyze which flood direction causes the most casualties
4. Create heat maps showing the relationship between parameters
5. Calculate the point of diminishing returns for adding more shelters
