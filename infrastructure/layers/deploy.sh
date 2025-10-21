#!/usr/bin/env bash

# Unfortunately CloudFormation doesn't support creating new versions with keeping the old versions.
# There are different tools to handle this and retain previous versions, but we want to stay CloudFormation native.
# So this script checks if there is an existing version of the LambdaLayer already in this account.
# Creates a new stack if missing or creates a new version of the Layer.
# In order to know the latest version of the Layer, use this helper script when deploing Lambdas:
# https://github.com/sosw/sosw-examples/tree/master/helpers/sosw_layers_version_changer
# Simply hook running this script in the directory of the Lambda that you are deploying.

set -e

# Change ACCOUNT_ID and S3 bucket name appropriately.
ACCOUNT_ID=`aws sts get-caller-identity|grep "Account"|awk -F '"' '{print $4}'`
BUCKET_NAME="app-control-$ACCOUNT_ID"
RUNTIMES="python3.10 python3.11 python3.12 python3.13"
NAME=sosw
GITHUB_ORGANIZATION=$NAME
PROFILE=default

HELPMSG="USAGE: ./deploy.sh [-v branch] [-p profile]
Deploys $NAME layer. Installs $NAME from latest pip version, or from a specific branch if you use -v.\n
Use -p in case you have specific profile (not the default one) in you .aws/config with appropriate permissions.\n
Use -r if case you want to install without the custom packages and only sosw."

while getopts ":v:p:rh" option
do
    case "$option"
    in
        v) VERSION=$OPTARG;;
        p) PROFILE=$OPTARG;;
        r) RAW=true;;
        h|*) echo -e "$HELPMSG";exit;;
    esac
done


# Install package with respect to the rule of Lambda Layers:
# https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html

if [[ ${VERSION} ]]; then
    echo "Deploying a specific version from branch: $VERSION"
    pip3 install git+https://github.com/GITHUB_ORGANIZATION/$NAME.git@$VERSION --no-dependencies -t $NAME/python/
else
    VERSION="stable"
    pip3 install $NAME --no-dependencies -t $NAME/python/
fi

if [ ! $RAW ]; then
  echo "Packaging other (non-sosw) reqired libraries"
  pip3 install aws_lambda_powertools -t $NAME/python/
  pip3 install aws_xray_sdk -t $NAME/python/
  pip3 install bson --no-dependencies -t $NAME/python/
  pip3 install requests -t $NAME/python/;
fi

echo "Generated a random suffix for file name."
FILE_NAME=$NAME-$VERSION-$RANDOM

zip_path="/tmp/$FILE_NAME.zip"
stack_name="layer-$NAME"

echo "Packaging..."
if [ -f "$zip_path" ]
then
    rm $zip_path
    echo "Removed the old package."
fi

cd $NAME
zip -qr $zip_path *
cd ..
echo "Created a new package in $zip_path."


if ! aws cloudformation describe-stacks --stack-name layer-sosw;
then
  aws s3 cp $zip_path s3://$BUCKET_NAME/lambda_layers/ --profile $PROFILE
  echo "Uploaded $zip_path to S3 bucket to $BUCKET_NAME."

  aws s3 cp $NAME/$NAME.yaml s3://$BUCKET_NAME/lambda_layers/$FILE_NAME.yaml --profile $PROFILE
  echo "Uploaded $NAME/$FILE_NAME.yaml to S3 bucket to $BUCKET_NAME."


  echo "Deploying new stack $stack_name with CloudFormation"
  aws cloudformation package --template-file $NAME/$NAME.yaml --output-template-file deployment-output.yaml \
      --s3-bucket $BUCKET_NAME --profile $PROFILE
  echo "Created package from CloudFormation template"

  echo "Calling for CloudFormation to deploy"
  aws cloudformation deploy --template-file ./deployment-output.yaml --stack-name $stack_name \
      --parameter-overrides FileName=$FILE_NAME.zip \
      --capabilities CAPABILITY_NAMED_IAM --profile $PROFILE;

else
  echo "Publishing  new version of layer $NAME with code from $zip_path"
  aws lambda publish-layer-version --layer-name $NAME --zip-file fileb://$zip_path --compatible-runtimes $RUNTIMES
fi