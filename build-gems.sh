
BASE_GEM_PATH=$(pwd)/gems
echo ""
echo "BASE GEM PATH: $BASE_GEM_PATH"

for d in $BASE_GEM_PATH/*/
do
  cd $d
  GEM_NAME=$(basename `pwd`)

  # Fetch the local and latest remote version numbers
  VERSION_PATH="${GEM_NAME/-//}"
  REMOTE_VERSION=$(gem list $GEM_NAME -r | grep $GEM_NAME | grep -Eo '[0-9\.]+')
  LOCAL_VERSION=$(cat lib/$VERSION_PATH/version.rb| grep 'VERSION' | grep -Eo '[0-9\.]+')

  echo "  - $GEM_NAME -- Local version: $LOCAL_VERSION, Remote version: $REMOTE_VERSION"

  # If the gem has not been published yet, or the local version is greater than the
  # Rubygems version, then build it and push it to Rubygems
  if [ -z $REMOTE_VERSION ] || [ $LOCAL_VERSION \> $REMOTE_VERSION ]; then
    echo "    New version detected ... publishing $GEM_NAME - $LOCAL_VERSION"
    echo ""
    echo $(gem build $GEM_NAME.gemspec)
    echo ""
    echo $(gem push `$Gem_NAME-$LOCAL_VERSION.gem` --key $RUBYGEMS_API_KEY)
  fi
  echo ""
  cd $BASE_GEM_PATH
done

echo "DONE"
