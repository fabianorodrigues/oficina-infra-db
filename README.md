# oficina-infra-db

## Visão geral

Este repositório provisiona a base de dados e a rede inicial da solução Oficina API. Ele representa a primeira etapa da implantação e entrega os recursos que serão consumidos pelos repositórios de Kubernetes, API e autenticação.

O Terraform cria uma VPC, subnets públicas, Internet Gateway, security groups e uma instância Amazon RDS SQL Server Express.

## Arquitetura e ordem de implantação

1. **`oficina-infra-db`**: cria VPC, subnets, security groups e RDS.
2. `oficina-infra-k8s`: consome VPC/subnets e cria ECR/EKS.
3. `oficina-api`: publica a imagem no ECR, executa migrations e sobe no EKS.
4. `oficina-auth-lambda`: publica as Lambdas de autenticação e autorização.
5. `oficina-infra-k8s`: etapa futura para API Gateway.

## Responsabilidade deste repositório

- Provisionar a rede base da solução.
- Provisionar o RDS SQL Server Express.
- Liberar acesso administrativo ao RDS apenas para o CIDR do operador.
- Gerar os outputs usados pelos demais repositórios.

## Integração com os outros repositórios

Este repositório inicia a infraestrutura compartilhada. Ele não consome outputs de outros repositórios.

### Valores consumidos

| Valor | Origem | Uso |
|---|---|---|
| Não aplicável | - | Este repositório inicia a infraestrutura base |

### Valores gerados

| Output | Usado por | Formato de cópia |
|---|---|---|
| `db_address`, `db_port`, `db_name` | `oficina-api`, `oficina-auth-lambda` | Montar `DB_CONNECTION_STRING` com usuário e senha do banco |
| `vpc_id` | `oficina-infra-k8s` | Copiar como string para `TF_VAR_vpc_id`, exemplo `vpc-abc` |
| `subnet_ids` | `oficina-infra-k8s` | Copiar como JSON para `TF_VAR_subnet_ids`, exemplo `["subnet-abc","subnet-def"]` |
| `vpc_cidr_block` | `oficina-infra-k8s` | Referência de rede |
| `lambda_subnet_ids` | `oficina-auth-lambda` | Converter de JSON para CSV em `LAMBDA_SUBNET_IDS`, exemplo `["subnet-abc","subnet-def"]` -> `subnet-abc,subnet-def` |
| `lambda_security_group_ids` | `oficina-auth-lambda` | Converter de JSON para CSV em `LAMBDA_SECURITY_GROUP_IDS`, exemplo `["sg-abc","sg-def"]` -> `sg-abc,sg-def` |

Modelo de connection string para consumidores:

```text
Server=<db_address>,<db_port>;Database=<db_name>;User Id=<db-user>;Password=<db-password>;Encrypt=True;TrustServerCertificate=True;
```

## Configuração necessária

Configure os valores em `GitHub > Settings > Secrets and variables > Actions`.

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Autenticar na AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticar na AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Autenticar com credencial temporária |
| `AWS_REGION` | Secret | Região AWS, exemplo `us-east-1` |
| `TF_STATE_BUCKET` | Secret | Bucket S3 do Terraform State remoto |
| `TF_VAR_db_username` | Secret | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Secret | Senha do SQL Server |
| `TF_VAR_operator_cidr` | Secret | IP público do operador em formato `/32` |

Para descobrir o IP público no PowerShell:

```powershell
Invoke-RestMethod https://checkip.amazonaws.com
```

Configure `TF_VAR_operator_cidr` como `<seu-ip-publico>/32`.

Para execução local opcional, copie o exemplo e preencha os valores:

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Não versione `terraform.tfvars` real.

## Como executar

Em Pull Requests, o workflow `Terraform Check` valida formatação e configuração Terraform.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow prepara o backend remoto, executa `terraform plan`, aplica a infraestrutura e exibe os outputs úteis sem imprimir senha.

## Como validar

Consulte os outputs:

```powershell
terraform output
```

Valide o RDS:

```powershell
aws rds describe-db-instances --db-instance-identifier oficina-sqlserver --region <region> --query "DBInstances[0].[DBInstanceStatus,Engine,Endpoint.Address,Endpoint.Port,PubliclyAccessible]"
```

Resultado esperado:

- status `available`;
- engine `sqlserver-ex`;
- endpoint e porta preenchidos;
- acesso público restrito ao `TF_VAR_operator_cidr`;
- acesso ao RDS permitido para o security group da Lambda Auth e para o CIDR da VPC.

## Problemas comuns

| Problema | Possível causa | Como resolver |
|---|---|---|
| `terraform validate` falha | Arquivo Terraform inválido ou mal formatado | Rode `terraform fmt -recursive` e revise o erro |
| Workflow manual falha por secret ausente | Configuração obrigatória não criada | Revise a tabela de configuração |
| RDS não fica `available` | Criação ainda em andamento | Aguarde alguns minutos e valide novamente |
| Acesso local ao SQL Server falha | `TF_VAR_operator_cidr` incorreto | Atualize o secret com o IP público atual em formato `/32` |
| Lambda não acessa o RDS | Subnets ou security groups incorretos no repo da Lambda | Use `lambda_subnet_ids` e `lambda_security_group_ids` deste repo |

## Próxima etapa

Siga para o repositório `oficina-infra-k8s` e configure `TF_VAR_vpc_id` e `TF_VAR_subnet_ids` com os outputs deste repositório.
