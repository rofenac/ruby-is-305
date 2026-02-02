# 🚀 PatchPilot

> ✨ **Patch management orchestrator** for heterogeneous Windows/Linux environments ✨

🔍 Query · 📊 Compare · 🎯 Deploy · ✅ Verify

PatchPilot remotely queries, compares, and orchestrates patch management across Windows and Linux systems — built to prove that **Faronics Deep Freeze** is actually doing its job when the Deep Freeze console won't tell you. 🧊

---

## 🛠️ Installation

```bash
# 💎 Ruby dependencies
bundle install

# ⚛️ Frontend dependencies
cd web-gui && npm install && cd ..

# 🔑 Configure credentials
cp .env.example .env
# ✏️ Edit .env with your actual credentials
```

## 🚀 Launch

```bash
./bin/dashboard
```

| | URL |
|---|-----|
| 🎨 **Frontend** | http://localhost:5173 |
| ⚙️ **API** | http://localhost:4567 |

## 🧪 Tests

```bash
rake            # 🏃 Tests + linting
rake spec       # 🔬 Tests only
rake rubocop    # 💅 Linting only
```
