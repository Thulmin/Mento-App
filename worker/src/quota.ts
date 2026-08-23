import { DurableObject } from "cloudflare:workers";

export interface QuotaResult {
  readonly allowed: boolean;
  readonly limit: number;
  readonly remaining: number;
  readonly resetAtMs: number;
}

interface VersionRow extends Record<string, SqlStorageValue> {
  readonly version: number;
}

interface CountRow extends Record<string, SqlStorageValue> {
  readonly request_count: number;
}

export class UserDailyQuota extends DurableObject<Cloudflare.Env> {
  constructor(ctx: DurableObjectState, env: Cloudflare.Env) {
    super(ctx, env);
    void ctx.blockConcurrencyWhile(() => {
      this.migrate();
      return Promise.resolve();
    });
  }

  private migrate(): void {
    this.ctx.storage.sql.exec(
      "CREATE TABLE IF NOT EXISTS _sql_schema_migrations (" +
        "id INTEGER PRIMARY KEY, " +
        "applied_at TEXT NOT NULL DEFAULT (datetime('now'))" +
        ")"
    );
    const version = this.ctx.storage.sql
      .exec<VersionRow>(
        "SELECT COALESCE(MAX(id), 0) AS version " +
          "FROM _sql_schema_migrations"
      )
      .one().version;
    if (version < 1) {
      this.ctx.storage.sql.exec(
        "CREATE TABLE IF NOT EXISTS daily_usage (" +
          "day TEXT PRIMARY KEY, " +
          "request_count INTEGER NOT NULL CHECK(request_count >= 0), " +
          "updated_at_ms INTEGER NOT NULL" +
          ")"
      );
      this.ctx.storage.sql.exec(
        "INSERT INTO _sql_schema_migrations (id) VALUES (1)"
      );
    }
  }

  checkAndConsume(day: string, limit: number, nowMs: number): QuotaResult {
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(day) ||
      day !== new Date(nowMs).toISOString().slice(0, 10) ||
      !Number.isInteger(limit) ||
      limit < 1 ||
      limit > 10_000 ||
      !Number.isFinite(nowMs)
    ) {
      throw new Error("invalid_quota_input");
    }

    const retentionCutoff = new Date(nowMs - 8 * 86_400_000)
      .toISOString()
      .slice(0, 10);
    this.ctx.storage.sql.exec(
      "DELETE FROM daily_usage WHERE day < ?",
      retentionCutoff
    );

    const rows = this.ctx.storage.sql
      .exec<CountRow>(
        "INSERT INTO daily_usage (day, request_count, updated_at_ms) " +
          "VALUES (?, 1, ?) " +
          "ON CONFLICT(day) DO UPDATE SET " +
          "request_count = daily_usage.request_count + 1, " +
          "updated_at_ms = excluded.updated_at_ms " +
          "WHERE daily_usage.request_count < ? " +
          "RETURNING request_count",
        day,
        nowMs,
        limit
      )
      .toArray();

    const resetAtMs = Date.parse(day + "T00:00:00.000Z") + 86_400_000;
    const updatedCount = rows[0]?.request_count;
    if (updatedCount === undefined) {
      return {
        allowed: false,
        limit,
        remaining: 0,
        resetAtMs
      };
    }
    return {
      allowed: true,
      limit,
      remaining: Math.max(0, limit - updatedCount),
      resetAtMs
    };
  }
}
