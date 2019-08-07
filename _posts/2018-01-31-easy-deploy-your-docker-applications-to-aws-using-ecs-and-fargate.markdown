---
title: "Easy deploy your Docker applications to AWS using ECS and Fargate"
layout: post
date: 2018-01-31 12:00:00 -0300
image: /assets/images/fargate.png
headerImage: true
tag:
- aws
- terraform
- cloud
- docker
category: blog
author: dudribeiro
description: "In this post, I will try to demonstrate how you can deploy your Docker application into AWS using ECS and Fargate."
hidden: false
---
In this post, I will try to demonstrate how you can deploy your Docker application into AWS using ECS and Fargate.

As an example, I will deploy [this app](http://openjobs.me/) to ECS. The source can be found [here](https://github.com/opensanca/opensanca_jobs/).

I will use [Terraform](https://www.terraform.io/) to spin the infrastructure so I can easily track everything that I create as a code. If you want to learn the basics of Terraform, please read my [post about it](https://thecode.pub/creating-your-cloud-servers-with-terraform-bfa01a499bad).

<div class="breaker"></div>

## ECS

What is ECS?

The Elastic Container Service (ECS) is an AWS Service that handles the Docker containers orchestration in your EC2 cluster. It is an alternative for Kubernetes, Docker Swarm, and others.

### ECS Terminology

To start understanding what ECS is, we need to understand its terms and definitions that differs from the Docker world.

- `Cluster`: It is a group of EC2 instances hosting containers.
- `Task definition`: It is the specification of how ECS should run your app. Here you define which image to use, port mapping, memory, environments variables, etc.
- `Service`: Services launches and maintains tasks running inside the cluster. A Service will auto-recover any stopped tasks keeping the number of tasks running as you specified.

<div class="breaker"></div>

## Fargate

Fargate is a technology that allows running containers in ECS without needing to manage the EC2 servers for cluster. You only deploy your Docker applications and set the scaling rules for it. Fargate is an execution method from ECS.

`Show me the code`

The full example is on [Github](https://github.com/duduribeiro/terraform_ecs_fargate_example).

<div class="breaker"></div>

## The project structure

Our Terraform project is composed of the following structure:

```
├── modules
│ └── code_pipeline
│ └── ecs
│ └── networking
│ └── rds
├── pipeline.tf
├── production.tf
├── production_key.pub
├── terraform.tfvars
└── variables.tf
```

- `Modules` is where we will store the code that handles the creation of a group of resources. It can be reused by all environments (Production, Staging, QA, etc.) without needing to duplicate a lot of code.
- `production.tf` is the file that defines the environment itself. It calls the modules passing variables to it.
- `pipeline.tf` Since the pipeline can be a global resource without needing to isolate per environment. This file will handle the creation of this pipeline using the `code_pipeline` module.

<div class="breaker"></div>

## First part, the networking

The branch with this part can be found [here](https://github.com/duduribeiro/terraform_ecs_fargate_example/tree/01_networking).

The first thing that we need to create is the VPC with 2 subnets (1 public and 1 private) in each Availability Zone. Each Availability Zone is a geographically isolated region. Keeping our resources in more than one zone is the first thing to achieve high availability. If one physical zone fails for some reason, your application can answer from the others.

![our_networking](https://miro.medium.com/max/1400/1*Cvu1YNJdfezuVfU8kAPgNA.png)

Keeping the cluster on the private subnet protects your infrastructure from external access. The private subnet is allowed only to be accessed from resources inside the public network (In our case, will be the Load Balancer only).

This is the code to create this structure (it is practically the same from my introduction post of Terraform):

{% highlight terraform %}
/*====
The VPC
======*/

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name        = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}

/*====
Subnets
======*/
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
  vpc        = true
  depends_on = ["aws_internet_gateway.ig"]
}

/* NAT */
resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${element(aws_subnet.public_subnet.*.id, 0)}"
  depends_on    = ["aws_internet_gateway.ig"]

  tags {
    Name        = "${var.environment}-${element(var.availability_zones, count.index)}-nat"
    Environment = "${var.environment}"
  }
}

/* Public subnet */
resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  count                   = "${length(var.public_subnets_cidr)}"
  cidr_block              = "${element(var.public_subnets_cidr, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name        = "${var.environment}-${element(var.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

/* Private subnet */
resource "aws_subnet" "private_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  count                   = "${length(var.private_subnets_cidr)}"
  cidr_block              = "${element(var.private_subnets_cidr, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = false

  tags {
    Name        = "${var.environment}-${element(var.availability_zones, count.index)}-private-subnet"
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
  count          = "${length(var.public_subnets_cidr)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  count           = "${length(var.private_subnets_cidr)}"
  subnet_id       = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id  = "${aws_route_table.private.id}"
}

/*====
VPC's Default Security Group
======*/
resource "aws_security_group" "default" {
  name        = "${var.environment}-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = "${aws_vpc.vpc.id}"
  depends_on  = ["aws_vpc.vpc"]

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
{% endhighlight %}

The above code creates the VPC, 4 subnets (2 public and 2 private) in each Availability zone. It also creates a NAT to allow the private network access the internet.

<div class="breaker"></div>

## The Database

The branch with this part can be found [here](https://github.com/duduribeiro/terraform_ecs_fargate_example/tree/02_database).

We will create a RDS database. It will be located on the private subnet. Allowing only the public subnet to access it.

{% highlight terraform %}
/*====
RDS
======*/

/* subnet used by rds */
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.environment}-rds-subnet-group"
  description = "RDS subnet group"
  subnet_ids  = ["${var.subnet_ids}"]
  tags {
    Environment = "${var.environment}"
  }
}

/* Security Group for resources that want to access the Database */
resource "aws_security_group" "db_access_sg" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.environment}-db-access-sg"
  description = "Allow access to RDS"

  tags {
    Name        = "${var.environment}-db-access-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "rds_sg" {
  name = "${var.environment}-rds-sg"
  description = "${var.environment} Security Group"
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "${var.environment}-rds-sg"
    Environment =  "${var.environment}"
  }

  // allows traffic from the SG itself
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      self = true
  }

  //allow traffic for TCP 5432
  ingress {
      from_port = 5432
      to_port   = 5432
      protocol  = "tcp"
      security_groups = ["${aws_security_group.db_access_sg.id}"]
  }

  // outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "rds" {
  identifier             = "${var.environment}-database"
  allocated_storage      = "${var.allocated_storage}"
  engine                 = "postgres"
  engine_version         = "9.6.6"
  instance_class         = "${var.instance_class}"
  multi_az               = "${var.multi_az}"
  name                   = "${var.database_name}"
  username               = "${var.database_username}"
  password               = "${var.database_password}"
  db_subnet_group_name   = "${aws_db_subnet_group.rds_subnet_group.id}"
  vpc_security_group_ids = ["${aws_security_group.rds_sg.id}"]
  skip_final_snapshot    = true
  snapshot_identifier    = "rds-${var.environment}-snapshot"
  tags {
    Environment = "${var.environment}"
  }
}
{% endhighlight %}

With this code, we create the RDS resource with values received from the variables. We also create the security group that should be used by resources that want to connect to the database (in our case, the ECS cluster).

Ok. Now we have the database. Let’s finally create our ECS to deploy our app \o.

<div class="breaker"></div>

## Take Three: The ECS

The branch with this part can be found [here](https://github.com/duduribeiro/terraform_ecs_fargate_example/tree/03_ecs).

We are approaching the final steps. Now, it is the part that we define the ECS resources needed for our app.

### The ECR repository

The first thing is to create the repository to store our built images.

{% highlight terraform %}
/*====
ECR repository to store our Docker images
======*/
resource "aws_ecr_repository" "openjobs_app" {
  name = "${var.repository_name}"
}
{% endhighlight %}

### The ECR cluster

Next, we need our ECS cluster. Even using Fargate (that doesn’t need any EC2), we need to define a cluster for the application.

{% highlight terraform %}
/*====
ECS cluster
======*/
resource "aws_ecs_cluster" "cluster" {
  name = "${var.environment}-ecs-cluster"
}
{% endhighlight %}

### The tasks definitions

Now, we will define 2 task definitions.

- Web: Contains the definition of the web app itself.
- Db Migrate: This task will only run the command to migrate our database and will die. Since it is a single run task, we don’t need a service for it.

{% highlight terraform %}
/*====
ECS task definitions
======*/

/* the task definition for the web service */
data "template_file" "web_task" {
  template = "${file("${path.module}/tasks/web_task_definition.json")}"

  vars {
    image           = "${aws_ecr_repository.openjobs_app.repository_url}"
    secret_key_base = "${var.secret_key_base}"
    database_url    = "postgresql://${var.database_username}:${var.database_password}@${var.database_endpoint}:5432/${var.database_name}?encoding=utf8&pool=40"
    log_group       = "${aws_cloudwatch_log_group.openjobs.name}"
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.environment}_web"
  container_definitions    = "${data.template_file.web_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}

/* the task definition for the db migration */
data "template_file" "db_migrate_task" {
  template = "${file("${path.module}/tasks/db_migrate_task_definition.json")}"

  vars {
    image           = "${aws_ecr_repository.openjobs_app.repository_url}"
    secret_key_base = "${var.secret_key_base}"
    database_url    = "postgresql://${var.database_username}:${var.database_password}@${var.database_endpoint}:5432/${var.database_name}?encoding=utf8&pool=40"
    log_group       = "openjobs"
  }
}

resource "aws_ecs_task_definition" "db_migrate" {
  family                   = "${var.environment}_db_migrate"
  container_definitions    = "${data.template_file.db_migrate_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}
{% endhighlight %}

The tasks definitions are configured in a JSON file and rendered as a template in Terraform.

This is the task definition of the web app:

{% highlight json %}
[
  {
    "name": "web",
    "image": "${image}",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "memory": 300,
    "networkMode": "awsvpc",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group}",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "web"
      }
    },
    "environment": [
      {
        "name": "RAILS_ENV",
        "value": "production"
      },
      {
        "name": "DATABASE_URL",
        "value": "${database_url}"
      },
      {
        "name": "SECRET_KEY_BASE",
        "value": "${secret_key_base}"
      },
      {
        "name": "PORT",
        "value": "80"
      },
      {
        "name": "RAILS_LOG_TO_STDOUT",
        "value": "true"
      },
      {
        "name": "RAILS_SERVE_STATIC_FILES",
        "value": "true"
      }
    ]
  }
]
{% endhighlight %}

In the file above, we are defining the task to ECS. We pass the created ECR image repository as variable to it. We also configure other variables so ECS can start our Rails app.

The definition of the DB migration task is almost the same. We only change the command that will be executed.

### The load balancers

Before creating the Services, we need to create the load balancers. They will be on the public subnet and will forward the requests to the ECS service.

{% highlight terraform %}

resource "aws_alb_target_group" "alb_target_group" {
  name     = "${var.environment}-alb-target-group-${random_id.target_group_sufix.hex}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

/* security group for ALB */
resource "aws_security_group" "web_inbound_sg" {
  name        = "${var.environment}-web-inbound-sg"
  description = "Allow HTTP from Anywhere into ALB"
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

resource "aws_alb" "alb_openjobs" {
  name            = "${var.environment}-alb-openjobs"
  subnets         = ["${var.public_subnet_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.web_inbound_sg.id}"]

  tags {
    Name        = "${var.environment}-alb-openjobs"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "openjobs" {
  load_balancer_arn = "${aws_alb.alb_openjobs.arn}"
  port              = "80"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.alb_target_group"]

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}
{% endhighlight %}

In the file above we define that our target group will use HTTP on port 80. We also create a security group to allow access into the port 80 from the internet. After, we create the Application Load Balancer and the listener. To use Fargate, you should use an Application Load Balancer instead an Elastic Load Balancer.

### Finally, the ECS service

Now we will create the service. To use Fargate, we need to specify the `lauch_type` as `Fargate`.

{% highlight terraform %}
/*====
ECS service
======*/

/* Security Group for ECS */
resource "aws_security_group" "ecs_service" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

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
    Name        = "${var.environment}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

/* Simply specify the family to find the latest ACTIVE revision in that family */
data "aws_ecs_task_definition" "web" {
  task_definition = "${aws_ecs_task_definition.web.family}"
}

resource "aws_ecs_service" "web" {
  name            = "${var.environment}-web"
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster =       "${aws_ecs_cluster.cluster.id}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name   = "web"
    container_port   = "80"
  }

  depends_on = ["aws_alb_target_group.alb_target_group"]
}
{% endhighlight %}

### Auto-scaling

Fargate allows us to auto-scale our app easily. We only need to create the metrics in CloudWatch and trigger to scale it up or down.

{% highlight terraform %}
resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = "${aws_iam_role.ecs_autoscale_role.arn}"
  min_capacity       = 1
  max_capacity       = 4
}

resource "aws_appautoscaling_policy" "up" {
  name                    = "${var.environment}_scale_up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension      = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

resource "aws_appautoscaling_policy" "down" {
  name                    = "${var.environment}_scale_down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.environment}_openjobs_web_cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "85"

  dimensions {
    ClusterName = "${aws_ecs_cluster.cluster.name}"
    ServiceName = "${aws_ecs_service.web.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
  ok_actions    = ["${aws_appautoscaling_policy.down.arn}"]
}
{% endhighlight %}

We create 2 auto scaling policies. One to scale up and other to scale down the desired count of running tasks from our ECS service.

After, we create a CloudWatch metric based on the CPU. If the CPU usage is greater than 85% from 2 periods, we trigger the `alarm_action` that calls the scale-up policy. If it returns to the Ok state, it will trigger the scale-down policy.

<div class="breaker"></div>

## The Pipeline to deploy our app

Our infrastructure to run our Docker app is ready. But it is still boring to deploy it to ECS. We need to manually push our image to the repository and update the task definition with the new image and update the new task definition. We can run it through Terraform, but it could be better if we have a way to push our code to Github in the master branch and it deploys automatically for us.

Entering, [CodePipeline](https://aws.amazon.com/codepipeline) and [CodeBuild](https://aws.amazon.com/codebuild/).

CodePipeline is a Continuous Integration and Continuous Delivery service hosted by AWS.

CodeBuild is a managed build service that can execute tests and generate packages for us (in our case, a Docker image).

With it, we can create pipelines to delivery our code to ECS. The flow will be:

- You push the code to master’s branch
- CodePipeline gets the code in the Source stage and calls the Build stage (CodeBuild).
- Build stage process our Dockerfile building and pushing the Image to ECR and triggers the Deploy stage
- Deploy stage updates our ECS with the new image

Let’s define our Pipeline with Terraform:

{% highlight terraform %}
/*
/* CodeBuild
*/

data "template_file" "buildspec" {
  template = "${file("${path.module}/buildspec.yml")}"

  vars {
    repository_url     = "${var.repository_url}"
    region             = "${var.region}"
    cluster_name       = "${var.ecs_cluster_name}"
    subnet_id          = "${var.run_task_subnet_id}"
    security_group_ids = "${join(",", var.run_task_security_group_ids)}"
  }
}


resource "aws_codebuild_project" "openjobs_build" {
  name          = "openjobs-codebuild"
  build_timeout = "10"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/docker:1.12.1"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec.rendered}"
  }
}

/* CodePipeline */

resource "aws_codepipeline" "pipeline" {
  name     = "openjobs-pipeline"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.source.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration {
        Owner      = "duduribeiro"
        Repo       = "openjobs_experiment"
        Branch     = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]

      configuration {
        ProjectName = "openjobs-codebuild"
      }
    }
  }

  stage {
    name = "Production"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration {
        ClusterName = "${var.ecs_cluster_name}"
        ServiceName = "${var.ecs_service_name}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
{% endhighlight %}

In the above code, we create a CodeBuild project, using the following buildspec (build specifications file):

{% highlight yaml %}
version: 0.2

phases:
  pre_build:
    commands:
      - pip install awscli --upgrade --user
      - echo `aws --version`
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --region ${region} --no-include-email)
      - REPOSITORY_URI=${repository_url}
      - IMAGE_TAG=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - echo Entered the pre_build phase...
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build --build-arg build_without="development test" --build-arg rails_env="production" -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"web","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
      - echo upgrading db-migrate task definitions
      - aws ecs run-task --launch-type FARGATE --cluster ${cluster_name} --task-definition production_db_migrate --network-configuration "awsvpcConfiguration={subnets=[${subnet_id}],securityGroups=[${security_group_ids}]}"
artifacts:
  files: imagedefinitions.json
{% endhighlight %}

We defined some phases in the above file.
- `pre_build`: Upgrade aws-cli, set some environment variables: REPOSITORY_URL with the ECR repository and IMAGE_TAG with the CodeBuild source version. The ECR repository is passed as a variable by Terraform.
- `build`: Build the Dockerfile from the repository tagging it as LATEST in the repository URL.
- `post_build`: Push the image to the repository. Creates a file named `imagedefinitions.json` with the following content:
‘[{“name”:”web”,”imageUri”:REPOSITORY_URL”}]’
This file is used by CodePipeline to upgrade your ECS cluster in the Deployment stage.
- `artifacts`: Get the file created in the last phase and uses as the artifact.

After, we create a CodePipeline resource with 3 stages:

- `Source`: Gets the repository from Github (change it by your repository information) and pass it to the next stage.
- `Build`: Calls the CodeBuild project that we created in the step before.
- `Production`: Gets the artifact from Build stage (imagedefinitions.json) and deploy to ECS.

Let’s see they working together?

<div class="breaker"></div>

## Running all together

The code with the full example is [here](https://github.com/duduribeiro/terraform_ecs_fargate_example).

Clone it. Also, since we use Github as the CodePipeline source provider, you need to generate a token to access the repositories. [Read here](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) to generate yours.

After generating your token, export it as an environment variable.

{% highlight bash %}
$ export GITHUB_TOKEN=YOUR_TOKEN
{% endhighlight %}

Now, we need to import the modules and the provider library.

{% highlight bash %}
$ terraform init
{% endhighlight %}

![terraform_init](https://miro.medium.com/max/1400/1*6HQQkkurojqHSIw3ywQTSw.png)

Now, let the magic begin!

{% highlight bash %}
$ terraform apply
{% endhighlight %}

it will display that Terraform will create some resources, and if you want to continue

![plan](https://miro.medium.com/max/1400/1*N_Ce_3nRV-hk4QFgd-J3sw.png)

Type `yes`.

![wait](https://miro.medium.com/max/520/1*lZ7NXzq0NMQmObgMoyoJIg.gif)

Seriously, get a coffee until it finishes.

![coffee](https://miro.medium.com/max/1400/1*hl4G1GBfzMSBuBJ2axn0LQ.png)

![apply_complete](https://miro.medium.com/max/1400/1*-w-oLVLxuyebsaUStamQHg.png)

AWESOME!. Our infrastructure is ready!!. If you enter in your CodePipeline at AWS Dashboard, you can see that it also triggered the first build:

![pipeline](https://miro.medium.com/max/1400/1*XfmkQU8ae8v9Pbp6iaJQIA.png)

Wait until all the Stages are green.

![green](https://miro.medium.com/max/912/1*ZdNh3pr5qIdU-vMwlQfi4Q.png)

Get your Load Balancer DNS and check the deployed application:

{% highlight bash %}
$ terraform output alb_dns_name
{% endhighlight %}

![dns](https://miro.medium.com/max/1400/1*WW07XGYH37It1xq5tUnGrQ.png)

![website](https://miro.medium.com/max/2000/1*wJmKvO2Pd36jtJMZePd-3Q.png)

Finally, the app is running. Almost magic!

![magic](https://miro.medium.com/max/550/1*mPUc2fU1VPbW6gjbw1DjeQ.gif)

![thats_all](https://miro.medium.com/max/1400/1*dsHpznpcd482MHT1fvyc3Q.png)


Cheers,
🍻
