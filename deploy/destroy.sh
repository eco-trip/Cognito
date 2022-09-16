#!/bin/bash

read -p "Destroy everything? [y/N]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	exit
fi

# LOAD PARAMETERS
source parameters

if [ "$Env" = "production" ]; then
	read -p "Are you sure? " -n 1 -r
	echo
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
	fi
fi

# COGNITO
sam delete \
	--stack-name ${URI} \
	--no-prompts \
	--region ${AWS_DEFAULT_REGION}
