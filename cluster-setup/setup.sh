#!/usr/bin/env bash

# Install K3d, do nothing if present
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

ARGO_DOMAIN="argo.localhost"
APP_DOMAIN="labster-app.localhost"
DOCKER_REGISTRY_DOMAIN="registry.localhost"
# Some MacOS stuff is deployed in port 5000, so we need to change it
DOCKER_REGISTRY_PORT="5050"
IMAGE_NAME="labster-hello-world"

KUBECTL_PATH=$(which kubectl)
K3D_PATH=$(which k3d)
DOCKER_PATH=$(which docker)
ARGOCD_PATH=$(which argocd)

# It would be cool to have a cache registry, but looks like there are conflicts using 2 different registries in k3d.
# Needs research
# docker run -d --name registry -p 5060:5000 -e REGISTRY_PROXY_REMOTEURL="https://registry-1.docker.io" registry:2

# Create our internal registry.
${K3D_PATH} registry create ${DOCKER_REGISTRY_DOMAIN} --port ${DOCKER_REGISTRY_PORT}

# Deploy cluster, load balancer, registry and replace traefik with nginx
${K3D_PATH} cluster create local-development --k3s-arg "--disable=traefik@server:0" \
  --volume "$(pwd)/ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/ingress-nginx.yaml" \
  --port 8080:80@loadbalancer \
  --port 8443:443@loadbalancer \
  --registry-use k3d-${DOCKER_REGISTRY_DOMAIN}:${DOCKER_REGISTRY_PORT} \

${KUBECTL_PATH} config set-context local-development
${KUBECTL_PATH} get nodes

# Create some namespaces for ArgoCD and the App. The names are not modifiable
${KUBECTL_PATH} create namespace argocd
${KUBECTL_PATH} create namespace dev

# Create hosts entries to avoid problem with the ingress and redirections. In linux this step is not needed due to
# anything exposed under localhost will resolve in the same way.
# TODO: Implement this in a better way with a loop.
if  grep -q "127.0.0.1 ${ARGO_DOMAIN}" "/etc/hosts" ; then
  echo "The hosts are already in place" ;
else
  echo "127.0.0.1 ${ARGO_DOMAIN}" | sudo tee -a /etc/hosts
  echo "127.0.0.1 ${APP_DOMAIN}" | sudo tee -a /etc/hosts
  echo "127.0.0.1 k3d-${DOCKER_REGISTRY_DOMAIN}" | sudo tee -a /etc/hosts
fi

# Install ArgoCD
${KUBECTL_PATH} apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Argo is deploying..."
${KUBECTL_PATH} wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -A --timeout 600s
${KUBECTL_PATH} wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -A --timeout 600s

while [ -z "$matched" ]
do
  echo "Waiting for secret argocd-initial-admin-secret"
  matched=$(${KUBECTL_PATH} get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" --ignore-not-found=true)
  sleep 5;
done

echo "You can access it in ${ARGO_DOMAIN}:8080"
echo "With the following credentials:"
echo "User: admin"
ARGO_PASSWORD=$(${KUBECTL_PATH} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Password: ${ARGO_PASSWORD}"

# This block will fix the redirection loop that argoCD cause when you run in localhost using the installation script without certificate.
# You can find part of this fix in https://github.com/argoproj/argo-cd/issues/2953#issuecomment-905294537
${KUBECTL_PATH} delete -A ValidatingWebhookConfiguration ingress-controller-nginx-ingress-nginx-admission
${KUBECTL_PATH} apply -n argocd -f argocd-ingress.yaml -n argocd
${KUBECTL_PATH} apply -n argocd -f argocd-config.yaml -n argocd
${KUBECTL_PATH} rollout restart deployment argocd-server -n argocd

# Wait until everything is ready and deploy the application
${DOCKER_PATH} build ../app -t k3d-${DOCKER_REGISTRY_DOMAIN}:${DOCKER_REGISTRY_PORT}/${IMAGE_NAME}:1.0.0
${DOCKER_PATH} push k3d-${DOCKER_REGISTRY_DOMAIN}:${DOCKER_REGISTRY_PORT}/${IMAGE_NAME}:1.0.0

${KUBECTL_PATH} apply -f ../app/argocd/argoProject.yaml -n argocd
${KUBECTL_PATH} apply -f ../app/argocd/argoApp.yaml -n argocd

${KUBECTL_PATH} wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -A --timeout 600s
${KUBECTL_PATH} wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -A --timeout 600s

${ARGOCD_PATH} login ${ARGO_DOMAIN}:8080 --username admin --password ${ARGO_PASSWORD} --insecure --plaintext --grpc-web --http-retry-max 10
${ARGOCD_PATH} app sync labster-app --local ../chart/labster-hello-world --insecure --plaintext --grpc-web --http-retry-max 10

