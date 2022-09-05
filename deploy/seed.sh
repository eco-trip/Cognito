#!/bin/bash

source parameters

CognitoUserPoolID=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='CognitoUserPoolID'].OutputValue" --output text)
CognitoAppClientID=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='CognitoAppClientID'].OutputValue" --output text)

aws cognito-idp sign-up \
	--region ${AWS_DEFAULT_REGION} \
	--client-id ${CognitoAppClientID} \
	--username admin@meblabs.com \
	--password Testtest1! \
	--user-attributes Name=email,Value=admin@meblabs.com Name=name,Value=Admin Name=family_name,Value=Istrator

aws cognito-idp admin-confirm-sign-up \
	--region ${AWS_DEFAULT_REGION} \
	--user-pool-id ${CognitoUserPoolID} \
	--username admin@meblabs.com
