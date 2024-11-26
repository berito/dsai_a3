# Cardiac Electrophysiology Simulation - parallelization
# using OpenMP and MPI

## Overview
This project implements the **Cardiac Electrophysiology Simulation** in  parallel versions using OpenMP and MPI. The performance analysis evaluates execution time under different configurations.

---

## Compilation
To compile the code, run:
```bash
make clean
make 
```
## Running the Code

### Serial Execution
Run the serial version with:
```bash
./build/life_serial -n <grid_size> -i <iterations> -p 0.2 -d
```
### parallel Execution
Run the parallel version with:
```bash
./build/life_parallel -n <grid_size> -i <iterations> -p 0.2 -d
```
- `<grid_size>`: The size of the grid (e.g., 500 for a 500x500 grid).
- `<iterations>`: The number of iterations to execute.
- `-p 0.2`: The probability for initializing cells as "alive" (e.g., 20%).
- `-d`: Disables the GUI display for performance measurement.

## Performance Analysis
To automate performance testing and analyze results:
```bash
./run_life <serial/parallel>

```
- `<serial/parallel>`: Specify whether to analyze the serial or parallel version.

The script runs the program under different configurations and saves the results to a CSV file.

### Output Files
- `data/data_serial.csv`: Contains results from the serial version.
- `data/data_parallel.csv`: Contains results from the parallel version.

### To visualize, run:
```bash
python plot.py <parallel/serial>

```




