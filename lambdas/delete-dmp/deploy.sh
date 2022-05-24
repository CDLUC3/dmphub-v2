LAMBDA_NAME=`basename \`pwd\``

echo "Building $LAMBDA_NAME ..."

# Delete the old zip
rm ../build/${LAMBDA_NAME}.zip

# Run bundler
bundle config --local path 'vendor/bundle'
bundle install
bundle update

# Zip it up
zip -r ../build/${LAMBDA_NAME}.zip lambda_function.rb vendor

# Deploy zip to S3
echo "Deploying $LAMBDA_NAME to the AWS S3 bucket"
aws s3 cp ../build/${LAMBDA_NAME}.zip s3://uc3-dmp-hub-cf-bucket/lambdas/
