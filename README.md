# 🌉 Oficina Mecânica Infra API Gateway

Entrada pública HTTPS da solução, com HTTP API, Auth Lambda, VPC Link e roteamento privado para os três microsserviços. Publica access logs no CloudWatch.

## 🏗️ Recursos provisionados por esta esteira

- HTTP API do API Gateway, com rotas/integrações importadas do template OpenAPI e stage `$default`.
- VPC Link e seu security group/regras de conectividade ao NLB interno já existente.
- Integração Lambda e permissão para o Gateway invocar a função Auth já existente.
- Integrações HTTP privadas para OS, Execução e Orçamento/Pagamento, consumindo listeners publicados pela esteira Kubernetes.
- Log group de access logs estruturados no CloudWatch e parâmetros SSM de endpoint/prontidão do Gateway.

Esta esteira não cria o EKS, NLB, workloads, bancos, filas ou função Auth; consome esses recursos das esteiras responsáveis.

## 🛣️ Rotas públicas e destino por microsserviço

| Método no edge | Rota | Destino | Integração privada |
| --- | --- | --- | --- |
| POST | `/auth/documento` | Auth Lambda | Integração Lambda; emissão do JWT de Cliente |
| ANY | `/api/{proxy+}` | OS / API: identidade de operadores, cadastros, ordens e consultas | VPC Link → listener 80 → NodePort 30080 |
| ANY | `/api/v1/execucoes` e `/api/v1/execucoes/{proxy+}` | Execução: entrada de estoque, preparação e ações do mecânico | VPC Link → listener 8081 → NodePort 30081 |
| ANY | `/api/v1/orcamentos` e `/api/v1/orcamentos/{proxy+}` | Orçamento/Pagamento: consultas e decisão do orçamento | VPC Link → listener 8082 → NodePort 30082 |
| ANY | `/api/v1/pagamentos` e `/api/v1/pagamentos/{proxy+}` | Orçamento/Pagamento: consulta financeira e notificações | VPC Link → listener 8082 → NodePort 30082 |

As seis rotas de raiz/proxy dos participantes são incluídas quando `FLUXO_DISTRIBUIDO_ENABLED=true`. São mais específicas que o proxy genérico `/api/{proxy+}`. `ANY` descreve o encaminhamento no Gateway; não cria métodos ou operações que a aplicação não implementa. Cada serviço continua responsável por validar sua rota, JWT, perfil e regras de negócio.

### 🔧 Exemplos de caminhos encaminhados

- Execução: `POST /api/v1/execucoes/estoque/registrar-entrada`; `GET /api/v1/execucoes/{ordemServicoId}/preparacoes/{preparacaoId}`; ações de iniciar/finalizar serviço sob a mesma preparação.
- Orçamento: `GET /api/v1/orcamentos/{id}` e `POST /api/v1/orcamentos/{id}/decisao`. No modo distribuído, gerar/cancelar orçamento permanece coordenado pela Saga de OS.
- Pagamento: `GET /api/v1/pagamentos/{pagamentoId}` e `POST /api/v1/pagamentos/notificacoes/mercado-pago`. O Webhook usa HMAC/consulta ao provedor, sem JWT; não existe endpoint público para confirmar pagamento manualmente.
- OS: `/api/health`, cadastros e `/api/v1/gestao-ordem-servico/ordens-servico/...` continuam no proxy de OS.

Os proxies preservam o caminho recebido e removem o cabeçalho técnico `X-Clientes-Internos-Token` das requisições públicas. A consulta privada usada pela Lambda não deve ser exposta como atalho público. Os healthchecks privados de Execução e Orçamento/Pagamento não ganham rotas públicas adicionais: `/api/health` continua chegando à OS.

Fontes: [rotas e integrações do edge](infra/terraform/environments/dev/openapi/api-gateway.yaml.tftpl), [contratos dos participantes](infra/terraform/environments/dev/microsservicos.tf) e [guia da collection com as operações dos serviços](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/evidencias/postman.md).

<a id="rotas-e-ativação"></a>

## 🌉 Rotas e ativação

`POST /auth/documento` chama a Auth Lambda. Rotas de OS/cadastros, Execução e Orçamento/Pagamento seguem para seus listeners no NLB interno. O Webhook de pagamento chega ao serviço de Orçamento/Pagamento.

O contrato do edge está em `infra/terraform/environments/dev/openapi/api-gateway.yaml.tftpl`; não substitui os OpenAPIs dos serviços. No modo distribuído, os guardrails conferem flags, prontidão dos workloads, consulta privada da Lambda e targets saudáveis antes do corte.

Implantar após os três serviços e Auth estarem prontos. A URL resultante completa a configuração do Webhook; a ativação posterior atualiza Orçamento/Pagamento, sem segunda implantação obrigatória do Gateway. No destroy, remover primeiro esta entrada pública.


## 🔗 Dependências e contratos SSM

