# Sentinel — Sistema Automatizado de Escaneo de Vulnerabilidades

**Trabajo Integrador Final — UTN FRM**  
Tecnicatura en Ciberseguridad — Bits & Bytes  
Marín, Agustín · Muñoz, Carlos · Raía, Sofía

---

## Descripción

Sentinel es un sistema de escaneo automatizado de vulnerabilidades para redes de laboratorio. Integra Nmap, OpenVAS y n8n en un pipeline orquestado que descubre hosts, escanea puertos y ejecuta análisis de vulnerabilidades, almacenando los resultados en PostgreSQL y visualizándolos en un dashboard web en tiempo real.

El sistema puede dispararse automáticamente por schedule, manualmente desde n8n, o bajo demanda desde el dashboard con seguimiento de progreso en tiempo real.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     Ubuntu Server 24.04                      │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │ Dashboard│    │   n8n    │    │  Greenbone / OpenVAS │  │
│  │  :5002   │◄──►│  :5678   │◄──►│        :9392         │  │
│  └──────────┘    └──────────┘    └──────────────────────┘  │
│       │               │                                     │
│       │          ┌────┴─────┐    ┌──────────┐              │
│       │          │ nmap-api │    │  gvm-api │              │
│       │          │  :5000   │    │  :5001   │              │
│       │          └──────────┘    └──────────┘              │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────┐                                              │
│  │PostgreSQL│                                              │
│  │  :5432   │                                              │
│  └──────────┘                                              │
└─────────────────────────────────────────────────────────────┘
```

### Servicios

| Servicio | Puerto | Descripción |
|---|---|---|
| Dashboard | 5002 | Interfaz web de visualización y control |
| n8n | 5678 | Motor de automatización del workflow |
| nmap-api | 5000 | Microservicio REST wrapper de Nmap |
| gvm-api | 5001 | Microservicio REST wrapper de OpenVAS |
| PostgreSQL | 5432 | Base de datos de resultados |
| Greenbone GSA | 9392 | Interfaz web de OpenVAS |

---

## Requisitos

- Ubuntu Server 24.04
- Docker 24+
- Docker Compose v2+
- 8 GB RAM mínimo (16 GB recomendado para OpenVAS)
- 50 GB de disco libre
- La VM debe tener una interfaz de red en la red `192.168.100.0/24`

---

## Instalación

### 1 — Clonar el repositorio

```bash
git clone https://github.com/Carlosfmr95/Bits-Bytes_Sentinel
cd Bits-Bytes_Sentinel
```

### 2 — Ejecutar el script de configuración

```bash
chmod +x setup.sh
./setup.sh
```

El script realiza automáticamente lo siguiente:
- Detecta la IP de la VM en la red `192.168.100.0/24`
- Genera una clave de encriptación aleatoria para n8n
- Solicita las credenciales (PostgreSQL, GVM/OpenVAS, n8n)
- Escribe el archivo `.env` completo y listo para usar

Credenciales que el script va a pedir:

| Credencial | Descripción |
|---|---|
| Usuario/Contraseña PostgreSQL | Acceso a la base de datos de resultados |
| Usuario/Contraseña GVM | Acceso a OpenVAS (usuario `admin` recomendado) |
| Usuario/Contraseña n8n | Acceso al panel de automatización |

### 3 — Levantar el stack

```bash
docker compose up -d
```

> **Primera vez:** tarda entre 10 y 30 minutos porque OpenVAS descarga sus bases de datos de vulnerabilidades. Las tablas de PostgreSQL se crean automáticamente — no hace falta ejecutar ningún SQL manualmente.

Para ver el progreso en tiempo real:

```bash
docker compose logs -f
```

### 4 — Verificar que todos los servicios están corriendo

```bash
docker compose ps
```

Los servicios deben mostrar `running` o `healthy`. Los contenedores de datos de OpenVAS (`scap-data`, `vulnerability-tests`, etc.) pueden tardar varios minutos en pasar a `healthy` la primera vez.

Si `scap-data` muestra error, reiniciarlo una vez que los otros feeds estén listos:

```bash
docker compose restart scap-data
```

### 5 — Configurar n8n

#### 5.1 — Crear cuenta de administrador

Abrir en el browser:

```
http://192.168.100.5:5678
```

> Reemplazar `192.168.100.5` con la IP real de la VM que mostró el `setup.sh`.

La primera vez n8n muestra un formulario para crear la cuenta de administrador. Completarlo con los datos que se deseen (no necesitan coincidir con los del `.env`).

#### 5.2 — Importar el workflow

1. En el panel izquierdo → **Workflows**
2. Botón **Add workflow** → **Import from file**
3. Seleccionar el archivo `n8n/Workflow TIF -Bits&Bytes.json`

#### 5.3 — Crear la credencial de PostgreSQL

Los nodos que escriben en la base de datos necesitan una credencial configurada. Hacerlo una sola vez:

1. Menú superior derecho (ícono de usuario) → **Settings** → **Credentials**
2. Botón **Add credential** → buscar y seleccionar **PostgreSQL**
3. Completar con los siguientes valores:

| Campo | Valor |
|---|---|
| **Name** | `PostgresSQL Scans` (exactamente así) |
| **Host** | `postgres-scans` |
| **Database** | `security_scans` |
| **User** | valor de `POSTGRES_USER` en el `.env` |
| **Password** | valor de `POSTGRES_PASSWORD` en el `.env` |
| **Port** | `5432` |
| **SSL** | desactivado |

4. Hacer click en **Save**

#### 5.4 — Asignar la credencial a los nodos PostgreSQL

En el editor del workflow, dos nodos necesitan la credencial:

**Nodo "Guardar en PostgreSQL":**
- Hacer click sobre el nodo
- En el panel derecho → *Credential to connect with* → seleccionar `PostgresSQL Scans`

**Nodo "Guardar Historial":**
- Hacer click sobre el nodo
- En el panel derecho → *Credential to connect with* → seleccionar `PostgresSQL Scans`

#### 5.5 — Activar el workflow

En la esquina superior derecha del editor del workflow:
1. Hacer click en **Save**
2. Activar el toggle **Inactive → Active** (o botón **Publish**)

El webhook `/webhook/start-scan` queda activo y el dashboard puede disparar escaneos.

---

## Uso

### Dashboard

Acceder a `http://192.168.100.5:5002`

