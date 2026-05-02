# oficina-infra-db

Infraestrutura do banco de dados da Oficina API.

Este repositorio cria apenas a infraestrutura do Amazon RDS SQL Server Express usada pela API principal do repositorio `oficina-api`.

## Objetivo do repositorio

Manter uma infraestrutura simples para:

- configurar secrets no GitHub;
- rodar check e plan em pull requests para `main`;
- provisionar o banco manualmente por GitHub Actions;

## Arquitetura criada

Regiao padrao:

```text
us-east-1
```

O Terraform cria:

- VPC simples;
- 2 subnets publicas em Availability Zones diferentes;
- Internet Gateway;
- Route Table publica;
- Security Group do RDS;
- DB Subnet Group;
- Amazon RDS for SQL Server Express.

O RDS fica publicamente acessivel para facilitar testes locais, mas a porta `1433` fica restrita no Security Group a:

- `operator_cidr`: IP publico do operador em formato `/32`;
- `vpc_cidr`: CIDR da VPC para uso futuro pela API/Lambda dentro da VPC.

Nao existe regra de banco para `0.0.0.0/0`.

## Recursos AWS provisionados

RDS:

```text
Engine: sqlserver-ex
Edition: SQL Server Express
Instance class: db.t3.micro
Storage: 20 GB
Storage type: gp2
Port: 1433
Publicly accessible: true
Multi-AZ: false
Enhanced Monitoring: disabled
Performance Insights: disabled
Backup retention: 0
Deletion protection: false
```

O banco logico esperado pela aplicacao e `OficinaDb`. As tabelas e migrations sao aplicadas pelo repositorio `oficina-api`.

## Secrets necessarios

Configure em:

```text
GitHub > Settings > Secrets and variables > Actions
```

Secrets obrigatorios:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
AWS_REGION
TF_STATE_BUCKET
TF_VAR_db_username
TF_VAR_db_password
TF_VAR_operator_cidr
```

Use:

```text
AWS_REGION = us-east-1
```

`TF_VAR_operator_cidr` deve ser o IP publico do operador com `/32`.

Exemplo:

```text
200.100.50.25/32
```

Para descobrir seu IP publico no PowerShell:

```powershell
Invoke-RestMethod https://checkip.amazonaws.com
```

Nao versione secrets reais. Arquivos `*.tfvars` e `.env` devem permanecer locais.

## Bucket S3 do Terraform state

O backend S3 usa a key definida em `terraform/backend.tf`:

```text
oficina-infra-db/academy/terraform.tfstate
```

Informe o nome do bucket no secret:

```text
TF_STATE_BUCKET
```

Os workflows `terraform-plan` e `terraform-apply`  garantem antes do `terraform init`:

- criacao do bucket, se ainda nao existir;
- versionamento;
- criptografia SSE-S3;
- bloqueio de acesso publico.

Comando usado para bloqueio publico:

```bash
aws s3api put-public-access-block \
  --bucket "${TF_STATE_BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Se o bucket ja existir em outra conta AWS, escolha outro nome globalmente unico para `TF_STATE_BUCKET`.

## Abrir PR e validar check/plan

Abra um pull request para `main`.

Devem rodar automaticamente:

- `Terraform Check`;
- `Terraform Plan`.

O `Terraform Check` executa:

- checkout;
- setup Terraform;
- `terraform fmt -check -recursive`;
- `terraform init -backend=false`;
- `terraform validate`.

O `Terraform Plan` executa:

- checkout;
- setup Terraform;
- configuracao das credenciais AWS;
- garantia do bucket S3 do state;
- `terraform init` com backend S3;
- `terraform plan`.

Quando check e plan estiverem verdes, faca merge na `main`.

## Executar apply manual

Depois do merge:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow `Terraform Apply` e manual e executa:

- checkout;
- setup Terraform;
- configuracao das credenciais AWS;
- garantia do bucket S3 do state;
- `terraform init`;
- `terraform apply -auto-approve`.

## Executar destroy manual

Para destruir a infraestrutura:

```text
GitHub Actions > Terraform Destroy > Run workflow
```

Informe exatamente:

```text
DESTROY
```

O workflow executa `terraform destroy -auto-approve` apenas depois dessa confirmacao manual.

## Validar RDS criado no Console AWS

Acesse:

```text
AWS Console > RDS > Databases
```

Valide:

- status `Available`;
- engine `SQL Server Express`;
- endpoint preenchido;
- public accessibility habilitado;
- Security Group sem regra `0.0.0.0/0` para porta `1433`.

## Validar RDS via AWS CLI

```powershell
aws rds describe-db-instances `
  --region us-east-1 `
  --query "DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,Endpoint.Address,PubliclyAccessible]"
```

Resultado esperado:

```text
available
sqlserver-ex
endpoint preenchido
PubliclyAccessible = true
```

## Conectar via SSMS

No SQL Server Management Studio:

Server name:

```text
<rds-endpoint>,1433
```

Authentication:

```text
SQL Server Authentication
```

Login:

```text
<db_username>
```

Password:

```text
<db_password>
```

Em Options, marque `Trust Server Certificate` se aparecer. Use `Encrypt` e `Trust` conforme necessario para conexao com RDS.

## Aplicar migrations vindas do oficina-api

As migrations ficam no repositorio `oficina-api`.

No repo `oficina-api`, gere o script idempotente:

```powershell
dotnet ef migrations script --idempotent `
  --project src/Oficina.Infrastructure `
  --startup-project src/Oficina.Api `
  --output oficina-migrations.sql
```

Aplique no RDS:

```powershell
sqlcmd -S <rds-endpoint>,1433 `
  -d OficinaDb `
  -U <usuario> `
  -P "<senha>" `
  -C `
  -i oficina-migrations.sql
```

Valide as tabelas:

```powershell
sqlcmd -S <rds-endpoint>,1433 `
  -d OficinaDb `
  -U <usuario> `
  -P "<senha>" `
  -C `
  -Q "SELECT name FROM sys.tables ORDER BY name"
```

Valide as migrations:

```powershell
sqlcmd -S <rds-endpoint>,1433 `
  -d OficinaDb `
  -U <usuario> `
  -P "<senha>" `
  -C `
  -Q "SELECT * FROM __EFMigrationsHistory"
```