| Contrato | Uso | Papel |
| --- | --- | --- |
| `/oficina-mecanica/development/status/vpc` | Estado da VPC | Consumido |
| `/oficina-mecanica/development/vpc/vpc_id` | VPC do VPC Link | Consumido |
| `/oficina-mecanica/development/vpc/private_subnet_ids` | Subnets privadas | Consumido |
| `/oficina-mecanica/development/status/kubernetes` | Estado Kubernetes | Consumido |
| `/oficina-mecanica/development/kubernetes/internal_nlb_security_group_id` | SG do NLB | Consumido |
| `/oficina-mecanica/development/kubernetes/internal_nlb_listener_arn` | Listener TCP/80 | Consumido |
| `/oficina-mecanica/development/kubernetes/execucao_internal_nlb_listener_arn` | Listener TCP/8081 de Execução | Consumido no modo distribuído |
| `/oficina-mecanica/development/kubernetes/orcamento_pagamento_internal_nlb_listener_arn` | Listener TCP/8082 de Orçamento/Pagamento | Consumido no modo distribuído |
| `/oficina-mecanica/development/status/api-aplicacao`, `status/execucao` e `status/orcamento-pagamento-aplicacao` | Prontidão dos responsáveis pelas rotas | Consumido no modo distribuído |
| `/oficina-mecanica/development/api/fluxo_distribuido_habilitado` e `/oficina-mecanica/development/orcamento-pagamento/fluxo_distribuido_habilitado` | Corte coordenado aplicado nos produtores | Exige `true` no modo distribuído |
| `/oficina-mecanica/development/status/auth-lambda` | Estado Auth Lambda | Consumido |
| `/oficina-mecanica/development/auth-lambda/function_arn` | Integração Lambda | Consumido |
| `/oficina-mecanica/development/auth-lambda/function_name` | Permissão Lambda | Consumido |
| `/oficina-mecanica/development/api-gateway/api-endpoint` | Endpoint público | Publicado após deploy |
| `/oficina-mecanica/development/status/api-gateway` | Estado do Gateway | Publicado após deploy |

---

## 🚀 Validação local

```text
terraform fmt -check -recursive infra/terraform
terraform -chdir=infra/terraform/environments/dev init -backend=false -input=false
terraform -chdir=infra/terraform/environments/dev validate
```

## 🔐 GitHub Environment e operação

Crie em **Settings > Environments > development**:

| Nome | Tipo | Valor esperado em termos conceituais |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Environment Secret | Access key temporária do AWS Academy. |
| `AWS_SECRET_ACCESS_KEY` | Environment Secret | Secret key temporária do AWS Academy. |
| `AWS_SESSION_TOKEN` | Environment Secret | Token temporário da sessão AWS Academy. |
| `AWS_REGION` | Environment Variable | Região AWS, com fallback `us-east-1`. |
| `FLUXO_DISTRIBUIDO_ENABLED` | Environment Variable | `true` inclui as seis rotas específicas dos participantes e exige contratos/guardrails do corte distribuído; `false` mantém somente Auth e o proxy de OS. |
| `AUTO_PR_ENABLED` | Repository Variable | `true` quando as promoções automáticas estiverem habilitadas. |
| `RELEASE_BRANCH` | Repository Variable | Branch de promoção, com fallback `release`. |

O merge em `develop` executa o deploy automaticamente quando há mudança deployável. `infra/terraform/environments/dev/terraform-action.env` controla `apply` ou `destroy`; destroy exige alteração dedicada e não deve ser disparado junto com mudanças funcionais.

Após `apply`, valide o endpoint publicado no SSM, o VPC Link em estado `AVAILABLE`, o NLB interno com targets saudáveis, `POST /auth/documento`, `/api/health` e a proteção JWT. O stage `$default` grava access logs estruturados no CloudWatch. A integração Datadog/AWS pode consumir essa fonte como evolução, mas este repositório não declara nem afirma um Datadog Forwarder funcional.

---

<a id="operação-e-documentação"></a>

## 🧭 Operação e documentação

- [Visão geral, arquitetura e ordem das esteiras](https://github.com/oficina-mecanica-soat/oficina-mecanica-api#deploy-aws).
- [Configuração, primeira aplicação e recuperação após Reset](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/deploy/deploy-aws.md).
- [Collection consolidada e ambientes Local/Development](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/evidencias/postman.md).

Todo provisionamento, atualização e destroy na AWS ocorre pelas esteiras oficiais. O controle é `infra/terraform/environments/dev/terraform-action.env`; destroy exige alteração dedicada e verificação dos consumidores. `AWS_DEPLOY_ENABLED` autoriza a janela real, e `AUTO_PR_ENABLED` controla somente a abertura de promoções. Alterar uma Variable não dispara o CD.

Um ambiente disponível pode ser testado sem destroy. Sem estado compatível, alguns owners exigem primeiro uma recuperação por destroy dedicado com inventário vazio comprovado. Não apague recursos ou caches para contornar o bloqueio; consulte o guia antes de iniciar uma conta ou retomar um laboratório.

Fluxo Git: branch de trabalho → PR para `develop` → `release` → `main`. O CD físico ocorre em development; release e production registram promoções lógicas. PRs e merges permanecem sujeitos aos checks e à revisão. Mudanças somente em README/docs não exigem deploy físico pelos detectores atuais.
