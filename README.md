# IRIS Vector Search & RAG workshop

Hands-on materials for module 3 of the AI workshop day: vector search and RAG with InterSystems IRIS.
Everything runs in one IRIS container on your laptop.

## Before the workshop day (about 15 minutes)

**1. Install** (if you don't have them yet):
- [Docker Desktop](https://www.docker.com/products/docker-desktop) - start it and wait until it says *Engine running*
- [git](https://git-scm.com)
- [VS Code](https://code.visualstudio.com) with the extensions **InterSystems ObjectScript Extension Pack** and **Jupyter**

**2. Get the workshop files** (PowerShell):
```
git clone https://github.com/Ari-Glikman/iris-vector-rag-workshop.git
cd iris-vector-rag-workshop
```

**3. Run the readiness check:**
```
powershell -ExecutionPolicy Bypass -File .\check.ps1
```
It checks your laptop, downloads the workshop image (several GB - the first time takes a while), starts the
container (`docker compose up -d`) and tests everything the exercises need, including the internet connections to
huggingface.co and api.openai.com. It ends with **READY**, or tells you what to fix.
If you cannot fix something, bring the message to the workshop.

**4. Stop the container** until the workshop:
```
docker compose down
```
On the day, start it again with `docker compose up -d` (in the same folder) - it takes about a minute.

## On the day

Follow **Workshop Guide.docx** (Hebrew: **Workshop Guide - Hebrew.docx**). The OpenAI key for the exercises is given
out in the room.

| Folder / file | What it is |
|---|---|
| `exercises/` | the files you work on: `Ex1.cls` ... `Ex4.cls`, the SQL files, the Exercise 4 notebook |
| `solutions/` | the completed versions (same class names - paste if you fall behind) |
| `data/` | the fictional handbook PDFs the exercises search |
| `compose.yaml` | the workshop container (`docker compose up -d` / `down`) |
| `check.ps1` | the readiness check |

Logins: Management Portal http://127.0.0.1:42773 - user `_SYSTEM`, password `SYS`.
