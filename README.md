# Tap Buddy – dbt + PostgreSQL Analytics Pipeline

An analytics pipeline that models student engagement data for the Tap Buddy learning platform. Raw CSV data is loaded into PostgreSQL using Python (pandas + SQLAlchemy), then transformed through a **bronze → silver → gold** layer architecture using [dbt](https://www.getdbt.com/).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Setup Guide](#setup-guide)
5. [Running the Pipeline](#running-the-pipeline)
6. [Data Model](#data-model)
7. [Notes on Testing](#notes-on-testing)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
CSV files (data/)
      │
      ▼
 main.py  ──── pandas + SQLAlchemy ────▶  PostgreSQL (public schema)
                                                │
                                                ▼
                                         dbt transforms
                                          ├── bronze   (tables – raw copies from source)
                                          ├── silver   (views  – cleaned & enriched)
                                          └── gold     (tables – business-level aggregates)
```

---

## Prerequisites

Make sure you have the following installed **before** starting:

| Tool | Version | Install Link |
|------|---------|-------------|
| **Python** | 3.12+ | [python.org](https://www.python.org/downloads/) |
| **PostgreSQL** | 14+ | [postgresql.org](https://www.postgresql.org/download/) |
| **pgAdmin 4** (optional, for visual DB management) | Latest | Bundled with PostgreSQL or [pgadmin.org](https://www.pgadmin.org/download/) |
| **uv** (recommended Python package manager) | Latest | `pip install uv` or [docs.astral.sh/uv](https://docs.astral.sh/uv/) |
| **Git** | Latest | [git-scm.com](https://git-scm.com/) |

> **Tip:** If you don't want to use `uv`, you can use plain `pip` with a virtual environment instead — see the alternative steps below.

---

## Project Structure

```
tap_buddy_pg_dbt-main/
│
├── data/                          # Raw CSV source files
│   ├── crm_students.csv
│   ├── bq_video_events.csv
│   ├── bq_messages.csv
│   └── bq_assessment_events.csv
│
├── main.py                        # Python script to load CSVs → PostgreSQL
├── pyproject.toml                 # Python project config & dependencies
├── requirements.txt               # Pinned pip dependencies (alternative to uv)
├── .python-version                # Python 3.12
├── .env                           # ⚠️ YOU CREATE THIS — DB credentials (git-ignored)
│
└── tap_buddy_pg_dbt/              # dbt project root
    ├── dbt_project.yml            # dbt project configuration
    ├── profiles.yml               # ⚠️ YOU CREATE THIS — dbt connection profile (git-ignored)
    ├── models/
    │   ├── source/sources.yml     # Source definitions (public schema tables)
    │   ├── bronze/                # Raw source mirrors
    │   ├── silver/                # Cleaned & enriched views
    │   └── gold/                  # Business aggregates
    ├── macros/
    │   └── generate_schema.sql    # Custom schema routing macro
    ├── seeds/
    ├── snapshots/
    ├── tests/
    └── analyses/
```

---

## Setup Guide

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/tap_buddy_pg_dbt.git
cd tap_buddy_pg_dbt-main
```

### 2. Create the PostgreSQL database

Open **pgAdmin** (or `psql`) and create a new database:

```sql
CREATE DATABASE tap_buddy;
```

Make sure you know the **username**, **password**, and **host** for your PostgreSQL server. The defaults are typically `postgres` / `your_password` / `localhost`.

### 3. Create the `.env` file

In the **project root** (`tap_buddy_pg_dbt-main/`), create a file called `.env`:

```dotenv
user=postgres
password=your_postgres_password
host=localhost
dbname=tap_buddy
```

Replace the values with your actual PostgreSQL credentials.

> **Important:** This file is git-ignored and will **not** be committed. Every collaborator must create their own.

### 4. Create `profiles.yml` for dbt

Inside the **dbt project folder** (`tap_buddy_pg_dbt-main/tap_buddy_pg_dbt/`), create a file called `profiles.yml`:

```yaml
tap_buddy_pg_dbt:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: postgres
      password: "your_postgres_password"
      port: 5432
      dbname: tap_buddy
      schema: public
      threads: 4
```

Replace `user`, `password`, and `host` to match your local PostgreSQL setup. The `schema: public` value is where the raw source tables live; dbt will create `bronze`, `silver`, and `gold` schemas automatically via the custom `generate_schema` macro.

> **Important:** This file is also git-ignored. Do **not** commit it with real credentials.

### 5. Install Python dependencies

**Option A — using `uv` (recommended):**

```bash
uv sync
```

This reads `pyproject.toml`, creates a `.venv`, and installs everything automatically.

**Option B — using `pip`:**

```bash
python -m venv .venv

# Activate the virtual environment
# macOS / Linux:
source .venv/bin/activate
# Windows:
.venv\Scripts\activate

pip install -r requirements.txt
pip install dbt-core dbt-postgres pandas python-dotenv sqlalchemy psycopg2-binary
```

### 6. Verify dbt installation

```bash
cd tap_buddy_pg_dbt
dbt --version
```

You should see `dbt-core` 1.11+ and `dbt-postgres` 1.10+ in the output.

---

## Running the Pipeline

### Step 1 — Load CSV data into PostgreSQL

From the **project root** (`tap_buddy_pg_dbt-main/`):

```bash
# If using uv:
uv run python main.py

# If using pip + venv (make sure venv is activated):
python main.py
```

This reads every `.csv` in `data/`, and creates (or replaces) a table in the `public` schema of your `tap_buddy` database with the same name as the file. After running you should see these four tables in pgAdmin under `tap_buddy > Schemas > public > Tables`:

- `crm_students`
- `bq_video_events`
- `bq_messages`
- `bq_assessment_events`

### Step 2 — Run dbt

Navigate into the dbt project folder and run:

```bash
cd tap_buddy_pg_dbt

# Check your connection is working
dbt debug

# Run all models
dbt run
```

If `dbt debug` shows **All checks passed!**, you're good to go.

After `dbt run` completes, your database will have these schemas and objects:

| Schema | Model | Materialized As |
|--------|-------|-----------------|
| `bronze` | `bronze_crm_students` | table |
| `bronze` | `bronze_bq_video_events` | table |
| `bronze` | `bronze_bq_messages` | table |
| `bronze` | `bronze_bq_assessment_events` | table |
| `silver` | `silver_video_events` | view |
| `silver` | `silver_assessment_events` | view |
| `silver` | `silver_activity_spine` | view |
| `silver` | `silver_activity_windows` | view |
| `silver` | `silver_activity_message_signals` | view |
| `silver` | `silver_activity_video_signals` | view |
| `silver` | `silver_activity_assessment_signals` | view |
| `gold` | `gold_activity_engagement` | table |
| `gold` | `gold_activity_funnel` | table |
| `gold` | `gold_cumulative_engagement` | table |

---

## Data Model

### Source Tables (loaded by `main.py`)

- **`crm_students`** — Student roster with school, grade, city, and demographic info.
- **`bq_video_events`** — Video watch events (started, progress %, completed) per student and activity.
- **`bq_messages`** — Inbound/outbound messages between the platform and students per activity.
- **`bq_assessment_events`** — Quiz and project assessment events (started, completed, scored).

### Layer Descriptions

**Bronze** — 1:1 copies of source tables. Acts as a stable reference layer so downstream models are decoupled from the raw source.

**Silver** — Cleaning, deduplication, and feature extraction:

- `silver_activity_spine` — unique (student, activity) combinations across all sources.
- `silver_activity_message_signals` — per-student/activity message engagement flags (reached, responded, etc.).
- `silver_activity_video_signals` — max video progress and completion flags.
- `silver_activity_assessment_signals` — quiz and project completion flags with timestamps.
- `silver_activity_windows` — time-windowed activity anchors.
- `silver_video_events` / `silver_assessment_events` — cleaned event-level views.

**Gold** — Business-ready aggregates:

- `gold_activity_engagement` — one row per (student, activity) with all engagement signals joined together.
- `gold_activity_funnel` — per-activity conversion funnel (reached → video → quiz → project).
- `gold_cumulative_engagement` — per-student summary of completed activities (filtered to grade 7).

---

## Notes on Testing

This project was built on **dummy/synthetic data** under a time constraint, so dbt tests have not been added yet. In a production environment, you would want to add:

- **Source freshness checks** — add `loaded_at_field` in `sources.yml`.
- **Schema tests** — `not_null`, `unique`, and `accepted_values` on key columns like `student_id`, `activity_id`, and `event_type`.
- **Relationship tests** — ensure foreign keys (e.g., `student_id` in event tables) reference valid rows in `crm_students`.
- **Custom data tests** — e.g., `progress_percent BETWEEN 0 AND 100`, `score <= max_score`.

To add tests, define them in a `schema.yml` alongside your models or write SQL test files in the `tests/` folder. Run them with:

```bash
dbt test
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `dbt debug` fails on connection | Double-check `profiles.yml` credentials and that PostgreSQL is running. |
| `main.py` throws `OperationalError` | Verify `.env` values and that the `tap_buddy` database exists. |
| Password with special characters fails | `main.py` already uses `urllib.parse.quote_plus` — just make sure the `.env` value is the raw password (no manual URL encoding). |
| `ModuleNotFoundError: No module named 'dbt'` | Make sure `dbt-core` and `dbt-postgres` are installed and your virtual environment is activated. |
| Schemas not created | Run `dbt run` — dbt creates `bronze`, `silver`, and `gold` schemas automatically on first run via the custom `generate_schema` macro. |
| `data/old/` folder | Contains earlier versions of the CSV files — safe to ignore. Only the CSVs in `data/` (top level) are used. |