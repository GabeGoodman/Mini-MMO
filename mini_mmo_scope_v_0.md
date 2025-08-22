# Project: Top‑Down 2D MMO RPG — Scope & Architecture (v0.2)

> Working document to collect decisions, trade‑offs, and next steps. Target: **10,000 concurrent players per server cluster** (not a single process), low‑latency combat/social hubs, and cost‑efficient scaling.

---

## 1) Vision & Core Requirements

- **Game**: Top‑down 2D MMO RPG (PC-first; mobile-friendly later).
- **Target capacity**: 10,000 CCU per regional **cluster**; individual **world servers** sized to practical limits (1–3k CCU per world shard/zone).
- **Latency budget**: 50–120 ms RTT target; **server tick** 10–20 Hz for MMO gameplay.
- **Throughput**: Aim ≤ 20–40 kbps per active player (post interest‑management).
- **Scalability**: Multi‑core usage and horizontal scale; sharded world design by default.
- **Anti‑cheat**: Authoritative server; deterministic sim where possible.

---

## 2) Client Engine

**Chosen**: **Godot 4.4**

- Strong 2D pipeline, open source, extensible.
- Use **GDExtension** for custom netcode (binary protocol) and client prediction.
- Snapshot + delta compression; client‑side interpolation; prediction + reconciliation for movement.

---

## 3) Player Capacity & Sharding Model

- **Per‑process cap**: 1–3k CCU per world/zone server.
- **Sharded world**: Seamless transfers between zones/instances keep the world unified.
- **Cluster capacity**: 10k CCU distributed across zones.
- **Bandwidth**: 10k players × 20 kbps ≈ **200 Mbps** egress; handled by splitting across shards.
- **CPU model**: Single‑threaded simulation per zone + multi‑threaded IO; one process per core.

---

## 4) Server Architecture

**High-level modules**

- **Gateway/Proxy**: Session routing, auth, ddos shield.
- **Login/Auth**: OAuth2/OIDC compatible.
- **World Directory**: Tracks shards/zones and assigns players.
- **Zone/Instance Servers**: Authoritative sim, ECS, AOI, tick loop, snapshot/delta.
- **Chat/Presence**: Pub/sub channels with Redis backing.
- **Inventory/Economy**: Transactional, validated server‑side.
- **Data Services**: Profile, Items, Progression.
- **Telemetry/Analytics**: Events, KPIs, fraud detection.

**Data backbone**

- **MSSQL** (primary persistence, since it matches current work).
- **Redis** (session state, hot AOI indices).
- **Kafka/NATS** (optional future events/streams).
- **Blob storage** for snapshots/archives.

**Deployment**

- Containers + Kubernetes; HPA scaling; Blue/Green deploys.
- Observability: Prometheus, Grafana, Loki, Tempo.

---

## 5) Networking Stack

**Chosen**: **C++17/20 + Boost.Asio**

- Mature, performant, integrates with Godot via GDExtension.
- Design: per‑core IO threads, single‑threaded zone sims, lock‑free queues between IO and sim.
- **Transport**: Prefer **QUIC** (UDP+TLS, congestion control, multiplexing). TCP fallback with tuned framing.

---

## 6) Simulation & ECS

- **ECS**: Server‑first ECS (C++ flecs or entt).
- **Tick loop**: 50–100 ms fixed steps (10–20 Hz).
- **Interest management**: Grid/quadtree + relevance masks; cap updates per client per tick.
- **Compression**: Snapshot + delta (bit‑packing, varints, dictionaries).

---

## 7) Persistence & Consistency

- **Model**: Write‑behind with periodic snapshots.
- **Critical ops**: trades/purchases are transactional.
- **Schema**: Items/Appearance/Abilities tables (aligned with MSSQL design).
- **Caching**: Redis with TTL + version keys.

---

## 8) Anti‑Cheat & Security

- Server authoritative for all state.
- Verify cooldowns/actions server‑side.
- Replay protection and packet signing.
- Heuristics for impossible movement or actions.

---

## 9) Capacity Planning & Hardware

