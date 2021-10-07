IMAGE_TAG=$1
DOCKER_PATH=$(which docker)
ARGOCD_PATH=$(which argocd)
KUBECTL_PATH=$(which kubectl)

ARGO_PASSWORD=$(${KUBECTL_PATH} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

ARGO_DOMAIN="argo.localhost"
APP_DOMAIN="labster-app.localhost"
DOCKER_REGISTRY_DOMAIN="registry.localhost"
# Some MacOS stuff is deployed in port 5000, so we need to change it
DOCKER_REGISTRY_PORT="5050"
IMAGE_NAME="labster-hello-world"

# Build and deploy the application
# A quick shortcut to speed up the deploy operation
sed -i "" "/^\([[:space:]]*appVersion: \).*/s//\1$1/" ../chart/labster-hello-world/Chart.yaml
${DOCKER_PATH} build ../app -t k3d-${DOCKER_REGISTRY_DOMAIN}:${DOCKER_REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}
${DOCKER_PATH} push k3d-${DOCKER_REGISTRY_DOMAIN}:${DOCKER_REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}
${ARGOCD_PATH} login ${ARGO_DOMAIN}:8080 --username admin --password ${ARGO_PASSWORD} --insecure --plaintext --grpc-web --http-retry-max 10
${ARGOCD_PATH} app sync labster-app --force --local ../chart/labster-hello-world --insecure --plaintext --grpc-web --http-retry-max 10
