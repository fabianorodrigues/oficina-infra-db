# oficina-infra-db

## Visão geral

Este repositório faz parte da Fase 3 do Tech Challenge FIAP e provisiona a infraestrutura do banco de dados gerenciado da Oficina API.

A infraestrutura é criada com Terraform e entrega um Amazon RDS SQL Server Express usado pela aplicação principal e pela Lambda de autenticação. O repositório também expõe outputs de rede e conexão para integração com os demais componentes.

Os componentes ficam separados por responsabilidade:

| Repositório | Responsabilidade |
|---|---|
| `oficina-infra-db` | Infraestrutura do banco de dados, rede mínima e outputs de integração |
| `oficina-api` | API principal e migrations da aplicação |
| `oficina-auth-lambda` | Lambda Auth e Lambda Authorizer |
| `oficina-infra-k8s` | Infraestrutura Kubernetes |

## Arquitetura provisionada

O Terraform provisiona os seguintes recursos:

- VPC;
- subnets públicas;
- Internet Gateway;
- Route Table pública;
- Security Group do RDS;
- Security Group da Lambda Auth;
- DB Subnet Group;
- Amazon RDS SQL Server Express;
- bucket S3 para Terraform State, criado ou validado pelo workflow manual.

Diagrama simplificado:

```text
Cliente local / SSMS / sqlcmd / API local
        |
        v
RDS SQL Server Express

Lambda Auth
        |
        v
RDS SQL Server Express
```
## Workflows:

| Workflow | Quando executa | Finalidade |
|---|---|---|
| `Terraform Check` | Pull Request para `main` | Validar formatação, inicialização sem backend e sintaxe do Terraform |
| `Terraform Apply` | Manual | Validar secrets, preparar state remoto, executar plan, aplicar infraestrutura e exibir outputs seguros |

## Secrets necessários no GitHub

Configure os secrets em:

```text
GitHub > Settings > Secrets and variables > Actions
```

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key do AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Secret Key do AWS Academy |
| `AWS_SESSION_TOKEN` | Token temporário do AWS Academy |
| `AWS_REGION` | Região AWS |
| `TF_STATE_BUCKET` | Bucket S3 do Terraform State |
| `TF_VAR_db_username` | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Senha do SQL Server |
| `TF_VAR_operator_cidr` | Seu IP público com `/32` |


Para descobrir seu IP público no PowerShell:

```powershell
Invoke-RestMethod https://checkip.amazonaws.com
```

Cadastre o valor de `TF_VAR_operator_cidr` com `/32`:

```text
<seu-ip-publico>/32
```

## Terraform State

O Terraform State usa backend S3.

O nome do bucket vem do secret `TF_STATE_BUCKET`, e a região vem de `AWS_REGION`. O workflow passa esses valores ao backend com `terraform init -backend-config`, sem versionar bucket real nem região de deploy no backend.

Antes do `terraform init`, o workflow manual garante que o bucket exista e esteja configurado com:

- versionamento;
- criptografia SSE-S3;
- bloqueio de acesso público.

O workflow `Terraform Check` usa `terraform init -backend=false`, portanto Pull Requests não dependem de credenciais AWS nem acessam o backend remoto.

## Fluxo de provisionamento

### 1. Abrir Pull Request

Crie uma branch com as alterações de infraestrutura e abra um Pull Request para `main`.

O Pull Request deve executar automaticamente apenas:

- `Terraform Check`.

Esse check valida:

- formatação do Terraform com `terraform fmt -check -recursive`;
- inicialização sem backend remoto com `terraform init -backend=false`;
- sintaxe e configuração com `terraform validate`.

### 2. Fazer merge na main

Faça merge na `main` somente depois que o Pull Request estiver aprovado e com `Terraform Check` verde.

### 3. Executar apply manual

Depois do merge, execute:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow manual executa:

- validação dos secrets obrigatórios sem imprimir valores;
- configuração das credenciais AWS;
- criação ou validação do bucket S3 do state;
- `terraform init` com backend remoto;
- `terraform plan` para evidência no log;
- `terraform apply -auto-approve`;
- exibição de outputs úteis sem senha;
- validação da instância RDS pela AWS CLI.

## Outputs para integração

Após o `Terraform Apply`, use os outputs para configurar os demais repositórios.

Para o `oficina-auth-lambda`, use:

- `db_address`;
- `db_port`;
- `db_name`;
- `db_connection_string_without_password`;
- `lambda_subnet_ids`;
- `lambda_security_group_ids`.

A connection string não contém usuário nem senha. A senha deve continuar vindo de secret do ambiente consumidor.

## Validar RDS criado

### Pelo Console AWS

Acesse:

```text
AWS Console > RDS > Databases
```

Valide:

- status `Available`;
- engine `SQL Server Express`;
- endpoint preenchido;
- porta `1433`;
- Security Group sem regra `0.0.0.0/0` para a porta `1433`;
- entrada `1433` permitida para o IP `/32` do operador;
- entrada `1433` permitida para o Security Group da Lambda Auth.

### Pela AWS CLI

O workflow `Terraform Apply` valida automaticamente a instância usando o output `db_instance_identifier`.

Consulta equivalente:

```powershell
aws rds describe-db-instances --db-instance-identifier <db_instance_identifier> --region us-east-1 --query "DBInstances[0].[DBInstanceStatus,Engine,Endpoint.Address,Endpoint.Port,PubliclyAccessible]"
```

Resultado esperado:

```text
available
sqlserver-ex
endpoint preenchido
porta 1433
PubliclyAccessible = true
```
