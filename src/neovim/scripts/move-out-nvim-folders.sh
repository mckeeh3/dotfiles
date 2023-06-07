#!/bin/bash

# Check if the script parameter is empty
if [[ -z "$1" ]]; then
  echo "The nvim folder suffix name parameter is empty. Please provide a name for the renamed folders."
  exit 1
fi

# Get the script parameter
nvim_template_folder=$1

# Rename the folders
mv ~/.config/nvim ~/.config/nvim-"$nvim_template_folder"
mv ~/.local/share/nvim ~/.local/share/nvim-"$nvim_template_folder"
mv ~/.local/state/nvim ~/.local/state/nvim-"$nvim_template_folder"
mv ~/.cache/nvim ~/.cache/nvim-"$nvim_template_folder"

# Display a success message
echo "The folders have been renamed successfully."

