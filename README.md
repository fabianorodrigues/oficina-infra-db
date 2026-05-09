# oficina-infra-db

## Visão geral

Este repositório provisiona a base de dados e a rede inicial da Oficina API. Ele é a **etapa 1** da implantação da solução.

O Terraform cria um Amazon RDS SQL Server Express, VPC, subnets públicas e security groups. Os outputs deste repositório alimentam o `oficina-infra-k8s`, o `oficina-api` e o `oficina-auth-lambda`.

## Ordem de implantação da solução

1. **`oficina-infra-db`**
2. `oficina-infra-k8s`
3. `oficina-api`
4. `oficina-auth-lambda`
5. `oficina-infra-k8s` novamente para API Gateway
## Responsabilidade

Este repositório é responsável por:

- provisionar VPC, subnets públicas, Internet Gateway e rota pública;
- provisionar security groups para RDS e Lambda Auth;
- provisionar o RDS SQL Server Express;
- expor outputs de rede e conexão para os demais repositórios.

## Pré-requisitos

- Conta AWS com permissões para RDS, VPC, EC2 Security Groups e S3.
- Terraform instalado para validação local.
- AWS CLI instalada para validação opcional.
- GitHub Secrets configurados antes do workflow manual.
- Bucket de Terraform State informado por secret; o workflow manual cria ou valida o bucket.

## Configuração necessária

Configure os valores em `GitHub > Settings > Secrets and variables > Actions`.

| Nome | Tipo | Origem | Onde configurar | Uso |
|---|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Credencial AWS do usuário | GitHub Secrets deste repo | Autenticar na AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Credencial AWS do usuário | GitHub Secrets deste repo | Autenticar na AWS |
| `AWS_SESSION_TOKEN` | Secret | Credencial temporária, se aplicável | GitHub Secrets deste repo | Autenticar com sessão temporária |
| `AWS_REGION` | Secret | Região escolhida, por exemplo `us-east-1` | GitHub Secrets deste repo | Definir região do Terraform e AWS CLI |
| `TF_STATE_BUCKET` | Secret | Nome de bucket S3 escolhido pelo usuário | GitHub Secrets deste repo | Armazenar Terraform State remoto |
| `TF_VAR_db_username` | Secret | Valor definido pelo usuário | GitHub Secrets deste repo | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Secret | Valor definido pelo usuário | GitHub Secrets deste repo | Senha do SQL Server |
| `TF_VAR_operator_cidr` | Secret | IP público do operador com `/32` | GitHub Secrets deste repo | Liberar acesso administrativo ao RDS |

Para descobrir o IP público no PowerShell:

```powershell
Invoke-RestMethod https://checkip.amazonaws.com
```

Configure `TF_VAR_operator_cidr` no formato:

```text
<seu-ip-publico>/32
```

Exemplo local opcional:

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Não versione `terraform.tfvars` real.

## Como executar

1. Abra um Pull Request para `main`.
2. Aguarde o workflow `Terraform Check`.
3. Após aprovação, faça merge na `main`.
4. Execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow `Terraform Check` roda em Pull Request e executa:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

O workflow `Terraform Apply` é manual e executa:

- validação de secrets obrigatórios;
- criação ou validação do bucket S3 do state;
- `terraform init` com backend remoto;
- `terraform plan`;
- `terraform apply -auto-approve`;
- exibição de outputs úteis sem senha;
- validação básica do RDS pela AWS CLI.

## Como validar

Após o apply manual, consulte os outputs:

```powershell
terraform output
```

Valide a instância RDS:

```powershell
aws rds describe-db-instances --db-instance-identifier oficina-sqlserver --region <region> --query "DBInstances[0].[DBInstanceStatus,Engine,Endpoint.Address,Endpoint.Port,PubliclyAccessible]"
```

Resultado esperado:

- status `available`;
- engine `sqlserver-ex`;
- endpoint preenchido;
- porta `1433`;
- acesso público restrito ao `TF_VAR_operator_cidr`;
- acesso ao RDS permitido para o security group da Lambda Auth e para o CIDR da VPC.

## Outputs para a próxima etapa

| Output | Usado por | Configurar como |
|---|---|---|
| `db_address` | `oficina-api`, `oficina-auth-lambda` | Parte de `DB_CONNECTION_STRING` |
| `db_port` | `oficina-api`, `oficina-auth-lambda` | Parte de `DB_CONNECTION_STRING` |
| `db_name` | `oficina-api`, `oficina-auth-lambda` | Parte de `DB_CONNECTION_STRING` |
| `vpc_id` | `oficina-infra-k8s` | `TF_VAR_vpc_id` |
| `subnet_ids` | `oficina-infra-k8s` | `TF_VAR_subnet_ids` |
| `vpc_cidr_block` | `oficina-infra-k8s` | Referência de rede |
| `lambda_subnet_ids` | `oficina-auth-lambda` | `LAMBDA_SUBNET_IDS` |
| `lambda_security_group_ids` | `oficina-auth-lambda` | `LAMBDA_SECURITY_GROUP_IDS` |

Modelo de connection string para consumidores:

```text
Server=<db_address>,<db_port>;Database=<db_name>;User Id=<db-user>;Password=<db-password>;Encrypt=True;TrustServerCertificate=True;
```

## Problemas comuns

| Problema | Possível causa | Como resolver |
|---|---|---|
| `terraform validate` falha em PR | Arquivo Terraform inválido ou mal formatado | Rode `terraform fmt -recursive` localmente e revise o erro |
| Workflow manual falha por secret ausente | Secret obrigatório não configurado | Revise a tabela de configuração |
| RDS não fica `available` | Criação ainda em andamento | Aguarde alguns minutos e consulte novamente |
| Acesso local ao SQL Server falha | `TF_VAR_operator_cidr` incorreto | Atualize o secret com o IP público atual em formato `/32` |
| Lambda não acessa o RDS | Subnets ou security group incorretos no repo da Lambda | Use `lambda_subnet_ids` e `lambda_security_group_ids` deste repo |

## Próxima etapa

Siga para o repositório `oficina-infra-k8s` e configure os outputs `vpc_id` e `subnet_ids` como entradas do Terraform.
