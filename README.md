# 🚀 Desafio DIO: Simplifique o Gerenciamento de Infraestrutura com Terraform na AWS

Este repositório foi desenvolvido como parte do desafio prático da [Digital Innovation One (DIO)](https://www.dio.me/) com o objetivo de aplicar **Infraestrutura como Código (IaC)** utilizando **Terraform** para provisionar uma arquitetura **serverless** na AWS.

---

## 📋 Visão Geral

A infraestrutura provisionada por este código permite:

- Registro de pessoas em uma tabela DynamoDB via API Gateway + Lambda
- Consulta de registros utilizando outro endpoint da mesma API
- Toda a infraestrutura criada automaticamente via Terraform

---

## 🧱 Arquitetura Provisionada

| Componente         | Descrição                                                                 |
|--------------------|---------------------------------------------------------------------------|
| **Lambda Functions** | `registerLambda`: insere dados no DynamoDB<br>`getLambda`: lê dados     |
| **API Gateway**      | Rota REST `/insert` e `/getperson`, conectadas via `AWS_PROXY` às Lambdas |
| **DynamoDB**         | Tabela `DIOLivePerson`, com `id` como chave primária                     |
| **IAM Roles & Policies** | Controle de acesso para leitura e escrita no DynamoDB pelas funções Lambda |

---

## ⚙️ Recursos Criados com Terraform

- `aws_dynamodb_table`
- `aws_lambda_function`
- `aws_api_gateway_rest_api`
- `aws_api_gateway_resource`
- `aws_api_gateway_method`
- `aws_api_gateway_integration`
- `aws_api_gateway_deployment`
- `aws_api_gateway_stage`
- `aws_lambda_permission`
- `aws_iam_role`, `aws_iam_role_policy`

---

## 🧪 Funcionalidade

### Endpoint 1: `POST /insert`
Cadastra uma pessoa no DynamoDB.

### Endpoint 2: `POST /getperson`
Consulta uma pessoa no DynamoDB usando o ID.

---

## 🚧 Desafios Enfrentados & Soluções

### 🔴 Erro 404 ao Criar `aws_api_gateway_integration`
**Mensagem:**
```
creating API Gateway Integration: operation error API Gateway: PutIntegration, StatusCode: 404
```

**Causa:**
O método (`aws_api_gateway_method`) ainda não existia no momento da criação da integração.

**Solução:**
Adição de `depends_on` para garantir ordem correta:

```hcl
depends_on = [aws_api_gateway_method.writeMethod]
```

---

### 🔴 Erro "Unsupported argument: stage_name"
**Mensagem:**
```
Unsupported argument: stage_name in aws_api_gateway_deployment
```

**Causa:**
O Terraform CLI estava atualizado, mas o `AWS Provider v6.0.0` **não permite mais o uso direto de `stage_name`** em `aws_api_gateway_deployment`.

**Solução:**
Separação do stage em um novo recurso:

```hcl
resource "aws_api_gateway_stage" "stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
  deployment_id = aws_api_gateway_deployment.apideploy.id
}
```

E ajustes nas permissões com:

```hcl
source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/${aws_api_gateway_stage.stage.stage_name}/POST/insert"
```

---

## 💡 Requisitos

- **Terraform CLI** `>= 1.5.0` (usamos `v1.8.3`)
- **AWS Provider** `>= 6.0.0`
- Zip das funções Lambda enviados previamente para o bucket S3 (`msr-dio-terraform`)
- Políticas IAM nos arquivos JSON externos (`write_policy.json`, `read_policy.json`)

---

## ▶️ Como Executar

1. Configure suas credenciais da AWS
2. Edite os arquivos `*.json` com suas permissões
3. Certifique-se de que os zips `registerperson.zip` e `getperson.zip` estão no S3
4. Execute:

```bash
terraform init
terraform plan
terraform apply
```

5. Use um client como Postman ou curl para testar os endpoints.

---

## 📎 Exemplo de Requisições

```bash
curl -X POST https://<api-id>.execute-api.us-east-2.amazonaws.com/dev/insert \
  -d '{"id": "123", "name": "Maikel"}' \
  -H "Content-Type: application/json"

curl -X POST https://<api-id>.execute-api.us-east-2.amazonaws.com/dev/getperson \
  -d '{"id": "123"}' \
  -H "Content-Type: application/json"
```

---

## ✅ Conclusão

Este projeto demonstrou na prática como o Terraform pode simplificar o provisionamento de recursos AWS, mesmo em uma arquitetura serverless com múltiplas integrações. Além disso, o exercício ajudou a entender como lidar com erros comuns de ordem de criação, controle de versão de providers e boas práticas na criação de APIs REST com Lambda e DynamoDB.

---

## 🙌 Agradecimentos

Desenvolvido com base no desafio da [DIO - Digital Innovation One](https://www.dio.me/) para a formação em DevOps com AWS + Terraform.