#!/bin/zsh

# Check if an input file is provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

echo "Splitting input file into left, right, and audio intermediate files. This will re-encode them and take up a lot of disk space!"

input_file="$1"
base_name="${input_file%.*}"
audio_intermediate_file="${base_name}_audio.m4a"
left_intermediate_file="${base_name}_left_eye.mov"
right_intermediate_file="${base_name}_right_eye.mov"
mv_hevc_intermediate_file="${base_name}_MV-HEVC.mp4"
output_file="${base_name}_Spatial_Video.mp4"

# Extract and encode the left eye view
ffmpeg -y -i $input_file -vf "stereo3d=sbs2l:ml,format=yuv420p10le" -c:v prores_videotoolbox -v:profile 3 $left_intermediate_file -vf "stereo3d=sbs2l:mr,format=yuv420p10le" -c:v prores_videotoolbox -v:profile 3 $right_intermediate_file  -map 0:a -vn -sn -c:a aac_at -b:a 384k $audio_intermediate_file

echo "Splitting complete. Output files: $audio_intermediate_file, $left_intermediate_file, $right_intermediate_file. Using video files to create MV-HEVC..."

spatial-media-kit-tool merge --left-file "$left_intermediate_file" --right-file "$right_intermediate_file" --quality 50 --left-is-primary --horizontal-field-of-view 65 --horizontal-disparity-adjustment 200 --output-file "$mv_hevc_intermediate_file"

echo "Encoding MV-HEVC complete. Output file: $mv_hevc_intermediate_file. Remuxing audio back in..."

mp4box -add "$mv_hevc_intermediate_file" -add "$audio_intermediate_file" "$output_file"

echo "Success! Output is $output_file. Deleting all other created intermediate files now..."

rm $audio_intermedia_file $left_intermediate_file $right_intermediate_file $mv_hevc_intermediate_file

echo "Cleanup complete! Enjoy your spatial video!"
