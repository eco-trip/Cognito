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

if [ "$Env" = "dev" ]; then
	CognitoUrl=$(echo ${AuthUrl/__username__/$GitUsername})

	# create cognito with non custom url
	Parameters="ParameterKey=URI,ParameterValue=${URI} ParameterKey=Url,ParameterValue=${CognitoUrl} ParameterKey=SesArn,ParameterValue=${SesArn}"
	sam build -t ./cognito.yml -b .aws-sam/cognito/ --parameter-overrides ${Parameters}
	sam deploy \
		--template-file .aws-sam/cognito/template.yaml \
		--stack-name ${URI} \
		--disable-rollback \
		--resolve-s3 \
		--parameter-overrides ${Parameters} --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--tags project=${Project} env=${Env} creator=${GitUsername}

	CognitoDomainUrl="https://${CognitoUrl}.auth.${AWS_DEFAULT_REGION}.amazoncognito.com"
	echo ${CognitoDomainUrl}

	CognitoUserPoolID=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='CognitoUserPoolID'].OutputValue" --output text)
	CognitoAppClientID=$(aws cloudformation describe-stacks --stack-name ${URI} --query "Stacks[0].Outputs[?OutputKey=='CognitoAppClientID'].OutputValue" --output text)

	AdministrationPath=../../Administration/
	cp ${AdministrationPath}.env ${AdministrationPath}.env.development
	echo "" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_URL=${CognitoDomainUrl}" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${AdministrationPath}.env.development
	echo "AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${AdministrationPath}.env.development

	CpPath=../../CP/
	echo "" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_URL=${CognitoDomainUrl}" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_USER_POOL_ID=${CognitoUserPoolID}" >>${CpPath}.env.local
	echo "REACT_APP_AWS_COGNITO_CLIENT_ID=${CognitoAppClientID}" >>${CpPath}.env.local
else
	CognitoUrl=${AuthUrl}

	#create cognito
	Parameters="ParameterKey=URI,ParameterValue=${URI} ParameterKey=Url,ParameterValue=${CognitoUrl} ParameterKey=SesArn,ParameterValue=${SesArn} ParameterKey=AcmArn,ParameterValue=${AcmArn}"
	sam build -t ./cognito.yml -b .aws-sam/cognito/ --parameter-overrides ${Parameters}
	sam deploy \
		--template-file .aws-sam/cognito/template.yaml \
		--stack-name ${URI} \
		--disable-rollback \
		--resolve-s3 \
		--parameter-overrides ${Parameters} \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--tags project=${Project} env=${Env} creator=${GitUsername}

	#get cloudfront distribution for cognito custom domain (in cloud formation can't retrive it)
	CognitoCFD=$(aws cognito-idp describe-user-pool-domain --domain ${CognitoUrl} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE} | jq -r '.DomainDescription.CloudFrontDistribution')
	CognitoDnsURI=${URI}-dns

	#create dns record for cognito custom domain
	Parameters="ParameterKey=Url,ParameterValue=${CognitoUrl} ParameterKey=CognitoCFD,ParameterValue=${CognitoCFD} ParameterKey=HostedZoneId,ParameterValue=${HostedZoneId}"
	sam build -t ./cognito_dns.yml -b .aws-sam/cognito_dns/ --parameter-overrides ${Parameters}
	sam deploy \
		--template-file .aws-sam/cognito_dns/template.yaml \
		--stack-name ${CognitoDnsURI} \
		--disable-rollback \
		--resolve-s3 \
		--parameter-overrides ${Parameters} \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--tags project=${Project} env=${Env} creator=${GitUsername}
fi
