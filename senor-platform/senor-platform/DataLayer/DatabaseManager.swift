import Foundation
#if canImport(GRDB)
import GRDB

/// Manages database configuration, connections, and migrations
public final class DatabaseManager: LifecycleAware, Sendable {
    private let databaseURL: URL
    private let queue: DatabaseQueue
    private let logger = AppLogger.database

    public init() throws {
        // Store database in Application Support
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appFolderURL = appSupportURL.appendingPathComponent("SenorPlatform", isDirectory: true)

        if !fileManager.fileExists(atPath: appFolderURL.path) {
            try fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        }

        self.databaseURL = appFolderURL.appendingPathComponent("senorplatform.sqlite")
        self.queue = try DatabaseQueue(path: databaseURL.path)

        logger.info("Database initialized at: \(databaseURL.path)")
    }

    public func startup() async throws {
        try migrator.migrate(queue)
        logger.info("Database migrations completed successfully")
    }

    public func shutdown() async throws {
        // Nothing special needed for SQLite shutdown
        logger.info("Database shutdown")
    }

    /// Get a database queue for read operations
    public func read<T>(_ operation: @Sendable (Database) throws -> T) throws -> T {
        try queue.read(operation)
    }

    /// Get a database queue for write operations
    public func write<T>(_ operation: @Sendable (Database) throws -> T) throws -> T {
        try queue.write(operation)
    }

    /// Async read operation - uses synchronous read wrapped in Task
    public func asyncRead<T: Sendable>(_ operation: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await Task {
            try queue.read(operation)
        }.value
    }

    /// Async write operation - uses synchronous write wrapped in Task
    public func asyncWrite<T: Sendable>(_ operation: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await Task {
            try queue.write(operation)
        }.value
    }

