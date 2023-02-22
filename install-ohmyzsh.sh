#!/bin/bash

#set -x

ZSH_HOME="${HOME}/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_HOME}/custom"
ZSH_CONFIG="${HOME}/.zshrc"
P10K_THEME="${ZSH_CUSTOM}/themes/powerlevel10k"
P10K_CONFIG="${HOME}/.p10k.zsh"

BACKUP_DATE=`date +%m-%d-%Y_%M-%S` 
BACKUP_ZUFFIX="${BACKUP_DATE}.bak"

function checkSudo () {
	let responseOk=0
	while [ $responseOk -eq 0 ]
	do
		RESPONSE=""
		echo -n -e "Do you have access to 'sudo'? (Y)es / [N]o / (A)bort: \c"
		read -r RESPONSE
		case "${RESPONSE^^}" in
			"Y")
				echo -e "Will attempt package installation and shell assignment"
				let responseOk=1
				;;
		
			"N" | "")
				echo -e "Skipping package installation and shell assignment"
				let responseOk=1
				return 1
				;;
				
			"A")
				echo "Aborting"
				#set +x
				exit 1
				;;
				
			*)
				echo -e "\tInvalid response, please try again"
				;;
		esac
	done
	
	echo
	
	return 0
}

function checkIfExists () {
	FILE_OR_DIR=${1}
	BACKUP_FILE_OR_DIR=${1}_${BACKUP_ZUFFIX}

	if [ -d ${FILE_OR_DIR} ] || [ -f ${FILE_OR_DIR} ]; then
		[ -d "${FILE_OR_DIR}" ] && PATH_TYPE="dir"
		[ -f "${FILE_OR_DIR}" ] && PATH_TYPE="file"
		let responseOk=0
		while [ $responseOk -eq 0 ]
		do
			echo -n -e "\t${FILE_OR_DIR} ${PATH_TYPE} exists. Do you want to replace it? (Y)es / [N]o / (B)ackup / (A)bort: \c"
			RESPONSE=""
			read -r RESPONSE
			case "${RESPONSE^^}" in
				"Y")
					echo -e "\tDeleting '${FILE_OR_DIR}' ${PATH_TYPE}" ; /bin/rm -rf "${FILE_OR_DIR}" 2>&1 1> /dev/null
					let responseOk=1
					;;
					
				"B")
					echo -e "\tRenaming '${FILE_OR_DIR}' ${PATH_TYPE} to '${BACKUP_FILE_OR_DIR}'" ; /bin/mv  "${FILE_OR_DIR}"  "${BACKUP_FILE_OR_DIR}" 2>&1 1> /dev/null
					let responseOk=1
					;;
					
					
				"N" | "")
					echo -e "\tKeeping existing version of '${FILE_OR_DIR}'"
					return 1
					;;
					
				"A")
					echo "Aborting"
					#set +x
					exit 1
					;;
					
				*)
					echo -e "\tInvalid response, please try again"
					;;
			esac
		done
	fi
	
	return 0
}

function checkExec () {
	EXEC_PATH=`which $1`
	if [ -z "S{EXEC_PATH}" ] ; then
		return 1
	fi
	
	if [ -x "S{EXEC_PATH}" ] ; then
		return 1
	fi
	
	return 0
}

function checkDependencies () {
	for e in "$@" 
	do
		if checkExec $e ; then
			echo -e "\tFound executable $e"
		else
			echo -e "\tERROR: ${1} is needed and is not installed or is not executable. Can't continue"
			exit 5
		fi
	done
}

if checkSudo ; then
	echo "Checking dependencies that run using sudo"
	checkDependencies usermod
	echo
	
	echo "Updating packages"
	sudo apt update
	echo

	echo "Checking and installing if necessary:  curl, git, zsh, neofetch"
	sudo apt install curl git zsh neofetch -y
	echo

	echo "Setting zsh as the default shell"
	if sudo usermod -s /bin/zsh ${USER} ; then
		echo "Shell changed to /bin/zsh"
	else
		echo "ERROR: Couldn't change the shell to /bin/zsh. Skipping"
	fi
fi
echo

echo "Checking dependencies"
checkDependencies zsh curl git neofetch
echo

echo "Checking if OhMyzsh is installed"
if checkIfExists ${ZSH_HOME} ; then
	echo -e "\tCloning Oh My zsh repo"
	sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi
echo

echo "Checking if zsh is configured"
if checkIfExists ${ZSH_CONFIG} ; then
	echo -e "\tCopying zsh config"
	curl -fsSL 'https://raw.githubusercontent.com/gtrevize/scripts/master/zshrc' -o ${ZSH_CONFIG}
fi
echo

echo "Checking if PowerLevel10K is installed"
if checkIfExists ${P10K_THEME} ; then
	echo -e "\tCloning PowerLevel10K theme repo"
	git clone https://github.com/romkatv/powerlevel10k.git ${P10K_THEME}
fi
echo

echo "Checking if PowerLevel10K is configured"
if checkIfExists ${P10K_CONFIG} ; then
	echo -e "\tCopying PowerLevel10K config"
	curl -fsSL 'https://raw.githubusercontent.com/gtrevize/scripts/master/p10k.zsh' -o ${P10K_CONFIG}
fi

echo -e "\nDone. Exit and reload your shell"
echo

#set +x

exit 0
