# Cognito

Cognito Cloud Formation for AWS deploy

```sh
cd deploy && bash deploy.sh -e [ENV]
```

If "dev" env create cognito user pool with standard domain with git username:

- https://[AuthUrl].auth.$[AWS_DEFAULT_REGION].amazoncognito.com
- es: https://auth-ecotrip-brteo.auth.eu-west-1.amazoncognito.com

Otherwise create cognito with custom domain name and dns record set

- [staging] https://auth.staging.ecotrip.meblabs.dev
- [production] https://auth.ecotrip.meblabs.dev

**IMPORTANT**: The App must be deployed before cognito because the custom url require a root url set on DNS as record A

## Seed

To seed admin@meblabs.com as verified user into Cognito User Pool:

```sh
cd deploy && bash seed.sh -e [ENV]
```
