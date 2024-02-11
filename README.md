## Deploying AWS EKS cluster using Terraform and Jenkins
In this project, we explore the power of Infrastructure as Code tool, Terraform in seamlessly deploying infrastructure resources, helping us to reduce human errors while achieving greater agility, reliability and efficiency.
Firstly, we deploy Terraform code to create EC2 instance and deploy Jenkins on it. Next, we authenticate to our AWS aaccount through AWS CLI, then create a Jenkins pipeline to deploy EKS cluster.

## Step 1: Setup pre-requisites
Create an S3 bucket to serve as the remote backend. Having a remote backend to store terraform statefile, we eliminate possible conflict that could emanate from multiple modification of the file simultaneously as remote backend offers state locking which ensures only person makes changes to the terraform statefile at a time. Secondly, we create a key pair through the console which will be used to remotely access our EC2 instance

![Screenshot (356)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/ceaeff14-defb-4515-84ec-b157c89bf5ef)

![Screenshot (403)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/02f0f4a3-51ae-449e-a0b3-3431907e8235)

## Step 2: Authenticate to AWS, create Terraform code and execute terraform workflow to create instance and deploy Jenkins on it
With our credentials, ACCESS_KEY_ID and SECRET_ACCESS_KEY, we authenticate to AWS account using the command below:
```
aws configure
```

![Screenshot (357)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/5be4f57d-58e5-465f-873d-93cc32973119)

Terraform code to create instance and other dependent resources (VPC and Security Group). We will make use of existing modules where necessary

provider.tf (cloud provider in use)
```
provider "aws" {
  region = "us-east-1"
}
```

backend.tf (remote backend to store terraform statefile)

```
terraform {
  backend "s3" {
    bucket = "<bucket_name>"
    key    = "path-to-where-statefile-is-stored"
    region = "<region>"
  }
}
```

data.tf (instance details to be used)
```
data "aws_ami" "test" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "azs" {}
```

variables.tf (variables defined to be used)
```
variable "vpc_cidr" {
  description = "VPC CIDR"
  type = string
}

variable "public_subnets" {
  description = "Subnets CIDR"
  type = list(string)
}

variable "instance_type" {
  description = "Instance Type"
  type = string
}
```

terraform.tfvars (values of variables created)
```
vpc_cidr = "10.0.0.0/16"
public_subnets = [ "10.0.1.0/24" ]
instance_type  = "t3.small"
```

main.tf (main configuration file)
```
# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "jenkins-vpc"
  cidr = var.vpc_cidr

  azs = data.aws_availability_zones.azs.names
  public_subnets = var.public_subnets

  enable_dns_hostnames = true

  tags = {
    Name        = "jenkins-vpc"
    Terraform   = "true"
    Environment = "dev"
  }

  public_subnet_tags = {
    Name = "jenkins-subnet"
  }
}

# SG
module "sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "jenkins-sg"
  description = "Security Group for Jenkins Server"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "HTTP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Name = "jenkins-sg"
  }
}

# EC2
module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "Jenkins-Server"

  instance_type               = var.instance_type
  key_name                    = "jenkins-server-key"
  monitoring                  = true
  vpc_security_group_ids      = [module.sg.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = file("jenkins-install.sh")
  availability_zone           = data.aws_availability_zones.azs.names[0]

  tags = {
    Name        = "Jenkins-Server"
    Terraform   = "true"
    Environment = "dev"
  }
}
```

jenkins-install.sh (script to install jenkins, terraform, git and kubectl on server). This will be passed as user-data to be executed when instance is launched.
```
#!/bin/bash

# install jenkins
sudo yum update -y
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade -y
sudo amazon-linux-extras install java-openjdk11 -y
sudo yum install jenkins -y
sudo systemctl enable jenkins
sudo systemctl start jenkins

# then install git
sudo yum install git -y

#then install terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

#finally install kubectl
sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mkdir -p $HOME/bin && sudo cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
```
Run terraform workflow with the commands below:
```
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```
![Screenshot (358)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/e6eb19ef-218b-4880-bea1-f485f3899175)

![Screenshot (359)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/42a12e5a-6b38-4dc4-a980-7b02ac9b5ac7)

![Screenshot (360)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/2641c2c3-c3f9-46a2-90ba-8f59c284098c)

![Screenshot (361)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/d8baadf9-424c-475d-b343-0d278a8d1bc3)

![Screenshot (362)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/b0ad485d-29a3-44c6-aa80-ab75ff1296b2)

![Screenshot (363)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/ef565ec3-ec0d-4ac9-94b2-7bc1d4da9a39)

![Screenshot (364)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/97a7ae54-a649-4fb1-87e0-eb3e71b371ca)

![Screenshot (365)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/134ba8c4-8ec9-4337-8c4e-126f90194bb3)

![Screenshot (366)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/726f3089-e578-4100-8fbf-b9d6244a767a)

![Screenshot (367)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/0eee2ec5-d525-4946-84ca-a22ba679f681)

![Screenshot (375)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/66c227a7-713e-43ab-b280-0d5528739fff)

![Screenshot (376)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/baf7d6af-d8c6-4903-9af5-32327cec729b)

![Screenshot (377)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/d83e8336-b31a-4c8c-ac5f-83b5d11c9edc)

