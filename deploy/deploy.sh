#!/bin/bash

source parameters

# DELETE OLD STACK IF EXIST ON CTRL+C
trap "echo; echo \"DELETING THE STACK\"; bash destroy.sh -e ${Env} -p ${Project} -t ${Target} -g ${GitUsername}; exit" INT

# GET SECTRETS
AcmArn=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.AcmArn')
SesArn=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.SesArn')
HostedZoneId=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.HostedZoneId')

# GET URL FROM S3 AND SET VARIABLES
aws s3 cp ${Urls} ./urls.json
AuthUrl=$(cat urls.json | jq ".auth.${Env}" | tr -d '"')

CognitoUrl=${AuthUrl}
if [ "$Env" = "dev" ]; then
	CognitoUrl=$(echo ${AuthUrl/__username__/$GitUsername})
fi

Parameters="ParameterKey=URI,ParameterValue=${URI} ParameterKey=Url,ParameterValue=${CognitoUrl} ParameterKey=SesArn,ParameterValue=${SesArn}"
sam build -t ./template.yml --parameter-overrides ${Parameters}
sam deploy \
	--template-file .aws-sam/build/template.yaml \
	--stack-name ${URI} \
	--disable-rollback \
	--resolve-s3 \
	--parameter-overrides ${Parameters} --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	--tags project=${Project} env=${Env} creator=${GitUsername}

if [ "$Env" = "dev" ]; then
	CognitoUserPoolID=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='CognitoUserPoolID'].OutputValue" --output text)
	CognitoAppClientID=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='CognitoAppClientID'].OutputValue" --output text)

	AdministrationPath=../../Administration/
	cp ${AdministrationPath}.env ${AdministrationPath}.env.development
	echo "" >>${AdministrationPath}.env.development
	echo "Project=${Project}" >>${AdministrationPath}.env.development
	echo "" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${AdministrationPath}.env.development

	CpPath=../../CP/
	echo "" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${CpPath}.env.local

	AppPath=../../App/
	echo "" >>${AppPath}.env.local
	echo "REACT_APP_AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${AppPath}.env.local
	echo "REACT_APP_AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${AppPath}.env.local
fi
