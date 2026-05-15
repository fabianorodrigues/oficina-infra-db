# oficina-infra-db

## Visão Geral

Este repositório provisiona a primeira camada da solução Oficina: rede, security groups e Amazon RDS SQL Server Express. Ele entrega a base consumida pelo EKS, pela API, pela Lambda de autenticação e pelo API Gateway privado.

## Responsabilidade Deste Repositório

- Criar VPC, subnets públicas e subnets privadas.
- Criar security groups para RDS e Lambda Auth.
- Criar o RDS SQL Server Express.
- Gerar outputs de rede e banco para os demais repositórios.
- Permitir acesso operacional ao RDS apenas quando habilitado explicitamente.

## Integração com os Outros Repositórios

Valores consumidos:

| Valor | Origem | Uso |
| --- | --- | --- |
| `TF_STATE_BUCKET` | GitHub Secret | Bucket S3 do state remoto do Terraform |
| Credenciais AWS | GitHub Secrets | Autenticar o workflow na AWS |
| `TF_VAR_db_username` e `TF_VAR_db_password` | GitHub Secrets | Criar o usuário administrador do RDS |
| `TF_VAR_operator_cidr` | GitHub Secret opcional | Restringir acesso operacional ao banco quando habilitado |

Valores gerados:

| Valor | Consumido por | Uso |
| --- | --- | --- |
| `vpc_id` e `vpc_cidr_block` | `oficina-infra-k8s` | EKS, regras internas e API Gateway |
| `public_subnet_ids` | `oficina-infra-k8s` | Node group do EKS |
| `private_subnet_ids` | `oficina-infra-k8s` | NLB interno e VPC Link |
| `lambda_subnet_id` | `oficina-auth-lambda` | VPC da Lambda Auth |
| `lambda_security_group_id` | `oficina-auth-lambda` | Security group da Lambda Auth |
| Dados do RDS | `oficina-api` e `oficina-auth-lambda` | Montagem segura da connection string fora do Terraform |

## Ordem de Implantação

1. `oficina-infra-db`
2. `oficina-infra-k8s` core
3. `oficina-infra-k8s` addons
4. `oficina-api`
5. `oficina-auth-lambda`
6. `oficina-infra-k8s` API Gateway

## Configuração Necessária

Configure em `GitHub > Settings > Secrets and variables > Actions`:

| Nome | Tipo | Uso |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | Autenticação AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticação AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS |
| `TF_STATE_BUCKET` | Secret | Nome do bucket S3 para state remoto |
| `TF_VAR_db_username` | Secret | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Secret | Senha do SQL Server |
| `ENABLE_OPERATOR_DB_ACCESS` | Variable opcional | Habilita acesso operacional ao RDS; padrão `false` |
| `TF_VAR_operator_cidr` | Secret opcional | CIDR `/32` exigido quando o acesso operacional estiver ativo |

Use o mesmo `TF_STATE_BUCKET` nos repositórios de infraestrutura. O workflow cria o bucket quando ele não existe, habilita versionamento, criptografia e bloqueio público. O state deste root usa a key `oficina-infra-db/{environment}/terraform.tfstate`; os arquivos `.tfstate` são criados automaticamente pelo Terraform.

Configuração opcional para acesso via SSMS:

- Com `ENABLE_OPERATOR_DB_ACCESS=false`, o RDS permanece sem acesso público.
- Com `ENABLE_OPERATOR_DB_ACCESS=true`, informe `TF_VAR_operator_cidr` como IPv4 `/32`.
- Quando habilitado, o Terraform configura o RDS como publicamente acessível e adiciona entrada TCP `1433` apenas para o CIDR informado.

## Como Executar

Pull requests executam o workflow `Terraform Check`, com `fmt`, `init -backend=false` e `validate`.

Após revisar e fazer merge na `main`, execute:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow valida a configuração, prepara o backend S3, executa `plan`, aplica o Terraform e valida o RDS.

## Como Validar na AWS

Console:

- Em S3, confirme que o bucket de state existe com versionamento, criptografia e bloqueio público.
- Em RDS, confirme que a instância está `available`, usa engine SQL Server Express e que `Publicly accessible` está coerente com `ENABLE_OPERATOR_DB_ACCESS`.
- Em Security Groups, quando o acesso operacional estiver habilitado, confirme uma regra TCP `1433` restrita ao `/32` configurado.
- Em VPC, confirme subnets públicas e privadas com tags do projeto.

CLI:

```powershell
$env:AWS_REGION="<regiao>"
$env:TF_STATE_BUCKET="<bucket-de-state>"
$env:PROJECT_NAME="oficina"

aws s3api get-bucket-versioning --bucket $env:TF_STATE_BUCKET
aws rds describe-db-instances --db-instance-identifier "$($env:PROJECT_NAME)-sqlserver" --region $env:AWS_REGION --query "DBInstances[0].{Status:DBInstanceStatus,Engine:Engine,PubliclyAccessible:PubliclyAccessible}"
aws ec2 describe-subnets --region $env:AWS_REGION --filters "Name=tag:Repository,Values=oficina-infra-db" --query "Subnets[].{Tier:Tags[?Key=='Tier']|[0].Value,MapPublicIpOnLaunch:MapPublicIpOnLaunch}"
```

## Como Executar Localmente

Use validações não destrutivas:

```powershell
cd oficina-infra-db/terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Para um `plan` local, crie `terraform.tfvars` a partir do exemplo e preencha valores reais apenas no ambiente local. Não versione esse arquivo.

## Como Validar Localmente

Confirme que os comandos locais finalizam sem erro e que nenhum arquivo versionado foi alterado. A validação funcional completa ocorre na AWS, após o `apply`. A validação de conectividade via SSMS depende da configuração temporária de acesso operacional e deve ser feita apenas com o IP `/32` autorizado.

## Próxima Etapa

Executar o `oficina-infra-k8s` core usando o mesmo `TF_STATE_BUCKET`, para consumir automaticamente a rede criada por este repositório.
