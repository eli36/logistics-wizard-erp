#!/bin/bash
echo Login IBM Cloud api=$CF_TARGET_URL org=$CF_ORG space=$CF_SPACE
bx login -a "$CF_TARGET_URL" --apikey "$IAM_API_KEY" -o "$CF_ORG" -s "$CF_SPACE"

# The branch may use a custom manifest
MANIFEST=manifest.yml
if [ -f ${REPO_BRANCH}-manifest.yml ]; then
  MANIFEST=${REPO_BRANCH}-manifest.yml
fi
echo "Using manifest file: $MANIFEST"

# and a prefix for dev branch services
if [ "$REPO_BRANCH" == "dev" ]; then
  PREFIX=$REPO_BRANCH"-"
  echo "Using prefix: $PREFIX"
else
  echo "No prefix for non-dev branch"
  PREFIX=""
fi

bx service create cloudantNoSQLDB Lite ${PREFIX}logistics-wizard-erp-db

# create the database
bx service key-create ${PREFIX}logistics-wizard-erp-db for-pipeline
CLOUDANT_URL=`bx service key-show ${PREFIX}logistics-wizard-erp-db for-pipeline | grep "\"url\"" | awk '{print $2}' | tr -d '","'`
curl -s -X PUT $CLOUDANT_URL/logistics-wizard | grep -v file_exists

if ! bx app show $CF_APP; then
  bx app push $CF_APP -n $CF_APP -f ${MANIFEST}
else
  OLD_CF_APP=${CF_APP}-OLD-$(date +"%s")
  rollback() {
    set +e
    if bx app show $OLD_CF_APP; then
      bx app logs $CF_APP --recent
      bx app delete $CF_APP -f
      bx app rename $OLD_CF_APP $CF_APP
    fi
    exit 1
  }
  set -e
  trap rollback ERR
  bx app rename $CF_APP $OLD_CF_APP
  bx app push $CF_APP -n $CF_APP -f ${MANIFEST}
  bx app delete $OLD_CF_APP -f
fi
