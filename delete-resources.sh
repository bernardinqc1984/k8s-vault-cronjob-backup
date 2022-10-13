#!/usr/bin/env bash

export NAMESPACE=vault
export BUCKET_NAME=PUT_YOUR_BUCKET_NAME # Replace here with what you want to use for your bucket name
export REGION=ap-northeast-2
export AWS_PROFILE_NAME=EXAMPLE # Replace here with your AWS_PROFILE_NAME here
export AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity \
 --profile $AWS_PROFILE_NAME | jq -r '.Account')
export POLICY_ARN="arn:aws:iam::$AWS_ACCOUNT_NUMBER:policy/vault-snapshot-agent"

kubectl delete secret vault-snapshot-agent-token -n $NAMESPACE
kubectl delete secret aws-secret -n $NAMESPACE

aws s3 rb s3://$BUCKET_NAME \
    --profile $AWS_PROFILE_NAME \
    --force \
    --no-cli-pager

aws iam list-access-keys \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --no-cli-pager | jq -r '.AccessKeyMetadata[].AccessKeyId' | xargs -I {} aws iam delete-access-key \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --access-key-id {} \
    --no-cli-pager

aws iam detach-user-policy \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --policy-arn $POLICY_ARN

# aws iam delete-access-key \
#     --profile $AWS_PROFILE_NAME \
#     --user-name vault-snapshot-agent

aws iam delete-user \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --no-cli-pager

aws iam delete-policy \
    --profile $AWS_PROFILE_NAME \
    --policy-arn $POLICY_ARN \
    --no-cli-pager