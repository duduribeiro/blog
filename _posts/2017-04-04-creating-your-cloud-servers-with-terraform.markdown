---
title: "Creating your cloud servers with Terraform"
layout: post
date: 2017-04-04 12:00:00 -0300
image: /assets/images/terraforming_mars.jpeg
headerImage: true
tag:
- cloud
- aws
- terraform
category: blog
author: dudribeiro
description: "Sometimes when you handle a lot of servers in the cloud, it is pretty easy to get lost on your infrastructure. “Where is that freaking server that I can’t find?”, or even “Why is this instance for?”. In this post, I will introduce one tool that I found myself liking a lot: To have a bootstrap of an Infrastructure as Code flow in my applications. Terraform."
hidden: false
---
Sometimes when you handle a lot of servers in the cloud, it is pretty easy to get lost on your infrastructure. “Where is that freaking server that I can’t find?”, or even “Why is this instance for?”.

In this post, I will introduce one tool that I found myself liking a lot: To have a bootstrap of an Infrastructure as Code flow in my applications. [Terraform](https://www.terraform.io/).
Infrastructure as Code (IaC) allows us to have a repository with code that describes our infrastructure. This way, we can avoid reminding how rebuild the entire infrastructure for an application. It will be on the code and it can be versioned and tested. And if something goes wrong, we can revert it. It is very useful having a continuous integration of the infrastructure. The whole team knows how it was built and all the pieces. You can apply the same flow that you use in you app code to your infrastructure, i.e: Someone makes a change, open a Pull Request, someone reviews it and after it is approved, you merge and your CI tools apply the changes in your environment.

<div class="breaker"></div>

## Why Terraform? What is the difference between Chef, Puppet or Ansible?

Chef, Puppet and Ansible are IaC tools too, but they focus on **configuring** operating system and applications. They are called Configuration Management Tools and they also can build infrastructure on the cloud with a help of plugins, but usually it is hard to configure and sometimes it is limited. With Terraform you can build from the services to the networking part. You can use Terraform to create the infrastructure and a configuration management tool to configure the applications. Terraform can’t replace your configuration management tool, but it’s made to work together with it.

![show_me_code](https://cdn-images-1.medium.com/max/1600/1*sS6MVPyxzhn3O8pA3nw0kg.jpeg)


<div class="breaker"></div>

## A practical example

In order to follow this article, you’ll need an AWS account.

Let’s create the servers for our web application. Take a look at this diagram of the resources that we’ll build.

![scenario](https://cdn-images-1.medium.com/max/1600/1*nYWHvlp87BBsE6gI2TbKYA.png)

We will create 2 subnets (one for public access and another private). We have Elastic Load Balancer in the public subnet to handle the traffic to our web servers. Our web servers will be on the private subnet and it will only be accessible through the Load Balancer. This mean that we won’t have direct access to make connections (for example, SSH) on the server. In order to access via SSH an instance on a private subnet, you’ll need a bastion host and connect to the web server through it. Thus, we will create the bastion host on the public subnet.

Before getting your hands dirty, you need to install Terraform. Follow the instructions of [this link](https://www.terraform.io/intro/getting-started/install.html) to install it in your machine.

### Directory structure

Let’s create a folder to handle our infrastructure code.

{% highlight shell %}
$ mkdir ~/terraform
{% endhighlight %}

I like to follow this pattern when working with Terraform:

```
├── modules
│   ├── networking
│   └── web
├── production
└── staging
```

Let’s create this folder structure

{% highlight shell %}
$ cd ~/terraform
$ mkdir -p modules/{networking,web} production staging
{% endhighlight %}


Our `modules` folder contains all the *shared code* to create the pieces of the infrastructure (web servers, app servers, databases, vpc, etc). Each folder inside the `modules` folder is related to a specific module. 
Next, I have folders for my environments (staging, production, qa, development, etc). Each of this folder contains code to use our shared modules and create a different architecture for each environment (This is my personal approach using Terraform, but feel free to work on a different way).

### Our first module: Networking

Let’s create our networking module. This will be responsible for creating the networking pieces of our infrastructure, like VPC, subnets, routing table, NAT server and the bastion instance.

Before we get deep in the code, I wanna explain how terraform works:

Terraform will provide us with some commands. Some of them are:

*plan*: Displays all the changes that Terraform makes on our infrastructure
*apply*: Executes all the changes to the infrastructure
*destroy*: Destroys everything that was created with Terraform

When you run Terraform inside a directory, it loads ALL `.tf` files from the directory and execute them (will not load on subfolders). Terraform will first create a graph of the resources to apply only in the final phase, so you don’t need to specify the resources in any specific order. The graph will determine the relations between the resources and ensure that Terraform creates they in the right order.

### Continuing on our networking module

Enter in the networking module

{% highlight shell %}
$ cd modules/networking
{% endhighlight %}

Let’s create our first tf file. The one that specifies all variables needed for our module.

{% highlight shell %}
$ touch variables.tf
{% endhighlight %}

Insert the following content on the variables.tf file:

{% highlight ruby %}
variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet"
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet"
}

variable "environment" {
  description = "The environment"
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "availability_zone" {
  description = "The az that the resources will be launched"
}

variable "bastion_ami" {
  default = {
    "us-east-1" = "ami-f652979b"
    "us-east-2" = "ami-fcc19b99"
    "us-west-1" = "ami-16efb076"
  }
}

variable "key_name" {
  description = "The public key for the bastion host"
}
{% endhighlight %}

These are all variables that our networking module needs in order to create all resources. We need the CIDR for the VPC and the subnets, the AWS region that we will use, the key name and the environment that we are building.
This is the way that you specify a variable in Terraform

{% highlight ruby %}
variable "variable_name" {
  description = "The description of the variable"
  default = "A default value if this isn't set
}
{% endhighlight %}

Ok. Now we have our `variables.tf` file to specify the interface of our module. Let’s create the file that will create networking stuffs for our module. Create the `main.tf` file in the networking folder. (you can specify any name that you want. Remember, all `tf` files will be loaded).

{% highlight shell %}
$ touch main.tf
{% endhighlight %}

Insert the following content on the main.tf file:

{% highlight ruby %}
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name        = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}

/* Internet gateway for the public subnet */
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name        = "${var.environment}-igw"
    Environment = "${var.environment}"
  }
}


/* Elastic IP for NAT */
resource "aws_eip" "nat_eip" {
  vpc = true
}

/* NAT */
resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
}