    // MARK: - Migration Definitions

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Migration 001: Initial schema
        migrator.registerMigration("001_initial") { db in
            // agents table
            try db.create(table: "agents") { t in
                t.primaryKey("id", .text).notNull()
                t.column("display_name", .text).notNull().unique()
                t.column("status", .text).notNull().defaults(to: "idle")
                t.column("name_source", .text).notNull()
                t.column("name_seed", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // task_types table
            try db.create(table: "task_types") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("schema_version", .integer).notNull()
                t.column("json_schema", .text).notNull()
                t.column("description", .text)
                t.column("created_at", .datetime).notNull()
            }

            // tasks table
            try db.create(table: "tasks") { t in
                t.primaryKey("id", .text).notNull()
                t.column("agent_id", .text).notNull().references("agents", onDelete: .cascade)
                t.column("task_type_id", .text).notNull().references("task_types")
                t.column("task_name", .text).notNull()
                t.column("task_metadata_json", .text).notNull()
                t.column("go_script_path", .text).notNull()
                t.column("is_enabled", .boolean).notNull().defaults(to: true)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // task_schedules table
            try db.create(table: "task_schedules") { t in
                t.primaryKey("id", .text).notNull()
                t.column("task_id", .text).notNull().references("tasks", onDelete: .cascade)
                t.column("schedule_kind", .text).notNull() // one_time, recurring
                t.column("schedule_payload_json", .text).notNull()
                t.column("cron_expression", .text).notNull()
                t.column("timezone", .text).notNull()
                t.column("next_run_at", .datetime)
                t.column("is_active", .boolean).notNull().defaults(to: true)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // task_runs table
            try db.create(table: "task_runs") { t in
                t.primaryKey("id", .text).notNull()
                t.column("task_id", .text).notNull().references("tasks", onDelete: .cascade)
                t.column("agent_id", .text).notNull().references("agents")
                t.column("worker_pid", .integer)
                t.column("trigger_source", .text).notNull() // scheduled, manual, api
                t.column("scheduled_for", .datetime).notNull()
                t.column("started_at", .datetime)
                t.column("completed_at", .datetime)
                t.column("status", .text).notNull() // scheduled, running, completed, failed, killed
                t.column("exit_code", .integer)
                t.column("stdout_log_path", .text)
                t.column("stderr_log_path", .text)
                t.column("error_message", .text)
            }

            // generated_content table
            try db.create(table: "generated_content") { t in
                t.primaryKey("id", .text).notNull()
                t.column("task_run_id", .text).notNull().references("task_runs", onDelete: .cascade)
                t.column("agent_id", .text).notNull().references("agents")
                t.column("title", .text).notNull()
                t.column("generated_content_json", .text).notNull()
                t.column("current_version", .integer).notNull().defaults(to: 1)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // generated_content_versions table
            try db.create(table: "generated_content_versions") { t in
                t.primaryKey("id", .text).notNull()
                t.column("generated_content_id", .text).notNull().references("generated_content", onDelete: .cascade)
                t.column("version", .integer).notNull()
                t.column("content_snapshot_json", .text).notNull()
                t.column("change_reason", .text)
                t.column("edited_by", .text)
                t.column("created_at", .datetime).notNull()

                // Unique constraint on content_id + version
                t.uniqueKey(["generated_content_id", "version"], onConflict: .fail)
            }

            // approval_queue table
            try db.create(table: "approval_queue") { t in
                t.primaryKey("id", .text).notNull()
                t.column("generated_content_id", .text).notNull()
                    .references("generated_content", onDelete: .cascade).unique()
                t.column("approval_status", .text).notNull().defaults(to: "pending") // pending, approved, rejected
                t.column("approved_by", .text)
                t.column("approved_at", .datetime)
                t.column("rejected_at", .datetime)
                t.column("rejection_reason", .text)
                t.column("batch_token", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // Publication targets table
            try db.create(table: "publication_targets") { t in
                t.column("id", .text).primaryKey()
                t.column("generated_content_id", .text).notNull().indexed()
                t.column("platform", .text).notNull()
                t.column("state", .text).notNull().defaults(to: "pending")
                t.column("scheduled_at", .datetime)
                t.column("remote_post_id", .text)
                t.column("remote_url", .text)
                t.column("error_message", .text)
                t.column("published_at", .datetime)
                t.column("created_at", .datetime).notNull().defaults(to: Date())
                t.column("updated_at", .datetime).notNull().defaults(to: Date())
                t.foreignKey(["generated_content_id"], references: "generated_content", onDelete: .cascade)
            }

            // remote_post_cache table
            try db.create(table: "remote_post_cache") { t in
                t.primaryKey("id", .text).notNull()
                t.column("platform", .text).notNull()
                t.column("cache_key", .text).notNull()
                t.column("payload_json", .text).notNull()
                t.column("stats_json", .text)
                t.column("fetched_at", .datetime).notNull()
                t.column("expires_at", .datetime).notNull()
            }

            // Create indexes for performance
            try db.create(index: "idx_task_runs_status_started", on: "task_runs",
                          columns: ["status", "started_at"])
            try db.create(index: "idx_task_schedules_next_run", on: "task_schedules",
                          columns: ["next_run_at", "is_active"])
            try db.create(index: "idx_approval_queue_status_created", on: "approval_queue",
                          columns: ["approval_status", "created_at"])
            try db.create(index: "idx_content_versions", on: "generated_content_versions",
                          columns: ["generated_content_id", "version"])
            try db.create(index: "idx_cache_platform_key_expires", on: "remote_post_cache",
                          columns: ["platform", "cache_key", "expires_at"])
        }

        // Migration 002: AI Chat History
        migrator.registerMigration("002_ai_chat_history") { db in
            try db.create(table: "chat_history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("section", .text).notNull()
                t.column("messages_json", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(index: "idx_chat_history_section", on: "chat_history", columns: ["section"])
        }

        // Migration 003: Patreon Stats and Events
        migrator.registerMigration("003_patreon_stats") { db in
            try db.create(table: "patreon_stats") { t in
                t.primaryKey("id", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("total_patrons", .integer).notNull()
                t.column("active_patrons", .integer).notNull()
                t.column("total_revenue_cents", .integer).notNull()
                t.column("monthly_revenue_cents", .integer).notNull()
            }
            try db.create(index: "idx_patreon_stats_timestamp", on: "patreon_stats", columns: ["timestamp"])

            try db.create(table: "patreon_pledge_events") { t in
                t.primaryKey("id", .text).notNull()
                t.column("member_id", .text).notNull()
                t.column("event_type", .text).notNull()
                t.column("date", .datetime).notNull()
                t.column("amount_cents", .integer)
                t.column("payment_status", .text)
                t.column("tier_id", .text)
                t.column("tier_title", .text)
            }
            try db.create(index: "idx_pledge_events_member", on: "patreon_pledge_events", columns: ["member_id"])
            try db.create(index: "idx_pledge_events_date", on: "patreon_pledge_events", columns: ["date"])
        }

        // Migration 004: ComfyUI Executions
        migrator.registerMigration("004_comfyui_executions") { db in
            try db.create(table: "comfyui_executions") { t in
                t.primaryKey("id", .text).notNull()
                t.column("workflow_id", .text).notNull()
                t.column("workflow_name", .text).notNull()
                t.column("inputs_json", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "queued")
                t.column("progress", .double).notNull().defaults(to: 0)
                t.column("current_node", .text)
                t.column("started_at", .datetime)
                t.column("completed_at", .datetime)
                t.column("output_paths_json", .text).notNull().defaults(to: "[]")
                t.column("output_directory", .text).notNull().defaults(to: "")
                t.column("error_message", .text)
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_comfyui_status_created", on: "comfyui_executions", columns: ["status", "created_at"])
            try db.create(index: "idx_comfyui_workflow", on: "comfyui_executions", columns: ["workflow_id"])
        }

        return migrator
    }
}
#endif
