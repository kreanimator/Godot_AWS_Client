# PowerShell version of deploy.sh for Windows
# Deploys sosw layer to AWS

param(
    [string]$Version = "stable",
    [string]$Profile = "default",
    [switch]$Raw = $false,
    [switch]$Help
)

if ($Help) {
    Write-Host "USAGE: .\deploy.ps1 [-Version branch] [-Profile profile] [-Raw] [-Help]"
    Write-Host "Deploys sosw layer. Installs sosw from latest pip version, or from a specific branch if you use -Version."
    Write-Host "Use -Profile in case you have specific profile (not the default one) in you .aws/config with appropriate permissions."
    Write-Host "Use -Raw if case you want to install without the custom packages and only sosw."
    exit
}

# Get AWS Account ID
$accountId = (aws sts get-caller-identity --query Account --output text)
$bucketName = "app-control-$accountId"
$runtimes = "python3.10,python3.11,python3.12,python3.13"
$name = "sosw"
$githubOrganization = $name

Write-Host "Deploying sosw layer for account: $accountId"

# Install sosw package
if ($Version -ne "stable") {
    Write-Host "Deploying a specific version from branch: $Version"
    pip install "git+https://github.com/$githubOrganization/$name.git@$Version" --no-dependencies -t "$name/python/"
} else {
    Write-Host "Installing stable version"
    pip install $name --no-dependencies -t "$name/python/"
}

if (-not $Raw) {
    Write-Host "Packaging other (non-sosw) required libraries"
    pip install aws_lambda_powertools -t "$name/python/"
    pip install aws_xray_sdk -t "$name/python/"
    pip install bson --no-dependencies -t "$name/python/"
    pip install requests -t "$name/python/"
}

# Generate random suffix for file name
$randomSuffix = Get-Random
$fileName = "$name-$Version-$randomSuffix"
$zipPath = "$env:TEMP\$fileName.zip"
$stackName = "layer-$name"

Write-Host "Packaging..."

# Remove old package if exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath
    Write-Host "Removed the old package."
}

# Create zip file using PowerShell
Set-Location $name
Compress-Archive -Path * -DestinationPath $zipPath -Force
Set-Location ..

Write-Host "Created a new package in $zipPath."

# Check if stack exists
$stackExists = $false
try {
    aws cloudformation describe-stacks --stack-name "layer-$name" --profile $Profile 2>$null
    if ($LASTEXITCODE -eq 0) {
        $stackExists = $true
    }
} catch {
    $stackExists = $false
}

if (-not $stackExists) {
    Write-Host "Uploading to S3 bucket: $bucketName"
    aws s3 cp $zipPath "s3://$bucketName/lambda_layers/" --profile $Profile
    Write-Host "Uploaded $zipPath to S3 bucket to $bucketName."

    aws s3 cp "$name/$name.yaml" "s3://$bucketName/lambda_layers/$fileName.yaml" --profile $Profile
    Write-Host "Uploaded $name/$fileName.yaml to S3 bucket to $bucketName."

    Write-Host "Deploying new stack $stackName with CloudFormation"
    aws cloudformation package --template-file "$name/$name.yaml" --output-template-file "deployment-output.yaml" --s3-bucket $bucketName --profile $Profile
    Write-Host "Created package from CloudFormation template"

    Write-Host "Calling for CloudFormation to deploy"
    aws cloudformation deploy --template-file "./deployment-output.yaml" --stack-name $stackName --parameter-overrides "FileName=$fileName.zip" --capabilities CAPABILITY_NAMED_IAM --profile $Profile
} else {
    Write-Host "Publishing new version of layer $name with code from $zipPath"
    aws lambda publish-layer-version --layer-name $name --zip-file "fileb://$zipPath" --compatible-runtimes $runtimes --profile $Profile
}

Write-Host "Deployment completed!"
