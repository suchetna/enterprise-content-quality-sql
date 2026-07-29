/*
Enterprise Content Quality & Taxonomy Analytics
Database Schema

Purpose:
Model a global enterprise content ecosystem for analysing content quality,
metadata completeness, taxonomy consistency, distribution reliability,
issue resolution, and client engagement.

Database compatibility:
SQLite
*/

PRAGMA foreign_keys = ON;


/* =========================================================
   1. CONTENT OWNERS
   Stores the teams and individuals responsible for content.
   ========================================================= */

CREATE TABLE content_owners (
    owner_id INTEGER PRIMARY KEY,
    owner_name TEXT NOT NULL,
    owner_team TEXT NOT NULL,
    owner_region TEXT NOT NULL
        CHECK (owner_region IN (
            'EMEA',
            'North America',
            'Global'
        )),
    owner_email TEXT UNIQUE,
    active_status INTEGER NOT NULL DEFAULT 1
        CHECK (active_status IN (0, 1))
);


/* =========================================================
   2. TAXONOMY
   Stores approved controlled-vocabulary values.
   ========================================================= */

CREATE TABLE taxonomy (
    taxonomy_id INTEGER PRIMARY KEY,
    taxonomy_type TEXT NOT NULL
        CHECK (taxonomy_type IN (
            'Region',
            'Campaign',
            'Programme',
            'Product',
            'Asset Class',
            'Audience',
            'Content Type',
            'Channel'
        )),
    taxonomy_value TEXT NOT NULL,
    parent_value TEXT,
    approved_status INTEGER NOT NULL DEFAULT 1
        CHECK (approved_status IN (0, 1)),
    effective_date DATE,
    retirement_date DATE,
    UNIQUE (taxonomy_type, taxonomy_value)
);


/* =========================================================
   3. CONTENT ASSETS
   Stores enterprise content and core metadata.
   ========================================================= */

CREATE TABLE content_assets (
    asset_id INTEGER PRIMARY KEY,
    asset_title TEXT NOT NULL,
    content_type TEXT,
    region TEXT,
    campaign TEXT,
    programme TEXT,
    product_name TEXT,
    asset_class TEXT,
    audience TEXT,
    primary_channel TEXT,

    owner_id INTEGER,

    creation_date DATE NOT NULL,
    publication_date DATE,
    review_date DATE,
    expiry_date DATE,
    last_modified_date DATE,

    content_status TEXT NOT NULL
        CHECK (content_status IN (
            'Draft',
            'In Review',
            'Approved',
            'Published',
            'Archived',
            'Expired'
        )),

    language_code TEXT DEFAULT 'en',
    accessibility_status TEXT
        CHECK (accessibility_status IN (
            'Compliant',
            'Partially Compliant',
            'Non-Compliant',
            'Not Assessed'
        )),

    metadata_complete INTEGER NOT NULL DEFAULT 0
        CHECK (metadata_complete IN (0, 1)),

    source_url TEXT,
    duplicate_group_id INTEGER,
    word_count INTEGER
        CHECK (word_count IS NULL OR word_count >= 0),

    FOREIGN KEY (owner_id)
        REFERENCES content_owners(owner_id)
);


/* =========================================================
   4. CONTENT ISSUES
   Stores content-quality, taxonomy, and governance issues.
   ========================================================= */

CREATE TABLE content_issues (
    issue_id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,

    issue_type TEXT NOT NULL
        CHECK (issue_type IN (
            'Missing Metadata',
            'Invalid Taxonomy',
            'Duplicate Content',
            'Expired Content',
            'Accessibility',
            'Broken Link',
            'Incorrect Ownership',
            'Content Accuracy',
            'Distribution Failure',
            'Other'
        )),

    issue_description TEXT NOT NULL,

    severity TEXT NOT NULL
        CHECK (severity IN (
            'Low',
            'Medium',
            'High',
            'Critical'
        )),

    issue_status TEXT NOT NULL
        CHECK (issue_status IN (
            'Open',
            'In Progress',
            'Escalated',
            'Resolved',
            'Closed'
        )),

    identified_date DATE NOT NULL,
    assigned_owner_id INTEGER,
    resolution_date DATE,
    root_cause TEXT,
    corrective_action TEXT,
    recurrence_flag INTEGER NOT NULL DEFAULT 0
        CHECK (recurrence_flag IN (0, 1)),

    FOREIGN KEY (asset_id)
        REFERENCES content_assets(asset_id),

    FOREIGN KEY (assigned_owner_id)
        REFERENCES content_owners(owner_id)
);


