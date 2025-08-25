# Modular Portfolio Deployment (Portfolio + Blog)

Two containers:
- **portfolio/** → Home, Experience, Projects (served on :8080)
- **blog/** → Blog list + posts (served on :8081)

## Deploy with Terraform
```
cd terraform
terraform init
terraform apply -auto-approve   -var region=ap-south-1   -var ami_id=ami-xxxxxxxx   -var key_name=your-keypair
```
Grab the `public_ip` output for GitHub Actions secrets.

## Configure GitHub Secrets
- `EC2_HOST` → your instance public IP
- `EC2_USER` → usually `ubuntu`
- `EC2_SSH_KEY` → contents of your private key (BEGIN/END lines included)

On push to **portfolio/** or **blog/**, CI uploads files to EC2 and rebuilds containers.

## Local build
```
docker build -t portfolio:latest ./portfolio
docker run -d -p 8080:80 portfolio:latest

docker build -t blog:latest ./blog
docker run -d -p 8081:80 blog:latest
```