![Screenshot (378)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/f32d9f1a-219b-412a-a160-329fb56eff8e)

![Screenshot (379)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/acca5e1d-5651-4588-b8a4-c2285b563d61)

![Screenshot (380)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/c1c2ddfd-6648-49bf-bdec-07c03c6b4c96)

![Screenshot (381)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/5448e494-de03-40d2-b548-40e84633c642)

![Screenshot (382)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/f7cd1bbb-dcfd-43f1-9937-9143450e121e)

Thereafter, we view the resources deployed through the console

![Screenshot (383)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/efac9704-b73b-4aa3-8964-e9c06cb5420b)

![Screenshot (384)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/582b1c1a-a1ab-4067-9e45-c67f692c2846)

![Screenshot (385)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/7ea88971-f191-41c5-b3c2-6b2b1f7ed1fc)

## Step 3: Setup Jenkins and configure the pipeline to deploy EKS cluster
Here, we access jenkins UI using the server IP and port, login to the jenkins server, extract the initial admin password using the commands below and setup Jenkins
```
ssh -i <server_username>@<server_ip>
sudo cat var/lib/jenkins/secrets/initialAdminPassword
```

![Screenshot (387)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/0da188de-2a4d-4ead-8069-e9223f60f21c)

![Screenshot (388)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/c5570f6f-c2c3-4ce7-a6e6-e0842a57d87e)

## Configuring the jenkins pipeline
Firstly, we create a pipeline and generate a pipeline script to checkout of the repository

![Screenshot (390)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/60781d77-1766-4bf8-b382-e9870001a523)

![Screenshot (391)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/af4ead8b-2e3d-4fda-99e4-f9b3f45434e0)

Next, we parametrize the project. This allows us make a choice of actions during build process.

![Screenshot (393)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/da7b7b94-be60-435c-a5d0-3fe442f6dc5a)

Next, we add our credentials to Jenkins to enable Jenkins authenticate to the account successfully

![Screenshot (395)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/d79960b8-dfc7-4968-84f5-4fad10acf9bc)

Then, we create the terraform code to deploy EKS cluster

backend.tf (remote backend to store terraform statefile)
```
terraform {
  backend "s3" {
    bucket = "ci-cd-terraform-eks"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
```
data.tf (data source to fetch information about availability zones)
```
data "aws_availability_zones" "azs" {}
```

provider.tf (to indicate provider in use)
```
provider "aws" {
  region = "us-east-1"
}
```

variables.tf (variables defined)
```
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "private_subnets" {
  description = "Subnets CIDR"
  type        = list(string)
}

variable "public_subnets" {
  description = "Subnets CIDR"
  type        = list(string)
}
```

terraform.tfvars (values of variables defined)
```
vpc_cidr        = "192.168.0.0/16"
private_subnets = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
public_subnets  = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]
```
main.tf (main configuration file)
```
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = var.vpc_cidr

  azs = data.aws_availability_zones.azs.names

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb"               = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = 1
  }

}

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_type = ["t3.small"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

Next, we create the Jenkins pipeline script below that will execute the terraform code to deploy the cluster
```
pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = "us-east-1"
    }
    stages {
        stage('Checkout SCM'){
            steps{
                script{
                    checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/kenchuks44/Terraform-and-AWS-EKS.git']])
                }
            }
        }
        stage('Initializing Terraform'){
            steps{
                script{
                    dir('aws-eks'){
                        sh 'terraform init'
                    }
                }
            }
        }
        stage('Formatting Terraform Code'){
            steps{
                script{
                    dir('aws-eks'){
                        sh 'terraform fmt'
                    }
                }
            }
        }
        stage('Validating Terraform'){
            steps{
                script{
                    dir('aws-eks'){
                        sh 'terraform validate'
                    }
                }
            }
        }
        stage('Previewing the Infra using Terraform'){
            steps{
                script{
                    dir('aws-eks'){
                        sh 'terraform plan'
                    }
                    input(message: "Are you sure to proceed?", ok: "Proceed")
                }
            }
        }
        stage('Creating/Destroying an EKS Cluster'){
            steps{
                script{
                    dir('aws-eks') {
                        sh 'terraform $action --auto-approve'
                    }
                }
            }
        }
    }
}
```

Then, we input the script into the pipeline

![Screenshot (399)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/e332961b-a3ec-4139-a00a-43231c467213)

Then, we run the build process to create the cluster

![Screenshot (396)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/b1f7e09c-793a-4507-aca0-a4be2a587836)

![Screenshot (401)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/99cc43b2-8fd8-4c85-a88d-615d84f67ca9)

![Screenshot (400)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/7351701b-0c56-4bde-a19f-5b8401adc355)

We then view the cluster created through the console

![Screenshot (397)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/7668474f-2d7b-4c8f-a3b5-a0e8a30d461f)

![Screenshot (398)](https://github.com/kenchuks44/Deploying-EKS-cluster-using-Terraform-and-Jenkins/assets/88329191/f7973a75-26e1-4b3f-98c2-66231beb8a7d)

Voila!!! We have successfully provisioned infrastructure resources automatically using Terraform and Jenkins. With these tools, we can seamlessly replicate this setup, thereby eliminating possible human errors, maintain infrastructure configurations, leading to more reliable and predictable infrastructure deployments.















