- **Per zone process**: 1–3k CCU.
- **CPU**: Pin processes to physical cores.
- **Memory**: 2–4 GB per 1k CCU.
- **Networking**: 10–25 Gbps NICs for cluster nodes.

---

## 10) Concrete Recommendation (Initial Stack)

- **Client**: Godot 4.4 + GDExtension netcode module (C++).
- **Server**: **C++ + Boost.Asio** with Flecs/entt ECS, QUIC via msquic/quiche.
- **Chat/Presence**: Redis pub/sub initially (expandable later).
- **Persistence**: **MSSQL** primary, Redis caching.
- **Infra**: Docker + k8s, Prometheus/Grafana stack.

---

## 11) Milestones

**Phase 0 — Hello Cluster (2–4 weeks)**

- Gateway + single zone server echoing movement.
- Godot client connects and receives snapshots.
- Redis session store; MSSQL profile storage.

**Phase 1 — AOI & Combat (4–8 weeks)**

- Spatial grid AOI; interest‑culled updates.
- Authoritative abilities/cooldowns.

**Phase 2 — Sharding (4–6 weeks)**

- Multiple zone processes.
- Directory service & seamless transfer.
- Cross‑zone chat.

**Phase 3 — Persistence & Economy (6–10 weeks)**

- Inventory, trade, anti‑dupe.
- Daily snapshots.

**Phase 4 — Hardening & Scale Tests (ongoing)**

- Bot load tests to 1–3k CCU per zone.
- Profiling, back‑pressure, soak tests.

---

## 12) Next Actions

1. Stand up skeleton services: gateway, auth, single zone (C++ Asio).
2. Build Godot GDExtension client for login + snapshots.
3. Add AOI grid + snapshot/delta.
4. Implement headless bots for 500 CCU load testing.
5. Expand to multiple zones and verify seamless transfers.

---

*This doc is living. We’ll iterate as we lock choices and discover constraints.*

---

## Phase 0 — Baseline Connectivity & Accounts (detailed)

> Goal: Prove end‑to‑end login → spawn → move → persist location using Godot 4.4 client and C++ Boost.Asio server with MSSQL. Keep art/world minimal.

### 0.1 Client: Minimal World & Movement

**Deliverables**

- Godot scene: `Main(Node2D)`, `Camera2D`, `Player(Node2D -> Sprite2D)`, simple input map (WASD), optional tiny TileMap.
- Placeholder 64×64 sprite.
- Debug overlay (RTT, snapshot seq, server tick).

**Acceptance**: Client moves locally; can run with prediction off/on.

---

### 0.2 Client: Login UI & Protocol

**Deliverables**

- Godot **Login/Register** screen with fields: Username, Password, Player Name.
- Protocol messages (binary):
  - `C→S Register{username, password, player_name, client_version}`
  - `C→S Login{username, password, client_version}`
  - `S→C AuthOk{session_token, player_id, map_id}` | `AuthFail{reason}`

**Notes**

- Passwords are sent over an encrypted channel once TLS/QUIC is enabled. For localhost bring‑up, allow plaintext **only for dev**, then enable TLS quickly.
- Player Name is separate from Username (login identifier). Username uniqueness enforced at DB; player name uniqueness configurable.

**Acceptance**: Register + login flows work against server stubs.

---

### 0.3 Database: Minimal Schema (MSSQL)

**Tables**

- **dbo.PlayerAccount** — login identity + password hash
- **dbo.Player** — character (name, XP, currency)
- **dbo.PlayerLocation** — last known location (authoritative)

**Security**

- Store **only salted password hashes** (recommend **Argon2id**). Do hashing in the **server**, not in SQL; store the PHC‑formatted hash string.
- Username storage is **standard practice**; enforce uniqueness; minimize PII.

**Field descriptions**

**dbo.PlayerAccount**

