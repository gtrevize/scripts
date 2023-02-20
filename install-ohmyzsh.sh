#!/bin/bash

echo "Updating packages"
sudo apt update

echo "Installing curl and git zsh"
sudo apt install curl git zsh neofetch -y

echo "Cloning Oh My zsh repo"
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

if [ -z "${ZSH_CUSTOM}" ]; then
	export ZSH_CUSTOM="~/.oh-my-zsh/custom"
fi

echo "Cloning PowerLevel10K theme repo"
git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

if [ -r ~/.zshrc ]; then
	/bin/rm ~/.zshrc 2> /dev/null
	/bin/mv ~/.zshrc ~/.zshrc.bak
fi

echo "Copying zsh config"
sh -c "$(curl -fsSL -o ~/.zshrc https://raw.githubusercontent.com/gtrevize/scripts/master/zshrc?token=GHSAT0AAAAAAB62RGRKDVM4NTXQJ2YQVSSGY7TYSSQ)"

if [ -r ~/.p10k.zsh.p10k.zs ]; then
	/bin/rm ~/.p10k.zsh 2> /dev/null
	/bin/mv ~/.p10k.zsh ~/.p10k.zsh.bak
fi

echo "Copying PowerLevel10K config"
sh -c "$(curl -fsSL -o ~/.p10k.zsh https://raw.githubusercontent.com/gtrevize/scripts/master/p10k.zsh?token=GHSAT0AAAAAAB62RGRK5BNP2LZDWCYPGZ42Y7TYQSQ)"





