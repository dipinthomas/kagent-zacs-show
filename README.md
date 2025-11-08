# Kagent Demo: Kubernetes and AWS Agents

This repository contains example Kagent Agent definitions, ModelConfig presets for multiple LLM providers, and supporting MCP server configurations to demonstrate AI-assisted operations for Kubernetes and AWS (CloudWatch and Billing).

Use this repo to quickly install Kagent, deploy ready-to-use agents, and run an interactive demo.

## Repo Structure
- **all_agents_values.yaml** — Helm values to enable core agents/tools during Kagent install
- **default_k8s-agent.yaml** — Kubernetes expert agent (diagnostics, ops, security)
- **cloudwatch_agent.yaml** — AWS CloudWatch expert agent (logs, metrics, alarms)
- **aws_billing_agent.yaml** — AWS Billing expert agent (costs, forecasts, anomalies)
- **stress-testing.yaml** — Sample k8s namespace/deployment/HPA for scaling tests
- **mcp/** — MCP server CRDs for AWS CloudWatch and Billing tools
- **modelconfig/** — ModelConfig CRDs for OpenAI, Azure OpenAI, Anthropic, Gemini
- **steps.txt** — Scripted install/verify commands consumed by the demo runner
- **demo_execution.sh** — Interactive shell runner for the steps
- **LICENSE** — MIT License

## Prerequisites
- A Kubernetes cluster and `kubectl` configured
- `helm` installed
- Kagent CLI (installed below)
- API key(s) for your chosen model provider(s) (e.g., OpenAI)
- For AWS agents (CloudWatch/Billing): AWS creds with required permissions

## Quick Start
The fastest way to install and verify is to run the interactive demo script with the provided steps.

```bash
# From repo root
bash demo_execution.sh steps.txt
```

The script will:
- Install Kagent CLI
- Install Kagent CRDs
- Install Kagent with `all_agents_values.yaml`
- Verify pods and services
- List available MCP tools

You can skip or rerun individual steps interactively.

## Manual Installation
If you prefer to run the commands yourself, use the following sequence (same as `steps.txt`).

```bash
# 1) Install Kagent CLI
curl https://raw.githubusercontent.com/kagent-dev/kagent/refs/heads/main/scripts/get-kagent | bash

# 2) Install CRDs
helm upgrade --install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
  --namespace kagent --create-namespace
kubectl get crds | grep kagent

# 3) Install controller (OpenAI example)
# Provide your OpenAI API key; this stores it locally in .kagent_openai_key for one-time use
if [ -z "${OPENAI_API_KEY:-}" ]; then 
  read -s -p "Enter OpenAI API Key: " OPENAI_API_KEY </dev/tty; echo; 
fi; printf '%s' "$OPENAI_API_KEY" > .kagent_openai_key

OPENAI_API_KEY="$(cat .kagent_openai_key)"; \
helm upgrade --install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --namespace kagent \
  -f all_agents_values.yaml \
  --set providers.default=openAI \
  --set providers.openAI.apiKey="$OPENAI_API_KEY"

# 4) Verify
kubectl get pods -n kagent
kubectl get svc -n kagent
kubectl get remotemcpservers -n kagent
```

## Deploy the Example Agents
Apply any of the provided agent CRDs once Kagent is running.

```bash
# Kubernetes expert agent
kubectl apply -f default_k8s-agent.yaml

# AWS CloudWatch agent
kubectl apply -f cloudwatch_agent.yaml

# AWS Billing agent
kubectl apply -f aws_billing_agent.yaml
```

- Agents reference a `modelConfig` by name (e.g., `openai-gpt-5-mini`). Ensure a matching ModelConfig is created (see below) and that required secrets exist.

## Configure Model Providers
Create a ModelConfig for your chosen provider and ensure required Kubernetes Secrets exist in the `kagent` namespace.

Examples are in `modelconfig/`:
- `openai-modelconfig.yaml`
- `azure-openai-modelconfig.yaml`
- `anthropic-modelconfig.yaml`
- `gemini-modelconfig.yaml`

Apply one or more:

```bash
kubectl apply -f modelconfig/openai-modelconfig.yaml
# or
kubectl apply -f modelconfig/azure-openai-modelconfig.yaml
kubectl apply -f modelconfig/anthropic-modelconfig.yaml
kubectl apply -f modelconfig/gemini-modelconfig.yaml
```

Create the referenced Secrets (names/keys must match the files):

```bash
# OpenAI
kubectl -n kagent create secret generic kagent-openai \
  --from-literal=OPENAI_API_KEY="YOUR_OPENAI_KEY"

# Azure OpenAI
kubectl -n kagent create secret generic kagent-azure-openai \
  --from-literal=AZURE_OPENAI_API_KEY="YOUR_AZURE_OPENAI_KEY"

# Anthropic
kubectl -n kagent create secret generic kagent-anthropic \
  --from-literal=ANTHROPIC_API_KEY="YOUR_ANTHROPIC_KEY"

# Gemini (Direct)
kubectl -n kagent create secret generic kagent-gemini \
  --from-literal=GEMINI_API_KEY="YOUR_GEMINI_KEY"

# Gemini Vertex AI (GCP service account key JSON)
kubectl -n kagent create secret generic kagent-gcp \
  --from-file=GCP_SERVICE_ACCOUNT_KEY=</path/to/service-account.json>
```

## AWS MCP Servers and Credentials
MCP server CRDs are in `mcp/` and are referenced by the AWS agents.

- `mcp/awslabs.aws-cloud-watch-mcp-server.yaml`
- `mcp/awslabs.billing-cost-management-mcp-server.yaml`
- `mcp/awslabs.cost-explorer-mcp-server.yaml`

These deployments expect AWS credentials via environment variables. Provide credentials by creating a Secret and projecting it, or by using your cluster’s standard mechanism for AWS auth (IRSA, KIAM, etc.). For simple demos, you can export variables on the MCP deployment via a patch:

```bash
# Example: patch the CloudWatch MCP deployment env (demo only)
# Replace values and consider using IRSA for production
kubectl -n kagent patch mcpserver awslabs-cloudwatch-mcp-server-latest --type merge -p '
{
  "spec": {
    "deployment": {
      "env": {
        "AWS_ACCESS_KEY_ID": "YOUR_KEY_ID",
        "AWS_SECRET_ACCESS_KEY": "YOUR_SECRET",
        "AWS_REGION": "us-east-1"
      }
    }
  }
}'
```

## Stress Testing Sample (optional)
Deploy a small namespace with a constrained quota, an `nginx` Deployment, and an HPA to observe scaling behavior:

```bash
kubectl apply -f stress-testing.yaml
kubectl get hpa -n auth-test
```

## Enabling Agents via Helm Values
`all_agents_values.yaml` toggles which built-in agents and tools start with the Helm chart.

- Update values as needed and re-run Helm to enable/disable specific agents or tools.

## Using the Agents
Once agents are installed and running, use your Kagent UI/CLI to interact with them. Example skills defined in the CRDs include:
- Kubernetes: cluster diagnostics, resource management, security audits
- CloudWatch: log analysis, metrics monitoring, alarm management, Logs Insights
- Billing: cost and usage analysis, spend forecasting, anomaly detection, optimization

## Cleanup
```bash
# Remove example agents
kubectl delete -f default_k8s-agent.yaml || true
kubectl delete -f cloudwatch_agent.yaml || true
kubectl delete -f aws_billing_agent.yaml || true

# Remove stress test
kubectl delete -f stress-testing.yaml || true

# Uninstall kagent
helm uninstall kagent -n kagent || true
helm uninstall kagent-crds -n kagent || true
kubectl delete ns kagent || true
```

## Troubleshooting
- Ensure the `ModelConfig` referenced by an agent exists and is Ready
- Verify Secrets and keys match names and keys in the ModelConfigs
- Check MCP server pods in `kagent` namespace and their logs if AWS tools fail
- Confirm network egress and DNS resolution from your cluster

## License
MIT — see [LICENSE](./LICENSE).