/* Public subnet */
resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.public_subnet_cidr}"
  availability_zone       = "${var.availability_zone}"
  map_public_ip_on_launch = true

  tags {
    Name        = "${var.environment}-public-subnet"
    Environment = "${var.environment}"
  }
}

/* Private subnet */
resource "aws_subnet" "private_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.private_subnet_cidr}"
  map_public_ip_on_launch = false
  availability_zone       = "${var.availability_zone}"

  tags {
    Name        = "${var.environment}-private-subnet"
    Environment = "${var.environment}"
  }
}

/* Routing table for private subnet */
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name        = "${var.environment}-private-route-table"
    Environment = "${var.environment}"
  }
}

/* Routing table for public subnet */
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat.id}"
}

/* Route table associations */
resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  subnet_id       = "${aws_subnet.private_subnet.id}"
  route_table_id  = "${aws_route_table.private.id}"
}

/* Default security group */
resource "aws_security_group" "default" {
  name        = "${var.environment}-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }

  tags {
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "bastion" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${var.environment}-bastion-host"
  description = "Allow SSH to bastion host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment}-bastion-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_instance" "bastion" {
  ami                         = "${lookup(var.bastion_ami, var.region)}"
  instance_type               = "t2.micro"
  key_name                    = "${var.key_name}"
  monitoring                  = true
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  subnet_id                   = "${aws_subnet.public_subnet.id}"
  associate_public_ip_address = true

  tags {
    Name        = "${var.environment}-bastion"
    Environment = "${var.environment}"
  }
}
{% endhighlight %}

Here we are creating all the networking part of our infrastructure based on the diagram that we saw. A VPC, both subnets (public and private), the Internet Gateway to the public subnet, the NAT server for the private subnet, the bastion host and all security group for the VPC, allowing inbound and outbound inside the VPC, and the security group for the bastion host, allowing the SSH on the Port 22. You can check [this link from AWS](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html) for more details.

This is how we create a resource on Terraform.

{% highlight ruby %}
resource "resource" "name" {
  attribute = "value"
}
{% endhighlight %}

The `resource` is the name of the resource that we want to build. Each cloud provider has different resources. For example, [these resources](https://www.terraform.io/docs/providers/aws/index.html) from AWS. We can also concatenate values. Remember that we created the variables file? We use them here with the `var.variable_name`. Like in this part of the code, which we use the `key_name` variable that we specified in the variables file:

{% highlight ruby %}
resource "aws_instance" "bastion" {
  ...
  key_name = "${var.key_name}"
  ...
}
{% endhighlight %}

This is how we created the instance and called its bastion. You can also get property of this resource in other parts of the code. Example:

{% highlight ruby %}
resource "someresource" "somename" {
  attribute = "${aws_instance.bastion.id}"
}
{% endhighlight %}

We use the same idea of var concatenation. But we specify `${resource_type.resource_name.property}`.

Our networking module is almost ready. We need to output some variables after the module build the resources, so we can use it in other parts of the code. Terraform has the [output command](https://www.terraform.io/intro/getting-started/outputs.html), allowing us to expose variables.

Create the output.tf file inside the networking folder.

{% highlight shell %}
$ touch output.tf
{% endhighlight %}

Insert the following content on the `output.tf` file:

{% highlight ruby %}
output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "public_subnet_id" {
  value = "${aws_subnet.public_subnet.id}"
}

output "private_subnet_id" {
  value = "${aws_subnet.private_subnet.id}"
}

output "default_sg_id" {
  value = "${aws_security_group.default.id}"
}
{% endhighlight %}

This is how we output a variable from our module:

{% highlight ruby %}
output "variable_name" {
  value = "variable value"
}
{% endhighlight %}

This will allow us to get these variables outside the module.

### Using our module to build the networking from our environment

Now that our networking module is ready, we can use it to build our networking from our environment (i.e, staging).
This is how our terraform folder looks now:

```
├── modules
│   ├── networking
│   │   ├── main.tf
│   │   ├── output.tf
│   │   └── variables.tf
│   └── web
├── production
└── staging
```

Go into `staging` folder.
{% highlight shell %}
$ cd ~/terraform/staging
{% endhighlight %}

First, create the public key for the staging servers
{% highlight shell %}
$ ssh-keygen -t rsa -C "staging_key" -f ./staging_key
{% endhighlight %}

Let’s create our main file. In this file, we will specify information of the AWS provider.

{% highlight shell %}
$ touch _main.tf
{% endhighlight %}

(We use _ at the beginning of the name because since terraform loads all files alphabetically, we need this to be loaded first, since it will create the keypair)

You can specify things like Access and secret key in some ways:
* Specify it directly in the provider (not recommended)
{% highlight ruby %}
provider "aws" {
  region     = "us-west-1"
  access_key = "myaccesskey"
  secret_key = "mysecretkey"
}
{% endhighlight %}

* Using the AWS_ACCESS_KEY and AWS_SECRET_KEY environment variables

{% highlight shell %}
$ export AWS_ACCESS_KEY_ID="myaccesskey"
$ export AWS_SECRET_ACCESS_KEY="mysecretkey"
$ terraform plan
{% endhighlight %}

The second option is recommended because you don’t need to expose your secrets on the file. *Bonus point*: If you have the [AWS cli](https://aws.amazon.com/pt/cli/) you don’t need to export these variables. Only run the `aws configure` command and terraform will use the variables that you set on it.

Insert the following content on the _main.tf file:

{% highlight ruby %}
provider "aws" {
  region = "${var.region}"
}

resource "aws_key_pair" "key" {
  key_name   = "${var.key_name}"
  public_key = "${file("staging_key.pub")}"
}
{% endhighlight %}

We will only specify the region to the provider. Both access and secret key, we will rely on the `AWS cli`.

Now create the `networking.tf` file. It will use our module to create the resources.

{% highlight shell %}
$ touch networking.tf
{% endhighlight %}

Insert the following content on the networking.tf file:

{% highlight ruby %}
module "networking" {
  source              = "../modules/networking"
  environment         = "${var.environment}"
  vpc_cidr            = "${var.vpc_cidr}"
  public_subnet_cidr  = "${var.public_subnet_cidr}"
  private_subnet_cidr = "${var.private_subnet_cidr}"
  region              = "${var.region}"
  availability_zone   = "${var.availability_zone}"
  key_name            = "${var.key_name}"
}
{% endhighlight %}

This is how we use [modules on Terraform](https://www.terraform.io/docs/configuration/modules.html).

{% highlight ruby %}
module "name" {
  source    = "location_path"
  attribute = "value"
}
{% endhighlight %}

The module attributes are all variables that we specified before in the variables.tf file from our networking module. Look that we are passing more variables to our module attributes. We need our environment to require these variables too. Create the `variables.tf` file for our staging environment.

{% highlight ruby %}
$ touch variables.tf
{% endhighlight %}

Add the following content to the `variables.tf` file:

{% highlight ruby %}
variable "environment" {
  default = "staging"
}

variable "key_name" {
  description = "The aws keypair to use"
}

variable "region" {
  description = "Region that the instances will be created"
}

variable "availability_zone" {
  description = "The AZ that the resources will be launched"
}

# Networking

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
}

variable "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
}

variable "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
}
{% endhighlight %}

This file follows the same pattern of the module’s variables file. These are all variables that we need to build our staging networking piece.

Ok… I think that we are ready to go. Your terraform’s folder structure should be like this:

```
├── modules
│   ├── networking
│   │   ├── main.tf
│   │   ├── output.tf
│   │   └── variables.tf
│   └── web
├── production
└── staging
    ├── _main.tf
    ├── networking.tf
    └── variables.tf
```

Run this command on `staging` folder: (Terraform’s commands should be run on the environments folder).

{% highlight shell %}
$ cd ~/terraform/staging
$ terraform get
$ terraform plan
{% endhighlight %}

* the `terraform get` command only syncs all modules.

After executing the `terraform plan` command, it will ask you a lot of informations (our variables). Answer they:

![terra_vars](https://cdn-images-1.medium.com/max/1600/1*CKnvWOjniPmXHpbI8u6oNA.png)

It will output a lot of things. Resources that will be created. You can analyze it to check if everything is ok. `terraform plan` will output only the planned change of the infrastructure.

Now, let’s apply these modifications.

{% highlight shell %}
$ terraform apply
{% endhighlight %}

But it is asking for all that information again. To avoid this, you can follow 2 ways to automatically inject variable’s value to Terraform
* Using a `terraform.tfvars` file and remember to ignore this file in your VCS.
* Specifying variables in Environment variables. `TF_VAR_environment=staging terraform apply` (this can be useful when you run through some CI tool)

We will follow the first way. So, create a terraform.tfvars file

{% highlight shell %}
$ touch terraform.tfvars
{% endhighlight %}

Insert the following content on `terraform.tfvars`:

{% highlight ruby %}
environment        = "staging"
key_name           = "test"
region             = "us-west-1"
availability_zone  = "us-west-1a"

# vpc
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
{% endhighlight %}

Now you can run the apply command without being asked for variable’s value.

{% highlight shell %}
$ terraform apply
{% endhighlight %}

![apply_complete](https://cdn-images-1.medium.com/max/1600/1*Lb4nvDoCX_hOyDckORfLOg.png)

Congratulations..

![congrats](https://cdn-images-1.medium.com/max/1600/1*6447MjaXTKhttJ5WlqTVpQ.gif)

This will generate 2 files on the staging folder: `terraform.tfstate` and `terraform.tfstate.backup`

Terraform controls all their resources on this `terraform.tfstate` file. You should *NEVER* delete this file. If you do, terraform will think that it needs to create new resources and will lose tracking with the others that it has been already created.

And how can I make my team in sync with the state?

You have 2 ways to keep the team with the remote in sync. You can commit this `.tfstate` file to your VCS repository, or use [Terraform Remote State](https://www.terraform.io/docs/state/remote.html). If you rely on terraform’s remote state, I really recommend you to use some wrapper tool for Terraform like [Terragrunt](https://github.com/gruntwork-io/terragrunt). It can handle the remote state locking and initializing it for you.

<div class="breaker"></div>

### Creating the web servers

This is our folder structure until now.

```
├── modules
│   ├── networking
│   │   ├── main.tf
│   │   ├── output.tf
│   │   └── variables.tf
│   └── web
├── production
└── staging
    ├── _main.tf
    ├── networking.tf
    ├── staging_key
    ├── staging_key.pub
    ├── terraform.tfstate
    ├── terraform.tfstate.backup
    ├── terraform.tfvars
    └── variables.tf
```

Go into our `web` module

{% highlight shell %}
$ cd ~/terrform/modules/web
{% endhighlight %}

Following the same flow we used to create the networking module, let’s create our variables file to specify the interface to our module:

{% highlight shell %}
$ touch variables.tf
{% endhighlight %}

Insert the following content on `variables.tf`:

{% highlight ruby %}
variable "web_instance_count" {
  description = "The total of web instances to run"
}

variable "region" {
  description = "The region to launch the instances"
}

variable "amis" {
  default = {
    "us-east-1" = "ami-f652979b"
    "us-east-2" = "ami-fcc19b99"
    "us-west-1" = "ami-16efb076"
  }
}

variable "instance_type" {
  description = "The instance type to launch"
}

variable "private_subnet_id" {
  description = "The id of the private subnet to launch the instances"
}

variable "public_subnet_id" {
  description = "The id of the public subnet to launch the load balancer"
}

variable "vpc_sg_id" {
  description = "The default security group from the vpc"
}

variable "vpc_cidr_block" {
  description = "The CIDR block from the VPC"
}

variable "key_name" {
  description = "The keypair to use on the instances"
}

variable "environment" {
  description = "The environment for the instance"
}

variable "vpc_id" {
  description = "The id of the vpc"
}
{% endhighlight %}

Create the main.tf file to handle the creation of the resources.

{% highlight shell %}
$ touch main.tf
{% endhighlight %}

Insert the following content on `main.tf`:

{% highlight ruby %}
/* Security group for the web */
resource "aws_security_group" "web_server_sg" {
  name        = "${var.environment}-web-server-sg"
  description = "Security group for web that allows web traffic from internet"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["${var.vpc_cidr_block}"]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["${var.vpc_cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment}-web-server-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "web_inbound_sg" {
  name        = "${var.environment}-web-inbound-sg"
  description = "Allow HTTP from Anywhere"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-web-inbound-sg"
  }
}

/* Web servers */
resource "aws_instance" "web" {
  count             = "${var.web_instance_count}"
  ami               = "${lookup(var.amis, var.region)}"
  instance_type     = "${var.instance_type}"
  subnet_id         = "${var.private_subnet_id}"
  vpc_security_group_ids = [
    "${aws_security_group.web_server_sg.id}"
  ]
  key_name          = "${var.key_name}"
  user_data         = "${file("${path.module}/files/user_data.sh")}"
  tags = {
    Name        = "${var.environment}-web-${count.index+1}"
    Environment = "${var.environment}"
  }
}

/* Load Balancer */
resource "aws_elb" "web" {
  name            = "${var.environment}-web-lb"
  subnets         = ["${var.public_subnet_id}"]
  security_groups = ["${aws_security_group.web_inbound_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  instances = ["${aws_instance.web.*.id}"]

  tags {
    Environment = "${var.environment}"
  }
}
{% endhighlight %}

This file is practically the same from our networking’s main.tf, we are only creating different resources. 
Some differences that you can note:

* In this example we are using the `count` attribute. It specifies to Terraform, to create N times this resource. If we pass 5 on the value, it will create 5 instances.
  {% highlight ruby %}
  resource "aws_instance" "web" {
    count = "${var.web_instance_count}"
    ...
  }
  {% endhighlight %}

  and you can create dynamic names with the counting number using the count.index property, for example:

    {% highlight ruby %}
      tags {
        Name = "web-server-${count.index + 1}"
      }
    {% endhighlight %}

* We are passing a file to the `user_data` property. In order to execute some code on the instance initialization, we need to pass the `user_data` attribute to our instance and we are specifying a file.
   {% highlight ruby %}
    user_data = "${file("${path.module}/files/user_data.sh")}"
   {% endhighlight %}

This will load the content of the `user_data.sh` file and pass to the attribute.

But we haven’t created this file yet, let’s do it. On the web module folder, create the `files` folder and the `user_data.sh` file.

{% highlight shell %}
$ mkdir files
$ touch files/user_data.sh
{% endhighlight %}

Insert the following content on the `files/user_data.sh`:

{% highlight bash %}
#!/bin/bash
apt-get update -y
apt-get install -y nginx > /var/nginx.log
{% endhighlight %}

This will install the nginx when the instance is created.

Now, let’s create the `output.tf` file to get the load balancer’s DNS after the execution.

{% highlight shell %}
$ touch output.tf
{% endhighlight %}

Insert the following content on the `output.tf`:

{% highlight ruby %}
output "elb.hostname" {
  value = "${aws_elb.web.dns_name}"
}
{% endhighlight %}

Our web module is done.

This is how our terraform structure is now:

```
├── modules
│   ├── networking
│   │   ├── main.tf
│   │   ├── output.tf
│   │   └── variables.tf
│   └── web
│       ├── files
│       │   └── user_data.sh
│       ├── main.tf
│       ├── output.tf
│       └── variables.tf
├── production
└── staging
    ├── _main.tf
    ├── networking.tf
    ├── staging_key
    ├── staging_key.pub
    ├── terraform.tfstate
    ├── terraform.tfstate.backup
    ├── terraform.tfvars
    └── variables.tf
```

<div class="breaker"></div>

### Using our web module

Let’s back to our staging folder

{% highlight shell %}
$ cd ~/terraform
$ cd staging
{% endhighlight %}

Now, we will use our recent created web module. Create a web.tf file

{% highlight shell %}
$ touch web.tf
{% endhighlight %}

Insert the following content on the `web.tf`:

{% highlight ruby %}
module "web" {
  source              = "../modules/web"
  web_instance_count  = "${var.web_instance_count}"
  region              = "${var.region}"
  instance_type       = "t2.micro"
  private_subnet_id   = "${module.networking.private_subnet_id}"
  public_subnet_id    = "${module.networking.public_subnet_id}"
  vpc_sg_id           = "${module.networking.default_sg_id}"
  key_name            = "${var.key_name}"
  environment         = "${var.environment}"
  vpc_id              = "${module.networking.vpc_id}"
  vpc_cidr_block      = "${var.vpc_cidr}"
}
{% endhighlight %}

This is pretty much the same way we used in our networking module. We are using almost the same variables that we already specified (except for `web_instance_count`. And some variables, we pass the output from our `networking` module.

{% highlight ruby %}
"${module.networking.public_subnet_id}"
{% endhighlight %}

This way we get the `public_subnet_id` output created on the networking module.

Let’s add the `web_instance_count` variable to our `variables.tf` file and `terraform.tfvars`. This variable represents the number of web instances that we will be created.

Your `variables.tf` from staging folder should be like this:

{% highlight ruby %}
variable "environment" {
  default = "staging"
}

variable "key_name" {
  description = "The aws keypair to use"
}

variable "region" {
  description = "Region that the instances will be created"
}

variable "availability_zone" {
  description = "The AZ that the resources will be launched"
}

# Networking

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
}

variable "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
}

variable "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
}

# Web
variable "web_instance_count" {
  description = "The total of web instances to run"
}
{% endhighlight %}

And your `terraform.tfvars` should be like this:

{% highlight ruby %}
environment        = "staging"
key_name           = "test"
region             = "us-west-1"
availability_zone  = "us-west-1a"

# vpc
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# web
web_instance_count  = 2
{% endhighlight %}

Let’s create an `output.tf` for our staging environment. With this, we can get the ELB hostname from our web module.

{% highlight shell %}
touch output.tf
{% endhighlight %}

Add the following content to `output.tf`:

{% highlight ruby %}
output "elb_hostname" {
  value = "${module.web.elb.hostname}"
}
{% endhighlight %}

This is the final directory structure that we have:

```
├── modules
│   ├── networking
│   │   ├── main.tf
│   │   ├── output.tf
│   │   └── variables.tf
│   └── web
│       ├── files
│       │   └── user_data.sh
│       ├── main.tf
│       ├── output.tf
│       └── variables.tf
├── production
└── staging
    ├── _main.tf
    ├── networking.tf
    ├── output.tf
    ├── staging_key
    ├── staging_key.pub
    ├── terraform.tfstate
    ├── terraform.tfstate.backup
    ├── terraform.tfvars
    ├── variables.tf
    └── web.tf
```

You can now run `terraform plan` to check which resources will be created. (before, run `terraform get` to update the modules)

{% highlight shell %}
$ terraform get
$ terraform plan
{% endhighlight %}

![plan](https://cdn-images-1.medium.com/max/1600/1*_3j03t04L3BbcAM9B3t5Tg.png)

Done. Terraform will create 5 new resources from our web module.

Let’s apply it.

{% highlight shell %}
$ terraform apply
{% endhighlight %}

![applied](https://cdn-images-1.medium.com/max/1600/1*zojlSrGMXN93qiHdoZVPhQ.png)

Yay.. our instances was created. Let’s get our Load Balancer DNS and try to open it on a Browser:

{% highlight shell %}
$ terraform output elb_hostname
{% endhighlight %}

This command will return the DNS from our Load Balancer. Open it on a browser:

![host](https://cdn-images-1.medium.com/max/1600/1*KAFGuGGUKWTWISGD2dqmBQ.png)

![working](https://cdn-images-1.medium.com/max/1600/1*X4llUCSctCV1RBczcOPusw.png)

It’s working!!! With this, you finished the creation of your infrastructure.

### Final Notes

Your web instances don’t have public ips:

![instances](https://cdn-images-1.medium.com/max/1600/1*SipX4XhQdT5_Z0zYySLmNg.png)

In order to SSH then, you need to use the bastion host created on the networking module.

Get the bastion host public IP,

![bastion](https://cdn-images-1.medium.com/max/1600/1*HctNFDW39zAagy7iRyiirQ.png)

and SSH on it with the `-A` flag to enable agent forwarding:

{% highlight shell %}
$ chmod 400 staging_key.pub
$ ssh-add -K staging_key
$ ssh -A ubuntu@52.53.227.241
{% endhighlight %}

Now, inside the Bastion host, you can connect into your web server private IP:

{% highlight shell %}
$ ssh ubuntu@10.0.2.113
{% endhighlight %}

![ssh](https://cdn-images-1.medium.com/max/1600/1*jxxGXtybRz43Rw47BacdxA.png)

Now, destroy everything

{% highlight shell %}
$ terraform destroy
{% endhighlight %}

You can get the full code of the example [here](https://github.com/duduribeiro/terraform_example).

That’s all.

![thatsall](https://cdn-images-1.medium.com/max/1600/1*PlGYD6UUSY3wbNzGRAkHSw.gif)

Cheers,
🍻