-- Tablas principales del sistema Sentinel.
-- Este archivo se ejecuta automáticamente al crear el volumen de PostgreSQL por primera vez.

CREATE TABLE IF NOT EXISTS vulnerability_scans (
    id               SERIAL PRIMARY KEY,
    scan_id          VARCHAR(100),
    fecha            TIMESTAMP,
    host_ip          VARCHAR(50),
    herramienta      VARCHAR(50),
    severidad_label  VARCHAR(20),
    puerto           VARCHAR(20),
    servicio         VARCHAR(100),
    version          VARCHAR(200),
    nombre_vuln      TEXT,
    cves             TEXT,
    severidad_cvss   NUMERIC(4,1)
);

CREATE TABLE IF NOT EXISTS scan_history (
    id              SERIAL PRIMARY KEY,
    scan_id         VARCHAR(100),
    fecha           TIMESTAMP,
    total_hosts     INTEGER DEFAULT 0,
    nmap_high       INTEGER DEFAULT 0,
    nmap_medium     INTEGER DEFAULT 0,
    nmap_low        INTEGER DEFAULT 0,
    openvas_high    INTEGER DEFAULT 0,
    openvas_medium  INTEGER DEFAULT 0,
    openvas_low     INTEGER DEFAULT 0
);

-- Seguimiento persistente de escaneos activos.
-- Reemplaza el dict en memoria del dashboard para sobrevivir reinicios del contenedor.
CREATE TABLE IF NOT EXISTS active_scans (
    scan_id     VARCHAR(100) PRIMARY KEY,
    target      VARCHAR(50),
    scan_type   VARCHAR(20),
    status      VARCHAR(20),
    progress    INTEGER DEFAULT 0,
    logs        TEXT DEFAULT '',
    created_at  TIMESTAMP DEFAULT NOW()
);
