#!/bin/bash

# Check if the ~/.config/nvim folder exists
if [[ -d ~/.config/nvim ]]; then
  echo "The ~/.config/nvim folder already exists. Please delete this folder before moving the nvim-<nvim_template_name> folders back."
  exit 1
fi

# Get the nvim_template_name
nvim_template_name=$1

# Move the folders back
mv ~/.config/nvim-"$nvim_template_name" ~/.config/nvim
mv ~/.local/share/nvim-"$nvim_template_name" ~/.local/share/nvim
mv ~/.local/state/nvim-"$nvim_template_name" ~/.local/state/nvim
mv ~/.cache/nvim-"$nvim_template_name" ~/.cache/nvim

# Display a success message
echo "The folders have been moved back successfully."

