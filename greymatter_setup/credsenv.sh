source ./creds.sh

cat greymatter-secrets.yaml |\
  sed "s/^  email:/  email: ${DECIPHER_DOCKER_EMAIL}/" |\
  sed "s/^  username:/  username: ${DECIPHER_DOCKER_USER}/" |\
  sed "s/^  password:/  password: ${DECIPHER_DOCKER_PASSWORD}/" >\
  custom-greymatter-secrets.yaml

cat greymatter.yaml | sed s@openshift@kubernetes@ > custom-greymatter.yaml