Desde el dashboard se puede:
- Ver todos los resultados de escaneos con filtros por host, severidad, herramienta y fecha
- Buscar vulnerabilidades por nombre o CVE
- Exportar resultados a CSV
- Ver el historial de escaneos
- Lanzar nuevos escaneos con seguimiento de progreso en tiempo real

### Lanzar un escaneo manualmente

Hacer click en **▶ NUEVO ESCANEO** en el header del dashboard, ingresar la IP objetivo (`192.168.100.x`) y seleccionar el tipo de escaneo (`quick` o `full`).

### Escaneo automático

El workflow está configurado para ejecutarse automáticamente todos los días a las **2:00 AM**. Se puede modificar en n8n → nodo **Schedule Trigger**.

---

## Reinstalar desde cero

Para borrar todo y empezar de nuevo (contenedores, volúmenes y datos):

```bash
# Detener y eliminar contenedores + todos los volúmenes (incluye datos de OpenVAS y PostgreSQL)
docker compose down -v

# Eliminar las imágenes propias para forzar rebuild
docker rmi sentinel-dashboard sentinel-nmap-api sentinel-gvm-api 2>/dev/null || true
```

Luego volver desde el paso 2 de la instalación:

```bash
./setup.sh
docker compose up -d
```

> **Atención:** `docker compose down -v` borra todos los datos incluyendo las bases de vulnerabilidades de OpenVAS. La próxima vez que se levante el stack va a volver a descargarlas (10-30 minutos).

### Reinstalar solo la aplicación (conservar feeds de OpenVAS)

Si se quiere resetear solo la base de datos y n8n sin volver a descargar los feeds de OpenVAS:

```bash
docker compose down
docker volume rm sentinel_n8n_data_vol sentinel_postgres_scans_data
docker compose up -d
```

Después volver a ejecutar el **Paso 5** para reimportar el workflow y reconfigurar las credenciales en n8n.

---

## Estructura del proyecto

```
sentinel/
├── .env.example          # Plantilla de variables de entorno
├── .gitignore
├── README.md
├── setup.sh              # Script de configuración inicial (genera el .env)
├── docker-compose.yml
├── postgres/
│   └── init.sql          # Tablas creadas automáticamente al iniciar PostgreSQL
├── dashboard/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py            # Backend Flask (API REST + scan trigger)
│   └── templates/
│       └── index.html    # Frontend (CSS + JS embebidos)
├── gvm-api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py            # Wrapper REST para OpenVAS via GMP socket
├── nmap-api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py            # Wrapper REST para Nmap
└── n8n/
    └── Workflow TIF -Bits&Bytes.json   # Workflow de automatización exportado
```

---

## Red de laboratorio

El sistema escanea únicamente la red `192.168.100.0/24`. Cualquier IP fuera de ese rango es rechazada por los microservicios.

---

## Tecnologías

- **Python 3.11** / Flask — backend de microservicios
- **PostgreSQL 16** — almacenamiento de resultados
- **n8n 1.88.0** — orquestación del workflow de escaneo
- **Nmap** — descubrimiento de hosts y escaneo de puertos
- **OpenVAS / Greenbone Community Edition** — análisis de vulnerabilidades
- **Docker / Docker Compose** — contenedores y orquestación
