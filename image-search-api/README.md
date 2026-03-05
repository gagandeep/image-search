# Royalty-Free Image Search API

A production-grade FastAPI application providing a unified image search API aggregating results from a local Typesense index (Unsplash Lite dataset) and multiple third-party image providers (Unsplash, Pexels, Pixabay, Freepik).

## Features
- Aggregates search results from multiple sources
- Defaults to a local Typesense index
- Rate limits aware provider routing (using Redis)
- Deduplication and Sorting
- Async non-blocking architecture

## Setup

1. Configure `.env` based on `env.example`. Ensure your `POSTGRES_URL` points to an existing database containing the Unsplash Lite dataset.
2. Run `docker-compose up -d`.
3. The API will be available at `http://localhost:8000/docs`.

### Typesense Population
The `docker-compose.yml` spins up Typesense and Redis, but expects your PostgreSQL dataset to be hosted externally (e.g. AWS RDS or another container).
To populate your Typesense instance from your database, run the ingestion script:

```bash
docker-compose exec api python scripts/populate_typesense.py
```

## Terraform Deployment (AWS EC2)

You can provision an EC2 instance ready to host this API using Terraform.

1. Navigate to `terraform/`.
2. Generate an SSH keypair: `ssh-keygen -t rsa -b 4096 -f ./deploy_key`
3. Initialize and apply:
```bash
terraform init
terraform plan -var="public_key=$(cat ./deploy_key.pub)"
terraform apply -var="public_key=$(cat ./deploy_key.pub)"
```
4. Terraform will output the public IP of the instance.
5. SSH into the instance: `ssh -i ./deploy_key ubuntu@<OUTPUT_IP>`
6. Clone the repository and run `docker-compose up -d`.
