# ComfyUI Local Server API — Source of Truth

Authoritative reference for ComfyUI's local HTTP/WebSocket API as exposed by `server.py`.
Source: https://docs.comfy.org/development/comfyui-server/comms_routes (verified 2026-05-21)
Cross-reference: https://github.com/comfyanonymous/ComfyUI/blob/master/server.py

**Base:** `http://127.0.0.1:8188` (default; user-configurable)
**Auth:** None — local server, no token.
**Framework:** aiohttp + asyncio.

---

## HTTP Routes

| Path | Method | Purpose |
|---|---|---|
| `/` | GET | Serve Comfy web client |
| `/embeddings` | GET | List embedding names |
| `/extensions` | GET | List extensions with `WEB_DIRECTORY` |
| `/features` | GET | Server features / capabilities |
| `/models` | GET | List model types |
| `/models/{folder}` | GET | List models in a folder |
| `/workflow_templates` | GET | Custom-node template workflows |
| `/system_stats` | GET | Python version, devices, VRAM, OS — **use for reachability/health** |
| `/object_info` | GET | All node type definitions |
| `/object_info/{node_class}` | GET | One node type |
| `/prompt` | GET | Current queue status + execution info |
| `/prompt` | POST | Submit workflow → returns `{ prompt_id, number, node_errors }` or error |
| `/queue` | GET | Current queue state (running + pending) |
| `/queue` | POST | Manage queue: `{ clear: true }` or `{ delete: [prompt_ids] }` |
| `/interrupt` | POST | Stop current execution |
| `/free` | POST | Free memory by unloading models — body: `{ unload_models: bool, free_memory: bool }` |
| `/history` | GET | Full execution history |
| `/history/{prompt_id}` | GET | History for one prompt — contains outputs |
| `/history` | POST | Clear history or delete entries — body: `{ clear: true }` or `{ delete: [prompt_ids] }` |
| `/view` | GET | Download an image — query: `filename`, `subfolder`, `type` (`output`\|`input`\|`temp`), `channel`, `preview` |
| `/view_metadata/{folder_name}` | GET | Model metadata |
| `/upload/image` | POST (multipart) | Upload image — fields: `image` (file), `subfolder`, `type`, `overwrite` |
| `/upload/mask` | POST (multipart) | Upload mask paired with original image |
| `/userdata` | GET | List user data files in a dir |
| `/v2/userdata` | GET | Structured files + dirs listing |
| `/userdata/{file}` | GET | Read user data file |
| `/userdata/{file}` | POST | Write user data file |
| `/userdata/{file}` | DELETE | Delete user data file |
| `/userdata/{file}/move/{dest}` | POST | Rename / move user data file |
| `/users` | GET | Current user info |
| `/users` | POST | Create user (multi-user mode only) |

### `/prompt` POST body

```json
{
  "prompt": { "<node_id>": { "class_type": "...", "inputs": { ... } }, ... },
  "client_id": "<optional uuid>",
  "extra_data": { "extra_pnginfo": { ... } },
  "front": false,
  "number": 0
}
```

Response:
```json
{ "prompt_id": "uuid", "number": 5, "node_errors": {} }
```
Or on validation failure: `{ "error": { "type": "...", "message": "...", "details": "...", "extra_info": { } }, "node_errors": { } }`.

### `/history/{prompt_id}` response

```json
{
  "<prompt_id>": {
    "prompt": [number, prompt_id, prompt_dict, extra_data, outputs_to_execute],
    "outputs": {
      "<node_id>": {
        "images": [{ "filename": "...", "subfolder": "...", "type": "output" }]
      }
    },
    "status": { "status_str": "success|error", "completed": true, "messages": [...] }
  }
}
```

---

## WebSocket

| Path | Notes |
|---|---|
| `/ws?clientId=<uuid>` | Bidirectional. Use `ws://` (or `wss://` for HTTPS host). Optional `clientId` query lets server target messages to a specific client. |

### Message types (server → client)

| Type | Payload | When |
|---|---|---|
| `status` | `{ status: { exec_info: { queue_remaining } }, sid }` | Connection + queue state changes |
| `execution_start` | `{ prompt_id, timestamp }` | Prompt begins execution |
| `execution_cached` | `{ prompt_id, nodes: [...] }` | Cached node outputs reused |
| `executing` | `{ prompt_id, node }` | Node start; `node: null` means execution finished |
| `progress` | `{ prompt_id, node, value, max }` | Long-running node progress |
| `executed` | `{ prompt_id, node, output }` | Node completed with output (often images) |
| `execution_error` | `{ prompt_id, node_id, node_type, exception_type, exception_message, traceback, ... }` | Node raised |
| `execution_interrupted` | `{ prompt_id, node_id, node_type, executed: [...] }` | `/interrupt` fired |
| `progress_state` | `{ prompt_id, nodes: {...} }` | (newer) per-node state map |

Binary frames carry preview images: 4-byte header (event type, image type) + raw image bytes.

---

## Health check

Use `GET /system_stats` with short timeout. 200 = reachable. Response includes `system: { os, python_version, ram_total, ram_free }`, `devices: [{ name, type, index, vram_total, vram_free, torch_vram_total, torch_vram_free }]`.

---

## What's NOT in current client

| Endpoint | Use case |
|---|---|
| `GET /history` (no prompt_id) | Full history list — useful for "recent generations" UI |
| `POST /history` | Clear history / delete entries |
| `POST /queue { delete: [...] }` | Cancel specific queued prompt (not just clear all) |
| `POST /free` | Free VRAM between heavy runs |
| `GET /models` + `/models/{folder}` | Enumerate available checkpoints/LoRAs (currently parsed from `/object_info`) |
| `GET /embeddings` | Embedding picker |
| `GET /features` | Feature gating / capability detection |
| `GET /workflow_templates` | Template gallery |
| `/userdata/*` | Persist user workflows on server |
| `/upload/mask` | Inpainting masks |
| WS `clientId` param | Scoped message routing in multi-client setup |

---

## Conventions

- All paths case-sensitive.
- All bodies JSON unless noted multipart.
- No content-type negotiation — server returns JSON for most routes, raw bytes for `/view`.
- No rate limiting. Backpressure is workflow execution time itself.
- 404 = route missing; 500 = unhandled exception in handler; 200 with `error` field = validation failure (especially on `/prompt`).
