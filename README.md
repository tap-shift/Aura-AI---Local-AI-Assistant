# Aura-AI---Local-AI-Assistant
Aura AI is a clean, high-performance Flutter app designed to bring a self-hosted AI Assistent to your phone through a chat. No subscription or datacenter – just my own hardware running a semi-powerful AI assistant. It connects to my self-hosted Ollama backend (running on Proxmox/Ubuntu) via a Python/FastAPI bridge.


Features
Vision & Chat: Analyzes images and chats with you.
Ultra Clean UI: Dark-mode "Aura Red" designed with a focus on speed and simplicity.
Smart Context: Saves chat history locally and remembers user preferences (Name, Language).
On-Device Downscaling: Automatically resizes high-res photos before upload to ensure fast processing on CPU/GPU.
Cancelable Requests: Instantly stop the AI if it's taking too long or you changed your mind.

### The Stack
Frontend: Flutter (Dart)
Backend: Python (FastAPI) + Caddy (SSL/Reverse Proxy)
AI Engine: Ollama (Self-hosted on Proxmox)
Database: shared_preferences for fast local history and settings.

### Setup
Server: Ubuntu VM, Ollama installed, and installed a model (e.g., llava for vision).
API: Python bridge script. Caddy for SSL to access from outside.
App: Flutter project made inside Android Studio, added an API key and URL in main.dart.
