- [CI/CD with Jenkins and Helm](#cicd-with-jenkins-and-helm)
    - [Install Jenkins to cluster via Helm](#install-jenkins-to-cluster-via-helm)
    - [Configure Jenkins and its pipeline](#configure-jenkins-and-its-pipeline)
    - [Run "build"](#run-build)

# CI/CD with Jenkins and Helm
In this demo we will see Jenkins deployed into Kubernetes via Helm and have Jenkins Agents spin up automatically as Pods.

CURRENT ISSUE: at the moment NodeSelector for agent does not seem to be delivered to Kubernetes cluster correctly. Since our cluster is hybrid (Linux and Windows) in order to work around it now we need to turn of Windows nodes.

## Install Jenkins to cluster via Helm
```
helm install --name jenkins stable/jenkins -f jenkins-values.yaml
```

## Configure Jenkins and its pipeline
Use this as pipeline definition
```
podTemplate(label: 'mypod') {
    node('mypod') {
        stage('Do something nice') {
            sh 'echo something nice'
        }
    }
}

```

## Run "build"
Build project in Jenkins and watch containers to spin up and down.
```
kubectl get pods -o wide -w
```
