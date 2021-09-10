# Simple Queue

This microservice architecture contains three services: 

1) gateway - this is the api gateway to the task queue from which one can add a task to the queue or query the numebr of tasks remaining in the queue
	This is a flask application with two paths: 
		- '/add' - this adds a task to the queue
		- '/get' - this returns the number of tasks remaining in the queue

2) rabbitmq service - the official rabbitmq docker container

3) processFromQ - this service accepts tasks from the queue, sleeps for 2 seconds, and repeats

To deploy make a project on GCP (Google Cloud Provider).

Navigate to `terraform-config/provision-gke-cluster/terraform.tfvars`. Replace the values in this terraform.tfvars file with your project_id and region. Terraform will use these values to target your project when provisioning your resources. Your terraform.tfvars file should look like the following.
```
# terraform.tfvars
project_id = "REPLACE_ME"
region     = "us-central1"
```

After you have saved your customized variables file, from within the `provision-gke-cluster` directory, initialize your Terraform workspace using `terraform init`, which will download the provider and initialize it with the values provided in your terraform.tfvars file.

```
$ terraform init

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/google from the dependency lock file
- Installing hashicorp/google v3.52.0...
- Installed hashicorp/google v3.52.0 (signed by HashiCorp)

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

# Provision the GKE Cluster

Still within the `terraform-config/provision-gke-cluster` directory, run terraform apply and review the planned actions. Your terminal output should indicate the plan is running and what resources will be created.

```
$ terraform apply
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

## Output truncated ...

Plan: 4 to add, 0 to change, 0 to destroy.

## Output truncated ...
```

This terraform apply will provision a VPC, subnet, GKE Cluster and a GKE node pool. Confirm the apply with a yes.

This process should take approximately 10 minutes. Upon successful application, your terminal prints the outputs defined in vpc.tf and gke.tf.

# Deploy Microservice Queue via Terraform

Navigate to the `deploy-queue-kubernetes` directory. From within the directory, run terraform init. Then run terraform apply. Confirm the apply with a yes.

```
$ terraform apply

## Output truncated ...

kubernetes_service.gateway: Creating...
kubernetes_service.rabbit: Creating...
kubernetes_deployment.process: Creating...
kubernetes_deployment.rabbit: Creating...
kubernetes_deployment.gateway: Creating...

## Output truncated ...

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

gateway_ip = "34.75.212.7"
```

This creates 3 deployments: gateway, process, and rabbit. It also creates 2 services - one to provide internal access to the rabbitmq container and one to provide an external endpoint to access the gateway service.

The docker images are pulled from my docker hub registry.

In your browser, navigate to gateway_ip:5000. In the above example, this is `34.75.212.7:5000`.

Two buttons should be displayed. Press them accordingly.

Note: My implementation allows for the consumer to receive up to two unacknowledged messages at once. Therefore, if two messages are sent successively and the number of tasks in the queue is queried, the amount returned will be 0. If three messages are sent successively and the number of tasks in the queue is checked, the amount will be 1.

# Clean up

From within the `deploy-queue-kubernetes` directory, run `terraform destroy`. Confirm the destroy with a yes. Once this has completed, navigate to the `provision-gke-cluster` directory and run `terraform destroy`. Confirm the destroy with a yes.

# Basic Kubernetes Deployment via yaml

I have also provided the deployments in the form of a yaml file. This can be deployed on any kuberentes host as follows:
```
soclof@cloudshell:~$ kubectl apply -f queue.yaml
service/rabbit created
deployment.apps/rabbit created
service/gateway created
deployment.apps/gateway created
deployment.apps/process created
```

The yaml file pulls the docker images from my docker hub. The docker containers can also be built from the dockerfiles in the repositories.

I personally deployed the services on a GKE cluster on a cluster with default settings.

To find the ip address through which to access the application:

```
soclof@cloudshell:~$ kubectl get service gateway
NAME      TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)          AGE
gateway   LoadBalancer   10.8.0.118   23.236.50.63   5000:30865/TCP   77s
```

In the above example, the application is running at `23.236.50.63:5000`.

Open `23.236.50.63:5000/` in a browser. Two buttons should be displayed. Press them accordingly.

Sources: https://learn.hashicorp.com/tutorials/terraform/gke?in=terraform/kubernetes, https://learn.hashicorp.com/tutorials/terraform/kubernetes-provider?in=terraform/kubernetes




