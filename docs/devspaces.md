# Using DevSpaces
When developing microservices it is sometimes critical to test whole solution, but creating complete environment for each developer is resource intensive, time consuming and publishing changes is not quick enough. This can be solved with AKS DevSpaces. There is share cluster with baseline of all microservices. Developer can change single microservice he is working on, it gets deployed and routing in cluster is configured so he can use all baseline services, but his dev version of microservice. Other developers are routed to baseline version. With that each developer can work on his own microservice without breaking environment for others.

Also DevSpaces are building app directly in container so it is very fast to publish and test changes without need to go throw pipelines and container builds. This makes things much faster and lowers overhead on CI/CD pipeline systems and container registry.

DevSpaces is solution design to work before developer commits code and before CI/CD process kicks in.

# Table of Contents

- [Using DevSpaces](#using-devspaces)
- [Table of Contents](#table-of-contents)
- [Build dev cluster for DevSpaces](#build-dev-cluster-for-devspaces)
- [Deploy application baseline](#deploy-application-baseline)
- [Changing one of microservices](#changing-one-of-microservices)

# Build dev cluster for DevSpaces
DevSpaces currently does not support some of enterprise features such as RBAC or policies, but this is often not required for dev stage (as opposed to test, uat, pre-prod or prod that all should be handled via CI/CD pipelines).

Let's build dev cluster and enable DevSpaces.

```bash
cd devspaces
az group create --name devspaces --location westeurope
az aks create -g devspaces \
  -n aksdevspaces \
  --location westeurope \
  --disable-rbac \
  -x \
  -c 2 \
  -s Standard_B2ms
az aks use-dev-spaces -g devspaces -n aksdevspaces
```

Install [VS Code DevSpaces extension](https://marketplace.visualstudio.com/items?itemName=azuredevspaces.azds)

# Deploy application baseline
Move to frontend folder and prepare DevSpaces. This generates Dockerfile, Helm chart and azds.yaml with DevSpaces configuration to enable continuous build.

```bash
cd frontend
azds prep --public
azds up
```

Last command also prints public endpoint URL on which we can access our frontend.

You may now change code in server.js to return different string. Pres CTRL+C do terminate azds up and run azds up again. This will rebuild container and publish new version.

We can also leverage debugging and live change capabilities of Dev Spaces extension for VS Code. Open new VS Code window in frontend folder and use CTRL+SHIFT+P to select Prepare configuration files for Azure Dev Spaces. Now you can go to debug section of VS Code including breakpoints. If you change code now Dev Spaces will push it to running container without need to go throw rebuild cycle.

Let's deploy service backendA

```bash
cd ../backendA
azds prep
azds up -d
```

Go back to frontend in your browser. Message should now return hello from both frontend and backend service.

# Changing one of microservices
We now have baseline services up and running. Suppose developer tomas now need to play with backend service and test it in context of other services in their baseline version. Tomas should see baseline frontend and his own backend while default user should still see baseline versions of services.

Create new devspace with existing default devspace as root.

```bash
azds space select --name tomas
```

Make code change in backend service and up it.

```bash
azds up -d
```

Go to browser and access default devspace version of your frontend such as http://default.frontend.something.weu.azds.io/ and you should still see unmodified messages. Default devspace is still routed to baseline version of backend service.

Get tomas devspace URIs.

```bash
azds list-uris
```

Open frontend URI for tomas devspace such as http://tomas.s.default.frontend.something.weu.azds.io/

Note you are now routed to modified version of backend service.

Do not need tomas devspace any more? Remove it.

```bash
azds space remove --name tomas -y
```



