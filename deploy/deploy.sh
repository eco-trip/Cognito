#!/bin/bash

source parameters

# DELETE OLD STACK IF EXIST ON CTRL+C
trap "echo; echo \"DELETING THE STACK\"; bash destroy.sh -e ${Env} -p ${Project} -t ${Target} -g ${GitUsername}; exit" INT

# GET SECTRETS
AcmArn=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.AcmArn')
SesArn=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.SesArn')
HostedZoneId=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.HostedZoneId')
AWS_ACCESS_KEY_ID=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.AWS_SECRET_ACCESS_KEY')

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
	echo "" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${AdministrationPath}.env.development

	CpPath=../../CP/
	echo "" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${CpPath}.env.local

	UserPoolIoT=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='UserPoolIoT'].OutputValue" --output text)
	UserPoolClientIot=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientIot'].OutputValue" --output text)
	IdentityPoolIot=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='IdentityPoolIot'].OutputValue" --output text)
	MQTT_ID=$(echo ${Secrets} | jq .SecretString | jq -rc . | jq -rc '.MQTT_ID')

	AppPath=../../App/
	echo "" >>${AppPath}.env.local
	echo "REACT_APP_AWS_COGNITO_USER_POOL_ID=${UserPoolIoT}" >>${AppPath}.env.local
	echo "REACT_APP_AWS_COGNITO_CLIENT_ID=${UserPoolClientIot}" >>${AppPath}.env.local
	echo "REACT_APP_AWS_IDENTITY_POOL_ID=${IdentityPoolIot}" >>${AppPath}.env.local
	echo "REACT_APP_MQTT_ID=${MQTT_ID}" >>${AppPath}.env.local
	echo "REACT_APP_AWS_REGION=${AWS_DEFAULT_REGION}" >>${AppPath}.env.local
fi
