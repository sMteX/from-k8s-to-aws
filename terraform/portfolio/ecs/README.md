# Elastic Container Service example

Goal of this deployment was to deploy a minimal ECS instance on Fargate (so we don't have to deal with setting up the EC2 instance even if it might be a bit cheaper).

There's a considerable ecosystem needed to accomplish this, roughly split into several of these files:
- first, the container image has to be pushed somewhere - `aws_ecr_repository` in [ecr.tf](./ecr.tf)
  - we can already configure the tags to be immutable with the exception of `latest`, somewhat good practice (although using `latest` is debatable at best anyway)
- next, we can define the ECS itself (in [ecs.tf](./ecs.tf)):
  - the top-most logical grouping of ECS services is ECS **Cluster**, so first we create that
- the actual resource responsible for running the containers is an ECS **Service**
  - this belongs to a given ECS Cluster
  - here we set the service to run 1 replica of the task, we specify the `FARGATE` launch type, and say that we want a public IP
- next we define the configuration of the task - `aws_ecs_task_definition`
  - here we name the task (`family`), specify the network mode, assign resources to the task, and actually specify the containers (name, Docker image, resources, ports, logging...)
  - the ECS task needs an Execution Role (lets ECS do things like pull image from ECR, push logs to CloudWatch, or pull Secrets)
    - this is created via multiple resources:
      - `aws_iam_policy_document` describing a trust policy for the ECS principal
      - `aws_iam_role` that uses this trust policy
      - `aws_iam_role_policy_attachment` that attaches the built-in `AmazonECSTaskExecutionRolePolicy` to the execution role
- last but not least, the ECS Service needs a bit of network config:
  - it can use a set of security groups, for which we added one (in [vpc.tf](./vpc.tf)):
    - we created this security group in the default VPC
    - we attached very broad ingress and egress rules, just to kinda make it work:
      - ingress is more or less okay - allow `80/tcp` from anywhere
      - egress *should* be in reality more scoped, but this is a rule for pulling image from ECR and writing logs to CW
      - finding out exact values would be tedious for an example that got torn right after, but it's not overlooked
  - it also needs the subnets associated with that Service - for which we used the default subnets in the default VPC

Result is captured in the [screen](./ecs-public-ip-proof.png) - portfolio running on public IP on `http` port (`80`). Setup was torn with `tofu destroy` right away for cost management - few minutes of actual runtime has costed probably just cents, essentially free.