/* =========================================================
   5. DISTRIBUTION EVENTS
   Tracks content delivery to channels and systems.
   ========================================================= */

CREATE TABLE distribution_events (
    distribution_id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,

    distribution_date DATE NOT NULL,

    region TEXT NOT NULL
        CHECK (region IN (
            'EMEA',
            'North America',
            'Global'
        )),

    channel TEXT NOT NULL,

    destination_system TEXT,

    distribution_status TEXT NOT NULL
        CHECK (distribution_status IN (
            'Queued',
            'Delivered',
            'Failed',
            'Partially Delivered'
        )),

    error_code TEXT,
    error_description TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0
        CHECK (retry_count >= 0),

    delivery_time_seconds INTEGER
        CHECK (
            delivery_time_seconds IS NULL
            OR delivery_time_seconds >= 0
        ),

    FOREIGN KEY (asset_id)
        REFERENCES content_assets(asset_id)
);


/* =========================================================
   6. ENGAGEMENT METRICS
   Stores content usage and client-engagement data.
   ========================================================= */

CREATE TABLE engagement_metrics (
    metric_id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,

    reporting_month DATE NOT NULL,

    region TEXT NOT NULL
        CHECK (region IN (
            'EMEA',
            'North America',
            'Global'
        )),

    channel TEXT NOT NULL,

    impressions INTEGER NOT NULL DEFAULT 0
        CHECK (impressions >= 0),

    views INTEGER NOT NULL DEFAULT 0
        CHECK (views >= 0),

    unique_users INTEGER NOT NULL DEFAULT 0
        CHECK (unique_users >= 0),

    downloads INTEGER NOT NULL DEFAULT 0
        CHECK (downloads >= 0),

    clicks INTEGER NOT NULL DEFAULT 0
        CHECK (clicks >= 0),

    conversions INTEGER NOT NULL DEFAULT 0
        CHECK (conversions >= 0),

    average_time_seconds REAL NOT NULL DEFAULT 0
        CHECK (average_time_seconds >= 0),

    bounce_rate REAL
        CHECK (
            bounce_rate IS NULL
            OR bounce_rate BETWEEN 0 AND 100
        ),

    FOREIGN KEY (asset_id)
        REFERENCES content_assets(asset_id),

    UNIQUE (
        asset_id,
        reporting_month,
        region,
        channel
    )
);


/* =========================================================
   INDEXES
   Improve performance for common content-steward queries.
   ========================================================= */

CREATE INDEX idx_content_assets_owner
    ON content_assets(owner_id);

CREATE INDEX idx_content_assets_status
    ON content_assets(content_status);

CREATE INDEX idx_content_assets_region
    ON content_assets(region);

CREATE INDEX idx_content_assets_expiry
    ON content_assets(expiry_date);

CREATE INDEX idx_content_assets_taxonomy
    ON content_assets(
        content_type,
        campaign,
        product_name,
        asset_class
    );

CREATE INDEX idx_content_issues_asset
    ON content_issues(asset_id);

CREATE INDEX idx_content_issues_status
    ON content_issues(issue_status);

CREATE INDEX idx_content_issues_severity
    ON content_issues(severity);

CREATE INDEX idx_distribution_asset
    ON distribution_events(asset_id);

CREATE INDEX idx_distribution_status
    ON distribution_events(distribution_status);

CREATE INDEX idx_engagement_asset
    ON engagement_metrics(asset_id);

CREATE INDEX idx_engagement_month
    ON engagement_metrics(reporting_month);
