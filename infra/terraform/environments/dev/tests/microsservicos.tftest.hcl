mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ready" }
  }
}
override_data {
  target = data.aws_ssm_parameter.vpc_id
  values = { value = "vpc-0123456789abcdef0" }
}
override_data {
  target = data.aws_ssm_parameter.private_subnet_ids
  values = { value = "subnet-0123456789abcdef0,subnet-0123456789abcdef1" }
}
override_data {
  target = data.aws_ssm_parameter.internal_nlb_security_group_id
  values = { value = "sg-0123456789abcdef0" }
}
override_data {
  target = data.aws_ssm_parameter.internal_nlb_listener_arn
  values = { value = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/net/api/abc/def" }
}
override_data {
  target = data.aws_ssm_parameter.microsservicos_listener_arn["execucao"]
  values = { value = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/net/api/abc/execucao" }
}
override_data {
  target = data.aws_ssm_parameter.microsservicos_listener_arn["orcamento_pagamento"]
  values = { value = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/net/api/abc/orcamento" }
}
override_data {
  target = data.aws_ssm_parameter.corte_coordenado
  values = { value = "true" }
}
override_resource {
  target          = aws_apigatewayv2_vpc_link.gateway
  override_during = plan
  values          = { id = "abc12345" }
}
run "roteamento_legado_preservado_por_padrao" {
  command = plan
  assert {
    condition = (
      !contains(keys(yamldecode(aws_apigatewayv2_api.gateway.body).paths), "/api/v1/execucoes/{proxy+}") &&
      contains(keys(yamldecode(aws_apigatewayv2_api.gateway.body).paths), "/api/{proxy+}") &&
      contains(keys(yamldecode(aws_apigatewayv2_api.gateway.body).paths), "/auth/documento") &&
      length(aws_vpc_security_group_ingress_rule.microsservicos_nlb_from_vpc_link) == 0
    )
    error_message = "Flag desligada deve preservar o contrato existente sem abrir novos listeners ao Gateway."
  }
}
run "familias_novas_encaminham_aos_owners_e_preservam_headers" {
  command = plan
  variables { microsservicos_habilitados = true }
  assert {
    condition = (
      yamldecode(aws_apigatewayv2_api.gateway.body).paths["/api/v1/execucoes/{proxy+}"]["x-amazon-apigateway-any-method"]["x-amazon-apigateway-integration"]["$ref"] == "#/components/x-amazon-apigateway-integrations/privateExecucao" &&
      yamldecode(aws_apigatewayv2_api.gateway.body).paths["/api/v1/orcamentos/{proxy+}"]["x-amazon-apigateway-any-method"]["x-amazon-apigateway-integration"]["$ref"] == "#/components/x-amazon-apigateway-integrations/privateOrcamentoPagamento" &&
      yamldecode(aws_apigatewayv2_api.gateway.body).paths["/api/v1/pagamentos/{proxy+}"]["x-amazon-apigateway-any-method"]["x-amazon-apigateway-integration"]["$ref"] == "#/components/x-amazon-apigateway-integrations/privateOrcamentoPagamento" &&
      alltrue([for k in ["privateApi", "privateExecucao", "privateOrcamentoPagamento"] :
        yamldecode(aws_apigatewayv2_api.gateway.body).components["x-amazon-apigateway-integrations"][k].requestParameters["overwrite:path"] == "$request.path" &&
        yamldecode(aws_apigatewayv2_api.gateway.body).components["x-amazon-apigateway-integrations"][k].requestParameters["remove:header.X-Clientes-Internos-Token"] == "''" &&
        !contains(keys(yamldecode(aws_apigatewayv2_api.gateway.body).components["x-amazon-apigateway-integrations"][k].requestParameters), "overwrite:header.Authorization") &&
        !contains(keys(yamldecode(aws_apigatewayv2_api.gateway.body).components["x-amazon-apigateway-integrations"][k].requestParameters), "overwrite:header.x-signature")
      ])
    )
    error_message = "Rotas devem chegar ao owner, preservar path/JWT/HMAC e retirar o header técnico da entrada pública."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.microsservicos_nlb_from_vpc_link["execucao"].from_port == 8081 && aws_vpc_security_group_ingress_rule.microsservicos_nlb_from_vpc_link["orcamento_pagamento"].from_port == 8082
    error_message = "Rede deve liberar somente as portas dos listeners próprios."
  }
}
run "owner_indisponivel_impede_ativar_rotas" {
  command = plan
  variables { microsservicos_habilitados = true }
  override_data {
    target = data.aws_ssm_parameter.microsservicos_status["execucao"]
    values = { value = "indisponivel" }
  }
  expect_failures = [aws_apigatewayv2_api.gateway]
}
run "corte_inativo_no_owner_impede_ativar_rotas" {
  command = plan
  variables { microsservicos_habilitados = true }
  override_data {
    target = data.aws_ssm_parameter.corte_coordenado["api"]
    values = { value = "false" }
  }
  expect_failures = [aws_apigatewayv2_api.gateway]
}
