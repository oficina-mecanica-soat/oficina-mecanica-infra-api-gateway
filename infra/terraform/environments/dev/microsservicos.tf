locals {
  microsservicos_listeners = var.microsservicos_habilitados ? { execucao = 8081, orcamento_pagamento = 8082 } : {}
}

data "aws_ssm_parameter" "microsservicos_listener_arn" {
  for_each = local.microsservicos_listeners
  name     = "${var.kubernetes_ssm_prefix}/${each.key}_internal_nlb_listener_arn"
}

data "aws_ssm_parameter" "microsservicos_status" {
  for_each = var.microsservicos_habilitados ? toset(["api-aplicacao", "execucao", "orcamento-pagamento-aplicacao"]) : toset([])
  name     = "/oficina-mecanica/${var.environment}/status/${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_microsservicos" {
  for_each                     = local.microsservicos_listeners
  security_group_id            = aws_security_group.vpc_link.id
  referenced_security_group_id = data.aws_ssm_parameter.internal_nlb_security_group_id.value
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  description                  = "Permite VPC Link para listener privado ${each.value}."
}
resource "aws_vpc_security_group_ingress_rule" "microsservicos_nlb_from_vpc_link" {
  for_each                     = local.microsservicos_listeners
  security_group_id            = data.aws_ssm_parameter.internal_nlb_security_group_id.value
  referenced_security_group_id = aws_security_group.vpc_link.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  description                  = "Permite VPC Link no listener privado ${each.value}."
}

data "aws_ssm_parameter" "corte_coordenado" {
  for_each = var.microsservicos_habilitados ? toset(["api", "orcamento-pagamento"]) : toset([])
  name     = "/oficina-mecanica/${var.environment}/${each.key}/fluxo_distribuido_habilitado"
}
