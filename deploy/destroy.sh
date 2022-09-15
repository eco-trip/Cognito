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
if [ "$Env" != "dev" ]; then
	# destroy cognito dns if not dev env
	CognitoDnsURI=${URI}-dns
	sam delete \
		--stack-name ${CognitoDnsURI} \
		--no-prompts \
		--region ${AWS_DEFAULT_REGION}

	# manual delete user pool custom domain before remove cognito
	aws s3 cp ${Urls} ./urls.json
	AuthUrl=$(cat urls.json | jq ".auth.${Env}" | tr -d '"')
	UserPoolId=$(aws cognito-idp describe-user-pool-domain --domain ${AuthUrl} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE} | jq -r '.DomainDescription.UserPoolId')
	aws cognito-idp delete-user-pool-domain \
		--domain ${AuthUrl} \
		--user-pool-id ${UserPoolId} \
		--region ${AWS_DEFAULT_REGION} \
		--profile ${AWS_PROFILE}
fi

sam delete \
	--stack-name ${URI} \
	--no-prompts \
	--region ${AWS_DEFAULT_REGION}