| Field        | Type                  | Description                                  | Notes                                                  |
| ------------ | --------------------- | -------------------------------------------- | ------------------------------------------------------ |
| AccountId    | UNIQUEIDENTIFIER (PK) | Internal surrogate key for the account.      | Default NEWSEQUENTIALID(); never exposed to client UI. |
| Username     | NVARCHAR(32)          | Login identifier chosen by user.             | Unique, case‑insensitive compare recommended.          |
| PasswordHash | NVARCHAR(200)         | PHC‑formatted Argon2id hash of the password. | No plaintext; includes parameters and salt.            |
| PasswordAlgo | NVARCHAR(16)          | Which algorithm produced `PasswordHash`.     | Default 'argon2id'; enables future migrations.         |
| CreatedAt    | DATETIME2(3)          | When the account was created (UTC).          |                                                        |
| LastLoginAt  | DATETIME2(3) NULL     | Last successful login timestamp (UTC).       | Updated on auth success.                               |
| IsBanned     | BIT                   | If set, login is refused.                    | Reason stored elsewhere (audit log) later.             |

**dbo.Player**

| Field      | Type                  | Description                               | Notes / FK                                           |
| ---------- | --------------------- | ----------------------------------------- | ---------------------------------------------------- |
| PlayerId   | UNIQUEIDENTIFIER (PK) | Internal surrogate key for the character. | Default NEWSEQUENTIALID().                           |
| AccountId  | UNIQUEIDENTIFIER (FK) | Owner account.                            | FK → `dbo.PlayerAccount(AccountId)`; cascade delete. |
| Name       | NVARCHAR(32)          | Public display name of the character.     | Unique; profanity check in app layer.                |
| Experience | INT                   | XP total for progression.                 | Future: move curves to data tables.                  |
| Money      | INT                   | In‑game currency balance.                 | Use server‑side transactions for updates.            |
| CreatedAt  | DATETIME2(3)          | When the character was created (UTC).     |                                                      |

**dbo.PlayerLocation**

| Field      | Type                      | Description                              | Notes / FK                                    |
| ---------- | ------------------------- | ---------------------------------------- | --------------------------------------------- |
| PlayerId   | UNIQUEIDENTIFIER (PK, FK) | Which player this location belongs to.   | PK and FK → `dbo.Player(PlayerId)`; 1:1 row.  |
| ZoneId     | INT                       | Current zone/shard identifier.           | Default 1; maps to zone registry.             |
| PosX       | INT                       | X position in fixed‑point (×100).        | Authoritative server units; client converts.  |
| PosY       | INT                       | Y position in fixed‑point (×100).        | Same scale as PosX.                           |
| Facing     | TINYINT                   | Heading/dir (0–255 or enum for 8‑way).   | TBD encoding; doc in protocol spec.           |
| UpdatedAt  | DATETIME2(3)              | Last time server updated this row (UTC). | Write‑behind every few seconds and on logout. |
| RowVersion | ROWVERSION                | Optimistic concurrency token.            | For race‑free updates.                        |

**DDL (starter)**

```sql
CREATE TABLE dbo.PlayerAccount (
  AccountId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
  Username NVARCHAR(32) NOT NULL,
  PasswordHash NVARCHAR(200) NOT NULL, -- e.g., PHC format: $argon2id$v=19$m=...$...
  PasswordAlgo NVARCHAR(16) NOT NULL DEFAULT 'argon2id',
  CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  LastLoginAt DATETIME2(3) NULL,
  IsBanned BIT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX UX_PlayerAccount_Username ON dbo.PlayerAccount(Username);

CREATE TABLE dbo.Player (
  PlayerId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
  AccountId UNIQUEIDENTIFIER NOT NULL,
  Name NVARCHAR(32) NOT NULL,
  Experience INT NOT NULL DEFAULT 0,
  Money INT NOT NULL DEFAULT 0,
  CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Player_Account FOREIGN KEY (AccountId)
    REFERENCES dbo.PlayerAccount(AccountId) ON DELETE CASCADE
);
CREATE UNIQUE INDEX UX_Player_Name ON dbo.Player(Name);
CREATE INDEX IX_Player_AccountId ON dbo.Player(AccountId);

CREATE TABLE dbo.PlayerLocation (
  PlayerId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
  ZoneId INT NOT NULL DEFAULT 1,
  PosX INT NOT NULL,  -- fixed‑point scaled by 100
  PosY INT NOT NULL,  -- fixed‑point scaled by 100
  Facing TINYINT NOT NULL DEFAULT 0,
  UpdatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  RowVersion ROWVERSION,
  CONSTRAINT FK_PlayerLocation_Player FOREIGN KEY (PlayerId)
    REFERENCES dbo.Player(PlayerId) ON DELETE CASCADE
);
CREATE INDEX IX_PlayerLocation_UpdatedAt ON dbo.PlayerLocation(UpdatedAt);
```

