
BASE_LAMBDA_PATH=$(pwd)/lambdas
echo ""
echo "BASE LAMBDA PATH: $BASE_LAMBDA_PATH"

for d in $BASE_LAMBDA_PATH/*/
do
  cd $d
  LAMBDA_NAME=$(basename `pwd`)
  echo "  - $LAMBDA_NAME"

  if [ -e Dockerfile ]; then
    # Build an image tag based on the name of the lambda and the 1st 7 characters of the latest
    # git commit for the lambda for example: '9e74454:=latest-get-dmp'
    IMAGE_TAG="$(git log --format="%H" -n 1 ./ | cut -c 1-7):=latest-$LAMBDA_NAME"

    echo "    Building Docker image, $IMAGE_TAG, and publishing to ECR ..."
    docker build -t "$SHORT_ECR_URI:latest-$LAMBDA_NAME" .
    docker tag "$ECR_REPOSITORY_URI:latest-$LAMBDA_NAME" $SHORT_ECR_URI:$IMAGE_TAG
    docker push "$SHORT_ECR_URI:latest-$LAMBDA_NAME"
    docker push $SHORT_ECR_URI:$IMAGE_TAG
  else
    echo "    No Dockerfile detecte."
  fi

  echo ""
  cd $BASE_LAMBDA_PATH
done

echo "DONE"
