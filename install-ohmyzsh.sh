#!/bin/bash

echo "Updating packages"
apt update

echo "Installing curl and git zsh"
apt install curl git zsh neofetch -y

echo "Cloning Oh My zsh repo"
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

echo "Cloning PowerLevel10K theme repo"
git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

echo "Copying zsh config"