**FK map (Phase 0)**

- `FK_Player_Account`: `dbo.Player(AccountId)` → `dbo.PlayerAccount(AccountId)` (CASCADE DELETE)
- `FK_PlayerLocation_Player`: `dbo.PlayerLocation(PlayerId)` → `dbo.Player(PlayerId)` (CASCADE DELETE)

**Optional: attach descriptions as Extended Properties**

```sql
-- Table descriptions
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Login identities and password hashes (Argon2id).',
  @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Playable characters linked to accounts.',
  @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Authoritative last known location for each player.',
  @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation';

-- Column descriptions (PlayerAccount)
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Account primary key (GUID).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'AccountId';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Login identifier (unique).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'Username';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'PHC‑formatted Argon2id password hash (includes salt and params).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'PasswordHash';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Password algorithm identifier (e.g., argon2id).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'PasswordAlgo';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'UTC creation timestamp.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'CreatedAt';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'UTC last successful login.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'LastLoginAt';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Flag to deny login.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerAccount', @level2type=N'COLUMN', @level2name=N'IsBanned';

-- Column descriptions (Player)
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Character primary key (GUID).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player', @level2type=N'COLUMN', @level2name=N'PlayerId';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Owner account id.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player', @level2type=N'COLUMN', @level2name=N'AccountId';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Public display name (unique).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player', @level2type=N'COLUMN', @level2name=N'Name';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Experience points total.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player', @level2type=N'COLUMN', @level2name=N'Experience';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Currency balance.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player', @level2type=N'COLUMN', @level2name=N'Money';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'UTC creation timestamp.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'Player', @level2type=N'COLUMN', @level2name=N'CreatedAt';

-- Column descriptions (PlayerLocation)
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Player id (also PK).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'PlayerId';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Current zone/shard identifier.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'ZoneId';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'X coordinate (fixed‑point ×100).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'PosX';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Y coordinate (fixed‑point ×100).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'PosY';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Heading or direction (encoding TBD).', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'Facing';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'UTC timestamp of last update.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'UpdatedAt';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Optimistic concurrency token.', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'PlayerLocation', @level2type=N'COLUMN', @level2name=N'RowVersion';
```

### 0.4 Server: Boost.Asio Game Server (MVP)

**Deliverables**

- TCP (then QUIC/TLS later) listener; message framing; session manager.
- Handlers: `Register`, `Login`, `Input`, `RequestSnapshot`.
- 20 Hz tick loop; on `Login` → load (or create) Player & PlayerLocation; spawn at last location.
- On movement inputs, update authoritative position; persist **throttled** (e.g., every 3–5 seconds or on logout).
- `Snapshot{player_id, seq, [entities...]}` to the client.

**Acceptance**: Two clients can log in, move, see each other; server persists/loads location.

---

### 0.5 Load Test & Metrics (Baseline)

**Deliverables**

- Headless bot client (CLI) that logs in and sends randomized movement.
- Target: **50–100 concurrent** on a dev machine; record CPU/tick time, bandwidth, and snapshot size.

**Acceptance**: Stable 20 Hz tick with ≤ 2 ms average tick time and no drops at target bot count.

---

### 0.6 Observability & Hygiene

**Deliverables**

- Structured logs (JSON) with connection IDs and tick metrics.
- Config file (.toml/.yaml): DB connection string, listen port, tick rate.
- Basic error handling & back‑pressure (disconnect clients that exceed rate limits).

**Acceptance**: Logs show per‑tick metrics; configs are externalized; server handles malformed packets gracefully.

