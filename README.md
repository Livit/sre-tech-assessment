# sre-tech-assessment
SRE Technical Assessment

## Instructions
1. Fork this repository to your own account.
2. Read the requirements below fully and implement them in a PR for review.
3. Be sure to use best practices where applicable (i.e. proper commit messages, etc).
4. Send the link to the PR back to your contact here at Labster when it is complete.

## Requirements
- Deploy [this "Hello World!" sample ExpressJS application](https://expressjs.com/en/starter/hello-world.html) using your preferred lightweight Kubernetes distribution.
- Please create a helm chart for this deployment.
- Assume that this will be used by developers for local development purposes, and write clear setup documentation as part of your PR.

# Automatic local development
## What is this?
This is a tool developed with the objective of build and deploy a fully operational GitOps environment along with your
applications. It uses k3d, argoCD and helm in order to make the things work.

## How it works
The provided toolset will install K3d and deploy a single node Kubernetes cluster. It will also install ArgoCD. Then,
ArgoCD will deploy the application helm chart.

## Technologies
- **K3s:** K3s is a highly available, certified Kubernetes distribution designed for production workloads in unattended,
  resource-constrained, remote locations or inside IoT appliances.
- **K3d:** k3d is a lightweight wrapper to run k3s in docker.
- **Docker registry:** an internal registry to push the docker image build in your local machine
- **Nginx Ingress controller:** reverse proxy / load balancer to make the easier the ports/domains management.
- **ArgoCD:** A continuous deployment tool based on yaml files

## Requirements
In order to run the application properly, you will need the following:
- Bash
- [Docker](https://docs.docker.com/engine/install/). The process needs to be up and running before the execution.
- [Kubectl](https://docs.docker.com/engine/install/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [Helm](https://helm.sh/docs/intro/install/)

It should work in macOS, Linux and WSL2, but it has been tested only in macOS.

## How can I use it
The first step is cloning the repository. After that, be sure that the URL of your repository is in
```app/argocd/argoProject.yaml```, inside ```spec.sourceRepos``` field. If not, just add a new line with your URL.

After that, you are ready to go, so launch the ```setup.sh``` script inside ```cluster-setup``` folder (enter in inside
the folder before). This script will install everything needed.
_The script will ask for the root password in order to install K3d_

If everything goes well, you will be able to access to ```argo.localhost:8080``` (the script will print needed
credentials), and to ```labster-app.localhost:8080``` with you application up and running.

Once everything is running, just make changes inside your app and execute ```npm run deploy {version}``` where version
is any valid tag that you want. Semantic versioning (ex. 1.0.1) is heavily encouraged though. This will automatically
update the application in kubernetes.

Besides, k3d provides a fully operative kubernetes cluster, and the script has configured the access to it, so, if you 
want to play with it, just run ```kubectl get pods -A``` or the kubectl command that you want.

## What is happening under the hood?
```setup.sh``` Script install K3d with several addons like Docker registry, ArgoCD (that implies a lot of kubernetes
resources), Nginx Ingress controller replacing Traefik and serving as load balancer, An Argo project and an Argo App.

After installing ArgoCD, the project will be created inside it and the application will be linked to the remote helm chart
(the one located in GitHub). This time will be the only time that Argo looks the repository, next times, the local chart
will be used. This is a limitation caused by ArgoCD and there is no workaround for it.

Argo will deploy the mentioned helm chart, powered by a docker image previously created and pushed by the script.

The ```npm run deploy {version}``` command, will build and image of the app (using Dockerfile) and push to the internal
registry. It also will force a local sync to ArgoCD, using the local helm chart, allowing also testing kubernetes
resources.

## Known issues
- The evil Google Chrome something decide for you which protocol is better, so is not unusual to be redirected to an
  HTTPS path even in your localhost. So if, in any point you have problems that implies SSL certificate, be sure that
  you are accessing to an HTTP route, because nothing in the cluster uses HTTPS.

## TODO List
- The script and file structure needs a major reorganization in order to improve the readability. The script also needs
  better error handling.
- The version tagging should use a way to increment it automatically, but for this test, a manual way is enough.
- Helm chart should contain several configuration like limits, request, affinity and better probes, but it only makes
  sense with a real world application.
- Is technically possible to install the dependencies with the same script, but it would require a lot of effort.
- Provide a reliable way to delete the whole cluster in a single command.

## Why you should not use it in the real world (at enterprise level at least)
Although K3d is an amazing tool to run clusters (even in cloud) is not the right tool to deploy your application in a
local machine.

**The first reason talks about complexity.** Kubernetes (talking about the whole ecosystem, not only the cluster) is an
extremely complex tool that needs a lot of underlying tools to run your applications (nginx ingress controller, ArgoCD,
registry, among others). Using it in your local machines means that, if you have 200 developers in the company, you will
have, at least, 200 kubernetes cluster running along with things like Zoom, Visual Studio or any other applications,
making it hard to have a standard environment.

**The second problem is the flexibility.** Laptops are not scalable or replaceable (also at scale, are more expensive than
servers). Depending on the number of services and the size of them, you will run eventually out of memory. Also, share
your changes is possible but messier.
During this test, I avoided Jenkins intentionally because my laptop couldn't run a cluster with Jenkins an Argo at the
same time.

**The last one is the homogeneity.** Despite docker, kubernetes and so on do a great job in standardization, is matter of time
that the versions of the software diverged.