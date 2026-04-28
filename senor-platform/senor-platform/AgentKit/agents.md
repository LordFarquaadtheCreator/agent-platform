# AgentKit

Agent execution framework. Tool registry, runner, and built-in tool implementations.

## Key Files

| File | Purpose |
|------|---------|
| `AgentKit.swift` | Central tool registry exposing `toolTypes`, `toolTypesByName`, `toolNames` |
| `Agent/Agent.swift` | Agent definition and metadata |
| `Agent/AgentRunner.swift` | Executes agent logic with tool access |
| `Agent/ToolJSONEncoder.swift` | JSON encoding for tool I/O |
| `Agent/ToolsHostView.swift` | SwiftUI view hosting tool UIs |
| `Agent/ToolsPanelView.swift` | Tool selection and configuration panel |
| `Tools/ToolProtocols.swift` | Tool definition protocols |
| `Tools/ToolSecurity.swift` | Tool permission sandboxing |
| `Tools/FileSystemTools.swift` | File read/write tools |
| `Tools/ImageComposerTool.swift` | Image composition and manipulation |
| `Tools/PublishingTools.swift` | Publish to configured targets |
| `Tools/ComfyUITool.swift` | ComfyUI (Stable Diffusion) integration |
| `Logging/AgentLogger.swift` | Agent-scoped logging |

## Tool Security

- Tools declare required permissions in `ToolSecurity.swift`.
- File system access restricted to sandboxed paths.
- Network tools require explicit allow-list.
