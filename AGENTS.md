# Instruções do repositório

- Preserve os contratos HTTP, autenticação e rede documentados nas ADRs e RFCs do clone irmão `oficina-mecanica-api`; avalie produtores e consumidores antes de alterá-los.
- Para trabalho transversal, leia `../oficina-mecanica-api/.agents/skills/oficina-mecanica/SKILL.md`; se o clone não estiver disponível, procure os documentos no GitHub da organização e informe a limitação antes de alterar contratos compartilhados. Não presuma descoberta automática fora da API.
- Compare as esteiras com VPC e Kubernetes e preserve Git Flow, quality gates, environments, SSM e guardrails de Terraform. Use português claro e acentuado em documentação e mensagens.
- Verifique status Git e preserve alterações. Não exponha segredos nem execute apply, destroy, alterações de state ou operações AWS reais sem autorização específica. Valide localmente quando aplicável.
- Valide a formatação com `terraform fmt -check -recursive infra/terraform` e, quando os providers estiverem disponíveis, execute `terraform init -backend=false -input=false` e `terraform validate` no diretório de ambiente; confira o CI e o README antes de executar.
