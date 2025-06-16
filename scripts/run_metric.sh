#!/bin/bash
# Read dwi from inputs/ and write metric to outputs/
# Metric is read from environment variable METRIC

set -e

echo "Running BeyondFA axial diffusivity ..."
echo "Listing /input..."
ls /input
echo "Listing /input/*..."
ls /input/*
echo "Listing /output..."
ls /output/

# Define metric
metric="ad"

# Find all dwi.mha files in /input
dwi_mha_files=$(find /input/images/dwi-4d-brain-mri -name "*.mha")

for dwi_mha_file in $dwi_mha_files; do
    # Set up file names
    json_file="/input/dwi-4d-acquisition-metadata.json"

    basename=$(basename $dwi_mha_file .mha)
    bval_path="/tmp/${basename}.bval"
    bvec_path="/tmp/${basename}.bvec"
    nifti_file="/tmp/${basename}.nii.gz"
    output_name="/output/features-128.json"

    # Convert dwi.mha to nii.gz
    echo "Converting $dwi_mha_file to $nifti_file..."
    python convert_mha_to_nifti.py $dwi_mha_file $nifti_file

    # Convert json to bval and bvec
    echo "Converting $json_file to $bval_path and $bvec_path..."
    python convert_json_to_bvalbvec.py $json_file $bval_path $bvec_path

    # Define output directory
    output_dir="/tmp/tractseg_ad_output"
    mkdir -p $output_dir

    # Create mask, response, FODs, and peaks
    tractseg_dir="${output_dir}/${basename}/tractseg"
    mkdir -p $tractseg_dir

    echo "Creating mask, response, FODs, and peaks..."
    dwi2mask $nifti_file $tractseg_dir/nodif_brain_mask.nii.gz -fslgrad $bvec_path $bval_path
    dwi2response fa $nifti_file $tractseg_dir/response.txt -fslgrad $bvec_path $bval_path

    dwi2fod csd $nifti_file $tractseg_dir/response.txt $tractseg_dir/WM_FODs.nii.gz -mask $tractseg_dir/nodif_brain_mask.nii.gz -fslgrad $bvec_path $bval_path
    sh2peaks $tractseg_dir/WM_FODs.nii.gz $tractseg_dir/peaks.nii.gz -mask $tractseg_dir/nodif_brain_mask.nii.gz -fast

    # Run TractSeg
    echo "Running TractSeg..."
    TractSeg -i $tractseg_dir/peaks.nii.gz  -o $tractseg_dir --bvals $bval_path --bvecs $bvec_path --keep_intermediate_files --brain_mask $tractseg_dir/nodif_brain_mask.nii.gz

    # Run AD calculation
    ad_dir="${output_dir}/${basename}/metric"
    mkdir -p $ad_dir
    echo "Calculating DTI metrics..."
    scil_dti_metrics.py --not_all --mask $tractseg_dir/nodif_brain_mask.nii.gz \
        --ad $ad_dir/ad.nii.gz $nifti_file $bval_path $bvec_path -f

    # Get corresponding metrics
    echo "Calculating average $metric metric in bundles..."
    bundle_roi_dir="${tractseg_dir}/bundle_segmentations"
    metric_dir=${ad_dir}

    # Make json with json["ad"]["mean"] = mena of ad in bundle
    roi_list=$(find $bundle_roi_dir -name "*.nii.gz" | sort)
    for roi in $roi_list; do
        bundle_name=$(basename $roi .nii.gz)
        echo "Calculating $metric in $bundle_name..."

        # Is sum of mask > 0?
        mask_sum=$(fslstats $roi -V | awk '{print $1}')
        if [ $mask_sum -eq 0 ]; then
            echo "$bundle_name,0" >> ${output_dir}/tensor_metrics.json
        else
            mean_metric=$(fslstats $ad_dir/$metric.nii.gz -k $roi -m)
            echo "$bundle_name,$mean_metric" >> ${output_dir}/tensor_metrics.json
        fi
    done
    # scil_volume_stats_in_ROI.py --metrics_dir ${ad_dir} $roi_list > ${output_dir}/tensor_metrics.json

    # Extract specified metric to JSON
    echo "Extracting $metric metrics to $output_dir..."
    python extract_metric.py ${output_dir}/tensor_metrics.json $output_dir/ad.json

    # Save the final metric.json to output directory
    echo "$metric metrics saved to $output_name"
    mv $output_dir/ad.json $output_name

done
