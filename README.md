# Aura-AI: Local & Self-Hosted AI Voice/Chat Assistant

**Aura-AI** is a high-performance, privacy-focused mobile assistant designed to bring a fully self-hosted AI experience directly to your smartphone. By leveraging your own hardware, Aura-AI eliminates subscriptions, third-party data collection, and reliance on external datacenters. The system features an optimized Flutter frontend communicating seamlessly with a self-hosted Ollama backend orchestrating local LLMs.

---

## Architecture & Stuff:
The platform uses a decoupled edge-to-server architecture optimized for consumer-grade hardware and local deployment:

* **Mobile Client (Flutter / Dart):** A reactive native application configured with an ultra-clean "Aura Red" dark-mode theme. It natively handles chat lifecycle state, localized storage orchestration, and edge-side image compression.
* **Orchestration Layer (Python / FastAPI):** Acts as a high-throughput middleware bridge between the mobile application and the core execution engine, managing request routing and payload parsing.
* **Edge Security & Ingress (Caddy):** Serves as a reverse proxy managing automatic SSL/TLS termination, allowing secure encrypted traffic from outside the local area network (LAN).
* **Inference Engine (Ollama):** Virtualized within an enterprise Proxmox environment on an Ubuntu VM, executing quantized local models (e.g., LLaVA) for multimodal vision and chat inference.

---

## Capabilities:
* **Multimodal Inference (Vision & Chat):** Process textual queries and visual data concurrently utilizing local vision-language models.
* **On-Device Downscaling:** Pre-processes and resizes high-resolution image payloads directly on the client device before ingestion to maximize network throughput and minimize GPU memory (VRAM) bottlenecking.
* **Zero-Latency Stream Cancellation:** Supports interruptible requests, allowing clients to instantly drop active text generation streams if context parameters shift.
* **Persistent Local Context:** Uses low-overhead localized storage abstraction via `shared_preferences` to maintain chat history and user state entirely on-device.

---

## Technologies:
| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | Flutter / Dart | Native UI rendering, state management, and edge image manipulation. |
| **API Gateway** | Python / FastAPI | Lightweight backend API wrapper and JSON serialization layer. |
| **Ingress/Proxy** | Caddy Server | Production-grade SSL termination and secure reverse proxy routing. |
| **AI Runtime** | Ollama | Local machine learning abstraction layer and model weight management. |
| **Infrastructure** | Proxmox VE / Ubuntu | Type-1 hypervisor running virtualized Linux environments for host compute. |
| **Storage** | Shared Preferences | Client-side persistent key-value caching for configurations and history. |

---

## System Setup & Deployment:
### 1. Server Configuration
1. Deploy an **Ubuntu VM** inside your **Proxmox** infrastructure.
2. Install the **Ollama** runtime and pull your preferred weights (e.g., `ollama pull llava`).
3. Run the Python FastAPI bridge script to expose the endpoint wrappers locally.
4. Configure **Caddy** to point to your FastAPI port with a public-facing domain for secure external access.

### 2. Client Compilation
1. Import the Flutter project into **Android Studio** or VS Code.
2. Navigate to `lib/main.dart`.
3. Update the global configuration fields with your secure deployment endpoint URL and custom API routing keys.
4. Compile and deploy the target `.apk` or iOS build to your device.
