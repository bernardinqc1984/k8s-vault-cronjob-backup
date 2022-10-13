#!/usr/bin/env bash

export NAMESPACE=vault
export BUCKET_NAME=PUT_YOUR_BUCKET_NAME # Replace here with what you want to use for your bucket name
export REGION=ap-northeast-2
export AWS_PROFILE_NAME=EXAMPLE # Replace here with your AWS_PROFILE_NAME here

## Create S3 Bucket for raft snapshot which is created by vault snapshot agent
aws s3api create-bucket \
    --profile $AWS_PROFILE_NAME \
    --region $REGION \
    --bucket $BUCKET_NAME \
    --create-bucket-configuration LocationConstraint=$REGION \
    --acl private \
    --no-cli-pager

## S3 Public Access Block Configuration
aws s3api put-public-access-block \
    --profile $AWS_PROFILE_NAME \
    --region $REGION \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --no-cli-pager

## Create IAM Policy for access to S3 Bucket which is for raft snapshot
POLICY_ARN=$(
    aws iam create-policy \
    --profile $AWS_PROFILE_NAME \
    --policy-name vault-snapshot-agent \
    --policy-document \
    --no-cli-pager \
"{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Effect\": \"Allow\",
            \"Action\": [
                \"s3:PutObject\",
                \"s3:GetObject\",
                \"s3:ListBucket\"
            ],
            \"Resource\": [
                \"arn:aws:s3:::$BUCKET_NAME\",
                \"arn:aws:s3:::$BUCKET_NAME/*\"
            ]
        }
    ]
}" | jq -r .Policy.Arn)

## Create IAM User for access to S3 Bucket which is for raft snapshot
aws iam create-user \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --tags Key=Name,Value=vault-snapshot-agent \
    --no-cli-pager

## Attach IAM Policy to IAM User
aws iam attach-user-policy \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --policy-arn $POLICY_ARN \
    --no-cli-pager

## Temporarily save ACCESS_KEY as shell variable
ACCESS_KEY=$(aws iam create-access-key \
    --profile $AWS_PROFILE_NAME \
    --user-name vault-snapshot-agent \
    --no-cli-pager)

## Extract ACCESS_KEY_ID and SECRET_ACCESS_KEY from ACCESS_KEY
export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKey.AccessKeyId' <<< $ACCESS_KEY)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.AccessKey.SecretAccessKey' <<< $ACCESS_KEY)
export AWS_DEFAULT_REGION=$REGION

## Create kubernetes secret for vault snapshot agent
kubectl create secret generic aws-secret -n $NAMESPACE \
    --from-literal=AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --from-literal=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --from-literal=AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
