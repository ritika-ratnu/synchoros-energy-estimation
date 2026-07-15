
## Synchoros Input testcase format

Each testcase contains:

- **`SiLagoBlocks/`**: Block description with path for resource and valid neighbour configuration.
- **`Operations/`**: Operation description and their resource bindings.
- **`Resources/`**: Resource description.
- **`ValidNeighbourDesigns/`**: Minimal abutted designs for each valid neighbour configuration.

The input files are organised into three directories:

1) SiLagoBlocks: JSON files to define different SiLago blocks with its resources and valid neighbour configurations.

2) Operations: JSON file to define the operation of the block in a specific valid neighbour configurations.

3) ValidNeighbourDesigns: RTL, Netlist and GDSII files for minimal designs with valid neighbour configurations.
