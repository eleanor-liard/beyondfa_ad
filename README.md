# Beyond FA: axial diffusivity

### **AD (Axial Diffusivity)**

AD corresponds to the **principal eigenvalue**:

$$
\text{AD} = \lambda_1
$$

It captures diffusion **along the primary fiber direction** and is used as a marker for **axonal integrity**.

* **Decreased AD** may indicate **axonal injury**, for example after trauma or in neurodegenerative conditions.

## Building the Docker
To build this Docker container, clone the repository and run the following command in the root directory:

```bash
DOCKER_BUILDKIT=1 sudo docker build -t beyondfa_da3 .
```

The Docker runs the code from `scripts/entrypoint.sh`.

## Running the Docker

Your Docker container should be able to read input data from `/input` and write output data to `/output`. Intermediate data should be written to `/tmp`. The input data will be a `.mha` file containing the diffusion MRI data with gradient table information contained in a `.json` file. The input file will be in `/input/images/dwi-4d-brain-mri/`, with gradient table information at `/input/dwi-4d-acquisition-metadata.json`. Your Docker should write a JSON list to the output directory with the name `/output/features-128.json`. **Your JSON list must contain 128 values. You may zero-pad the list if you wish to provide fewer than 128 values.**

See `scripts/convert_mha_to_nifti.py` and `scripts/convert_json_to_bvalbvec.py` for scripts to convert the `.mha` to `.nii.gz` and the `.json` to `.bval` and `.bvec` files.

To run this Docker:

```bash
#!/bin/bash

input_dir=".../input_data"
output_dir=".../output_data"
DOCKER_NOOP_VOLUME="beyondfa_da3-volume"

# Ensure output directory exists
mkdir -p "$output_dir"

# Recreate clean temp volume
sudo docker volume rm "$DOCKER_NOOP_VOLUME" > /dev/null 2>&1
sudo docker volume create "$DOCKER_NOOP_VOLUME" > /dev/null

# Run container
sudo docker run \
    -it \
    --platform linux/amd64 \
    --network none \
    --gpus all \
    --rm \
    --volume "$input_dir":/input:ro \
    --volume "$output_dir":/output \
    --volume "$DOCKER_NOOP_VOLUME":/tmp \
    beyondfa_da3

# Fix permissions on output
sudo chmod -R 777 "$output_dir"

```

