public struct AgentKit {
    public static let version = "0.1.0"
    public static let toolTypes: [any AgentTool.Type] = [
        ReadFileTool.self,
        CreateFileTool.self,
        WriteFileTool.self,
        DeleteFileTool.self,
        MoveFileTool.self,
        CopyFileTool.self,
        ReadFileChunkTool.self,
        ListDirectoryTool.self,
        CreateDirectoryTool.self,
        DeleteDirectoryTool.self,
        SearchFilesTool.self,
        PathExistsTool.self,
        GetFileInfoTool.self,
        RunCommandTool.self,
        GetEnvironmentTool.self,
        GetWorkingDirectoryTool.self,
        ComfyUITool.self,
        ImageComposerTool.self,
        DeviantArtPublishTool.self
    ]

    public static let toolTypesByName: [String: any AgentTool.Type] = Dictionary(
        uniqueKeysWithValues: toolTypes.map { ($0.toolName, $0) }
    )

    public static let toolNames: [String] = toolTypes.map { $0.toolName }.sorted()
}
