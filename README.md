## Deploying AWS EKS cluster using Terraform and Jenkins
In this project, we explore the power of Infrastructure as Code tool, Terraform in seamlessly deploying infrastructure resources, helping us to reduce human errors while achieving greater agility, reliability and efficiency.
Firstly, we deploy Terraform code to create EC2 instance and deploy Jenkins on it. Next, we authenticate to our AWS aaccount through AWS CLI, then create a Jenkins pipeline to deploy EKS cluster.

## Step 1: Setup pre-requisites
Create an S3 bucket to serve as the remote backend. Having a remote backend to store terraform statefile, we eliminate possible conflict that could emanate from multiple modification of the file simultaneously as remote backend offers state locking which ensures only person makes changes to the terraform statefile at a time
