# terraform-import-irsa
A minimal example of the issues using `terraform import` with the  terraform-aws-modules/iam/aws/latest/submodules/iam-role-for-service-accounts module.

## Deploy the Template
```bash
terraform init
terraform apply
```

## Delete State to Simulate Upgrade
```bash
terraform state show 'module.eks.aws_cloudwatch_log_group.this[0]'

# module.eks.aws_cloudwatch_log_group.this[0]:
resource "aws_cloudwatch_log_group" "this" {
    arn                         = "arn:aws:logs:ap-southeast-2:123456789012:log-group:/aws/eks/terraform-import-irsa/cluster"
    deletion_protection_enabled = false
    id                          = "/aws/eks/terraform-import-irsa/cluster"
    kms_key_id                  = null
    log_group_class             = "STANDARD"
    name                        = "/aws/eks/terraform-import-irsa/cluster"
    name_prefix                 = null
    region                      = "ap-southeast-2"
    retention_in_days           = 90
    skip_destroy                = false
    tags                        = {
        "Name" = "/aws/eks/terraform-import-irsa/cluster"
    }
    tags_all                    = {
        "Name" = "/aws/eks/terraform-import-irsa/cluster"
    }
}

terraform state rm 'module.eks.aws_cloudwatch_log_group.this[0]'
```

## Attempt to Import Resource
```bash
terraform import 'module.eks.aws_cloudwatch_log_group.this[0]' '/aws/eks/terraform-import-irsa/cluster'
module.eks.aws_cloudwatch_log_group.this[0]: Importing from ID "/aws/eks/terraform-import-irsa/cluster"...
...
module.eks.aws_cloudwatch_log_group.this[0]: Import prepared!
  Prepared aws_cloudwatch_log_group for import
...
╷
│ Error: Invalid count argument
│ 
│   on .terraform/modules/vpc_cni_irsa/modules/iam-role-for-service-accounts/main.tf line 135, in data "aws_iam_policy_document" "this":
│  135:   count = local.create_policy ? 1 : 0
│ 
│ The "count" value depends on resource attributes that cannot be determined until apply, so Terraform cannot predict how many instances will be created. To work around this, use the
│ -target argument to first apply only the resources that the count depends on.
╵
```
