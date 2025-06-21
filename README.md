# Ethereum RPC HealthCheck 🧪

> Full-stack Sepolia node probe for both Execution (Geth) and Consensus (Prysm) layers  
> Lightweight, terminal-friendly, and ready to `bash <(curl …)` anywhere.

---

## 🌐 What it does

- Auto-detects your machine's IP
- Probes **Geth** via JSON-RPC `:8545` (Execution Layer)
- Probes **Prysm** via REST API `:3500` (Beacon Layer)
- Fires **10 rapid requests** to test:
  - Latency (min/avg/max)
  - Success rate
  - Latest block and slot
  - Sync and health status
- Outputs a clean, color-coded summary

---

## ⚡ Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<your-username>/ethereum-rpc-healthcheck/main/sepolia_health.sh)
