# Homelab AWS Terraform

This project creates AWS support resources for the homelab: one S3 bucket for backups, two IAM users with scoped policies, and Secrets Manager secret containers.

It does not create IAM access keys and it does not store secret values in Terraform state.

Terraform state is stored in the S3 bucket `homelab-tf-state-rubenspensky` using S3 native lockfiles (`use_lockfile = true`), without DynamoDB.

## Resources

- S3 bucket: `homelab-backups-<aws-account-id>`
- IAM user: `homelab-s3-backups`
- IAM user: `homelab-secrets-reader`
- Secret: `homelab/cloudflare/tunnel-token`
- Secret: `homelab/github/arc-app`

The backups bucket has versioning, server-side encryption, public access blocking, and a lifecycle rule enabled by default.

## Usage

The state bucket must exist before `terraform init`. It is intentionally bootstrapped outside this project so Terraform does not manage its own backend bucket.

```sh
terraform init
terraform plan
terraform apply
```

If a local state already exists, migrate it to S3 with:

```sh
terraform init -migrate-state
```

Optional local variables file:

```sh
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` is ignored by Git.

## Create IAM Access Keys Manually

Create access keys outside Terraform so credentials are not stored in Terraform state.

```sh
aws iam create-access-key --user-name homelab-s3-backups
aws iam create-access-key --user-name homelab-secrets-reader
```

Store the resulting `AccessKeyId` and `SecretAccessKey` in your Kubernetes secret management flow.

## Put Secret Values

Cloudflare tunnel token:

```sh
aws secretsmanager put-secret-value \
  --secret-id homelab/cloudflare/tunnel-token \
  --secret-string '{"token":"REPLACE_ME"}'
```

ARC GitHub App:

```sh
aws secretsmanager put-secret-value \
  --secret-id homelab/github/arc-app \
  --secret-string '{"github_app_id":"REPLACE_ME","github_app_installation_id":"REPLACE_ME","github_app_private_key":"REPLACE_ME"}'
```

Do not commit real secret values, access keys, Terraform state, or local `.tfvars` files.

## State Bucket Bootstrap

The S3 backend bucket is `homelab-tf-state-rubenspensky` in `us-east-2`.

If it ever needs to be recreated, bootstrap it manually before running Terraform:

```sh
aws s3api create-bucket \
  --bucket homelab-tf-state-rubenspensky \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

aws s3api put-bucket-versioning \
  --bucket homelab-tf-state-rubenspensky \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket homelab-tf-state-rubenspensky \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket homelab-tf-state-rubenspensky \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```
