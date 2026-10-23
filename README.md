Marie-Tinka Olivier 
Terraform Project
23 October

Below is a clear outline of the steps I completed and actions I have taken as a "proof of work".
Also find "Evidence" screenshots attached in the repo.

The Project Structure along with Trade-offs and limitations are outlined at the end of this file.

>>  **Submission branch:** `submission`. This is the version to review. `main` contains the original training code.

*********************************************************************************************************
SUMMARY
*********************************************************************************************************
This project provisions an Amazon EKS Kubernetes cluster in AWS for three environments: dev, qa and prod. Each environment has its own VPC, cluster, worker nodes and Terraform state. The state is stored in a separate S3 bucket per environment (olivier-m-s3-dev, -qa, -prod), with locking to prevent simultaneous changes.

Two one-time bootstrap folders create what Terraform needs first: bootstrap/state-backend creates the state buckets, and bootstrap/github-oidc creates an IAM role that GitHub Actions can assume. A GitHub Actions workflow checks formatting, plans every environment on each pull request (posting the plan as a comment), and applies on merge to main. The workflow logs in with that role, so no AWS keys are stored in GitHub. Prod requires approval before it applies.

Dev was deployed and tested: both worker nodes became Ready, a test nginx app was reachable on NodePort 30007, and the environment was destroyed to confirm clean teardown.

*********************************************************************************************************
STEPS TAKEN & PROCESS DOCUMENTED
*********************************************************************************************************
1. 
In modules/capitec_eks/eks.tf
In resource "aws_vpc" "main" I added:
    enable_dns_support   = true
    enable_dns_hostnames = true

Why: EKS requirement - worker nodes cannot find the cluster if the DNS (domain name system) name is off.  

2. 
In modules/capitec_eks/variables.tf I commented out variable "vpc_id" since it is not used anywhere and exposes an account-specific AWS ID. 

3. 
In modules/capitec_eks/variables.tf I removed the default values (values should come from the .tfvars files and not the fallback - mostly for future use so it does not fall back to the wrong resources for a different environment). >> It must not be possible to accidentally run one environment's configuration against another. Removing the defaults will make Terraform stop instead (flag to the user). 

4. 
In modules/capitec_eks/variables.tf
Added a validation block to variables "environment" to ensure only "dev", "qa" and "prod" are allowed; otherwise typos or variations (e.g. "prd") will create new resources.

5. 
Prefixes updated in .tfvars files (for dev, qa and prod) to "olivier-m". Only changed in .tfvars, also referenced in main.tf and modules/capitec_s3/s3.tf - will update accordingly from the the .tfvars files.

6. 
Buckets updated to olivier-m-s3-{env} in the .tfbackend files - the backend must point at the correct bucket in remote state.

7. 
Bucket ARNs (Amazon Resource Names) in OIDC (Open ID Connect) updated to match those in the .tfbackend files (olivier-m-s3-{env}), since the CI (continuous integration) role can only use buckets listed there.

8. 
new folder bootstrap/state-backend/ created to solve the bootstrapping problem - providers.tf says the state lives in an s3 bucket, but the bucket does not exist yet. Terraform cannot create it - needs the bucket to store its own memory first.
Fix = separate Terraform project (kept in a SEPARATE file to not accidentally delete buckets when destroying an environment) that creates 3 x buckets; ran once with state kept local.
main.tf & providers.tf created within this file.

In terraform.tf:
required_version = ">= 1.10" since locking needs 1.10
>> Also updated TF_VERSION in `.github/workflows/terraform.yml` from 1.9.8 to 1.10 to ensure consistent results.

In main.tf:
4 x resources created for each environment (thus 12 resources in total, 3 buckets  x 4 resources each):
    1. Bucket (where state files are stored)
    2. Versioning (old copies of the state file to roll back)
    3. Encryption (to protect the state)
    4. Public access block (to ensure that nobody can make the bucket public by accident)

9. 
State locking turned on in each respective environment's backend file (in envs/*/*.tfbackend) to prevent two applies from altering the same state at the same time. Apparently older terraform versions needed separate DynamoDB tables for this, but with Terraform ~> 1.10, this is no longer necessary.

