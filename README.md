# oficina-infra-db

## Visão geral

Este repositório faz parte da Fase 3 do Tech Challenge FIAP e provisiona a infraestrutura do banco de dados gerenciado da Oficina API.

A infraestrutura é criada com Terraform e entrega um Amazon RDS SQL Server Express usado pela aplicação principal e pela Lambda de autenticação.

Os demais componentes ficam em repositórios separados:

| Repositório | Responsabilidade |
|---|---|
| `oficina-infra-db` | Infraestrutura do banco de dados |
| `oficina-api` | API principal e migrations da aplicação |
| `oficina-auth-lambda` | Lambda Auth e Lambda Authorizer |

## Conteúdo deste repositório

- Terraform da infraestrutura do banco;
- VPC e subnets;
- Security Groups;
- DB Subnet Group;
- Amazon RDS SQL Server Express;
- workflows de validação, plano e provisionamento manual.

Os workflows esperados são:

| Workflow | Quando executa | Finalidade |
|---|---|---|
| `Terraform Check and Plan` | Pull Request para `main` | Validar formatação, validar Terraform e gerar plano |
| `Terraform Apply` | Manual | Provisionar ou atualizar a infraestrutura |

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
- bucket S3 para Terraform State, criado ou validado pelo workflow.

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

O RDS fica publicamente acessível para facilitar testes locais, mas a porta `1433` deve ficar restrita a:

- IP público do operador, informado em `TF_VAR_operator_cidr` com `/32`;
- Security Group da Lambda Auth.

Não deve existir regra de entrada `1433` aberta para `0.0.0.0/0`.

## Secrets necessários no GitHub

Configure os secrets em:

```text
GitHub > Settings > Secrets and variables > Actions
```

| Secret | Descrição | Exemplo |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key do AWS Academy | keyId1234 |
| `AWS_SECRET_ACCESS_KEY` | Secret Key do AWS Academy | accessKey12345 |
| `AWS_SESSION_TOKEN` | Token temporário do AWS Academy | expira |
| `AWS_REGION` | Região AWS | `us-east-1` |
| `TF_STATE_BUCKET` | Bucket S3 do Terraform State | `oficina-tfstate-xpto` |
| `TF_VAR_db_username` | Usuário administrador do SQL Server | user |
| `TF_VAR_db_password` | Senha do SQL Server | senha123 |
| `TF_VAR_operator_cidr` | Seu IP público com `/32` | `000.000.00.00/32` |

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

O nome do bucket vem do secret `TF_STATE_BUCKET`. Antes do `terraform init`, os workflows garantem que o bucket exista e esteja configurado com:

- versionamento;
- criptografia SSE-S3;
- bloqueio de acesso público.

## Fluxo de provisionamento

### 1. Abrir Pull Request

Crie uma branch com as alterações de infraestrutura e abra um Pull Request para `main`.

O Pull Request deve executar automaticamente:

- `Terraform Check`;
- `Terraform Plan`.

### 2. Validar check/plan

Antes do merge, confirme que os workflows estão verdes.

O check valida:

- formatação do Terraform;
- inicialização sem backend;
- validação da configuração.

O plan valida:

- credenciais AWS;
- bucket S3 do Terraform State;
- inicialização com backend S3;
- plano de alteração da infraestrutura.

### 3. Fazer merge na main

Faça merge na `main` somente depois que o Pull Request estiver aprovado e com check/plan verdes.

### 4. Executar apply manual

Depois do merge, execute:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow executa:

- `terraform init`;
- `terraform apply -auto-approve`.

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

Use:

```powershell
aws rds describe-db-instances --region us-east-1 --query "DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,Endpoint.Address,Endpoint.Port,PubliclyAccessible]"
```

Resultado esperado:

```text
available
sqlserver-ex
endpoint preenchido
porta 1433
PubliclyAccessible = true
```