10. 
Confirmed: in envs/*/*.tfbackend, each .tfbackend has its own bucket and key (for dev, qa, and prod), since state must not be shared between environments.

11. 
Connect "kubectl" to the cluster (in dev).
aws eks update-kubeconfig --region af-south-1 --name olivier-m-eks-dev
What is happening (for my own understanding):

CLUSTER CREATION
>> Kubernetes control plane set up in 3 x AZs by AWS.
>> node group (2 x EC2 worker machines) launches and joins the Kubernetes control plane
>> until AWS says the resource is ready, Terraform waits.

12. 
kubectl connected to the cluster
Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % kubectl get nodes

NAME                                        STATUS   ROLES    AGE   VERSION
ip-10-0-0-37.af-south-1.compute.internal    Ready    <none>   23m   v1.35.8-eks-b9510e3
ip-10-0-1-153.af-south-1.compute.internal   Ready    <none>   23m   v1.35.8-eks-b9510e3

13. 
Ran kubectl apply -f k8s/nginx.yaml to let Kubernetes compare to what exists and make necessary updates.
>> 2 x objects: a POD (container holding the nginx web server - labelled my-app making it discoverable by other objects ) and a SERVICE (type = NodePort to open port 30007 and to forward traffic).

Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % kubectl apply -f k8s/nginx.yaml
pod/my-pod created
service/my-service created
Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % 

Get puplic IP:
Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % kubectl get nodes -o wide
NAME                                        STATUS   ROLES    AGE   VERSION               INTERNAL-IP   EXTERNAL-IP     OS-IMAGE                        KERNEL-VERSION                     CONTAINER-RUNTIME
ip-10-0-0-37.af-south-1.compute.internal    Ready    <none>   65m   v1.35.8-eks-b9510e3   10.0.0.37     13.244.151.18   Amazon Linux 2023.12.20261012   6.12.111-136.204.amzn2023.x86_64   containerd://2.3.5+unknown
ip-10-0-1-153.af-south-1.compute.internal   Ready    <none>   65m   v1.35.8-eks-b9510e3   10.0.1.153    13.246.30.2     Amazon Linux 2023.12.20261012   6.12.111-136.204.amzn2023.x86_64   containerd://2.3.5+unknown

Open in browser:
http://13.244.151.18:30007
http://13.246.30.2:30007

>> Networking works (nginx welcome page reached)

14. 
Idempotency (repeated execution reaches the same system state) check:
terraform plan -var-file=envs/dev/dev.tfvars

Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % terraform plan -var-file=envs/dev/dev.tfvars
module.eks.data.aws_caller_identity.current: Reading...
module.eks.aws_iam_role.cluster: Refreshing state... [id=olivier-m-eks-iam-role-dev]
module.eks.aws_vpc.main: Refreshing state... [id=vpc-097c2b41bc3433f7e]
module.eks.aws_iam_role.node: Refreshing state... [id=olivier-m-eks-node-role-dev]
module.eks.data.aws_caller_identity.current: Read complete after 0s [id=<account-id>]
module.eks.aws_internet_gateway.main: Refreshing state... [id=igw-0f08da5c9aacce0ef]
module.eks.aws_subnet.public[1]: Refreshing state... [id=subnet-08c81a8c35de71a33]
module.eks.aws_subnet.public[0]: Refreshing state... [id=subnet-0eea4e5f08bee4796]
module.eks.aws_subnet.public[2]: Refreshing state... [id=subnet-07a0e09014e408ff2]
module.eks.aws_route_table.public: Refreshing state... [id=rtb-07f0b193bf47ca04c]
module.eks.aws_route_table_association.public[2]: Refreshing state... [id=rtbassoc-0e0d7900cc29ced83]
module.eks.aws_route_table_association.public[0]: Refreshing state... [id=rtbassoc-094608cca04f80625]
module.eks.aws_route_table_association.public[1]: Refreshing state... [id=rtbassoc-0de91328e3084cb3c]
module.eks.aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy: Refreshing state... [id=olivier-m-eks-iam-role-dev/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy]
module.eks.aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy: Refreshing state... [id=olivier-m-eks-node-role-dev/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy]
module.eks.aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy: Refreshing state... [id=olivier-m-eks-node-role-dev/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy]
module.eks.aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly: Refreshing state... [id=olivier-m-eks-node-role-dev/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly]
module.eks.aws_eks_cluster.main: Refreshing state... [id=olivier-m-eks-dev]
module.eks.aws_eks_access_entry.admin: Refreshing state... [id=olivier-m-eks-dev:arn:aws:iam::<account-id>:user/capitec-batch-4]
module.eks.aws_security_group_rule.nodeport_ingress: Refreshing state... [id=sgrule-3412228993]
module.eks.aws_eks_node_group.main: Refreshing state... [id=olivier-m-eks-dev:olivier-m-eks-nodes-dev]
module.eks.aws_eks_access_policy_association.admin: Refreshing state... [id=olivier-m-eks-dev#arn:aws:iam::<account-id>:user/capitec-batch-4#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.


15. 
Destroy dev environment to prove clean teardown:

kubectl delete -f k8s/nginx.yaml

**** OUTPUT IN TERMINAL ****

Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % kubectl delete -f k8s/nginx.yaml
pod "my-pod" deleted from default namespace
service "my-service" deleted from default namespace
*****************************

terraform destroy -var-file=envs/dev/dev.tfvars

**** OUTPUT IN TERMINAL (last part)****
module.eks.aws_vpc.main: Destroying... [id=vpc-097c2b41bc3433f7e]
module.eks.aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy: Destruction complete after 1s
module.eks.aws_iam_role.cluster: Destroying... [id=olivier-m-eks-iam-role-dev]
module.eks.aws_vpc.main: Destruction complete after 1s
module.eks.aws_iam_role.cluster: Destruction complete after 1s

Destroy complete! Resources: 20 destroyed.
*****************************

16. 
Automate with GitHub Actions

WHY?
>> Pull Requests: Let GitHub run "plan"
>> Merges: Let GitHub run "apply"

Enabled workflows.

17. 
Create OIDC (Open ID Connect) role

WHY?
>> Must exist before pipeline can log in

I ran the following:

cd bootstrap/github-oidc

terraform init

terraform apply -var="github_org=marietinkaolivier99-dot" -var="github_repo=Terraform-Project-Cap"
>> gave a thumbprint error.

Thumbprint list removed from bootstrap/github-oidc/main.tf since AWS no longer needs thumbprints for GitHub (apparently since 2023 - checks GH's cert against its own list of trusterd certificate auths).
Instead, I removed linew 29-43 and added: 

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

terraform plan -var="github_org=marietinkaolivier99-dot" -var="github_repo=Terraform-Project-Cap"

Role & policy imported
terraform import -var="github_org=marietinkaolivier99-dot" -var="github_repo=Terraform-Project-Cap" aws_iam_role.github_actions github-actions-Terraform-Project-Cap

terraform import -var="github_org=marietinkaolivier99-dot" -var="github_repo=Terraform-Project-Cap" aws_iam_role_policy.github_actions github-actions-Terraform-Project-Cap:terraform-apply

terraform apply -var="github_org=marietinkaolivier99-dot" -var="github_repo=Terraform-Project-Cap"

ARN:
terraform output github_actions_role_arn
"arn:aws:iam::<account-id>:role/github-actions-Terraform-Project-Cap"


18. 
Store ARN in GitHub - New variable created in Github:
Name: AWS_ROLE_ARN
Value: arn:aws:iam::<account-id>:role/github-actions-Terraform-Project-Cap

WHY?
>> Workflow needs the variable to know which role to use.

19. 
Remove stored passwords from workflow
(in .github/workflows/terraform.yml)

All four jobs (plan, apply, manual, destroy-all)
aws-access-key-id 
&
aws-secret-access-key
= REPLACED WITH: role-to-assume: ${{ vars.AWS_ROLE_ARN }}

WHY?
>> No long-lived keys allowed (according to the brief).


Commit and push:
git add .github/workflows/terraform.yml
git commit -m "ci: use OIDC role instead of static AWS keys"
git push -u origin main


*** OUTPUT ***
Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % gh pr checks 1 --repo marietinkaolivier99-dot/Terraform-Project-Cap
All checks were successful
0 cancelled, 0 failing, 4 successful, 3 skipped, and 0 pending checks

   NAME                                                                                    DESCRIPTION  ELAPSED  URL                                                                                   
✓  Terraform/Plan (dev) (pull_request)                                                                  30s      https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
✓  Terraform/Plan (prod) (pull_request)                                                                 35s      https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
✓  Terraform/Plan (qa) (pull_request)                                                                   29s      https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
-  Terraform/Apply (${{ matrix.env }}) (pull_request)                                                            https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
-  Terraform/Destroy All Environments (pull_request)                                                             https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
✓  Terraform/Format & validate (pull_request)                                                           18s      https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
-  Terraform/Manual ${{ github.event.inputs.action }} (${{ github.event.inputs.environ...                        https://github.com/marietinkaolivier99-dot/Terraform-Project-Cap/actions/runs/39917...
Marie-TinkaOlivier@CMAC-CTXPF215WG Terraform-Project-Cap % 
***

20. 
Required reviewers (human) andded in Github for Prod.

21. 
I set the workflow with action = destroy to only the "manual" job so each environment can be destroyed on its own and that prod cannot be wiped by accident (des)
(destroy-all job in  .github/workflows/terraform.yml deleted)

22. 
Updated access entry for CI in eks.tf to:

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

and prinicipal ARN to:
  principal_arn = data.aws_iam_session_context.current.issuer_arn

23. 
Add chekcsum for Linux on Github:

terraform providers lock -platform=linux_amd64 -platform=darwin_arm64

24. 
Destroyed dev environment using:
terraform destroy -var-file=envs/dev/dev.tfvars

*********************************************************************************************************
PROJECT STRUCTURE & WITH TRADE-OFFS AND LIMITATIONS
*********************************************************************************************************
1. Project Structure
   WHAT 
    * envs/ 
        - one .tfvars file for each environment (dev, qa, prod)
        -  one backend file for each environment(.tfbackend)

    * modules/capitec_eks/
        - reusable code for cluster
        - reusable code for network
        - reusable code for IAM roles

        >> the modules are called by main.tf

    * bootstrap
        - run once at setup for state buckets and GitHub login role.       

   WHY
     >> 3 x required environments (dev, qa, prod) served by a singly copy of the code for DRY purposes ("Don't Repeat Yourself")


 2. Environment Deploy
   WHAT 
    * Commands run from project (root /Terraform-Project-Cap)

        - terraform init -reconfigure       -backend-config=envs/<env>/<env>.tfbackend  
        - terraform plan -var-file=envs/<env>/<env>.tfvars
        - terraform apply -var-file=envs/<env>/<env>.tfvars

   WHY
     >> .tfbackend - where the state is stored
     >> .tfvars - what the environment should look like
     >> used together to prevent using dev state with prod settings.

3. State and Backend - Strategy
   WHAT 
    * State
        - record of what was built by Terraform 
        - in S3
        - one S3 bucket per environment (dev,qa,prod)

    * Versioning    
        - keep copies
        - encryption implemented to protect contents
        - public access blocked

    * Locking   
        - use_lockfile set to true
        - prevent simultaneous runs to change the same state.

   WHY
     >> bootstrap created first locally since there must exist a state bucket before it can be used by Terraform.


 4. Trade-offs and Limitations
    4.1
    WHAT 
        * Worker Nodes = in Public Subnet
    PROS       
        >> simpler
        >> cheaper
    CONS
        >> less secure (compared to private subnets behind a Network Address Translation - NAT - gateway)


    4.2
    WHAT 
        * Port 30007 = open to anyone
    PROS       
        >> easy to configure
        >> does not require a load balancer/ ingress controller (complex)
        >> quick for development and testing
    CONS
        >> Firewall & security risk
        >> Secure traffic handling not built in, must be configured higher up.
        >> Port range is limited - thus not ideal for large-scale production (which is not necessary for this project anyway)

    4.3
        WHAT 
            * CI (Continuous Integration) permissions = broad/ unrestricted (ec2:* ; eks:* >> the asterisk * is a wildcard indicating that it is allowed to perform any possible action, including deletes, modifications,etc. ) - i.e., GitHub as full administrative control over the EC2 Virtual Servers and the EKS clusters.
        PROS       
            >> easy to deploy
            >> low maintenance
            >> easy to set up initially (for build and test)
        CONS
            >> the unrestricted permissions implies no safety net upon accidental destroy (for example)
            >> not production-compliant
*********************************************************************************************************


Thank you :)