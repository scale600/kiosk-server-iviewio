# Product Requirements Document (PRD)

## Kiosk Server on GCP Free Tier (Blazor Server + MudBlazor)

**Version:** 1.0  
**Project:** kiosk-server-iviewio  
**Domain:** kiosk1.iviewio.com  
**Last Updated:** 2026-02-03

---

## 1. Overview

### 1.1 Purpose

Deploy and operate **mhwlng/kiosk-server** (Blazor Server, .NET 8) on **Google Cloud Platform Free Tier**, with **MudBlazor** theming and **swap/zram** for stable operation within 1 GB RAM.

### 1.2 Goals

- Run kiosk-server 24/7 within GCP free tier (e2-micro, 1 GB RAM).
- Provide a modern, consistent UI via MudBlazor theme.
- Ensure reliability under memory pressure using zram/swap.
- Expose setup and kiosk control at **kiosk1.iviewio.com**.

### 1.3 Out of Scope

- Multi-region or HA deployment.
- Paid GCP resources beyond free tier.
- Native mobile apps; web-only.

---

## 2. Stakeholders & Users

| Role         | Description                                                |
| ------------ | ---------------------------------------------------------- |
| **Operator** | Configures kiosk URLs, reboot/shutdown via setup UI.       |
| **End user** | Uses kiosk display (browser full-screen) on touch devices. |
| **Admin**    | GCP project owner; VM, DNS, SSL, monitoring.               |

---

## 3. User Stories & Requirements

### 3.1 Deployment & Infrastructure

| ID  | User Story                                            | Acceptance Criteria                               | Priority |
| --- | ----------------------------------------------------- | ------------------------------------------------- | -------- |
| D1  | As an admin, I deploy kiosk-server on a single GCP VM | VM is e2-micro, in free tier, in chosen region    | Must     |
| D2  | As an admin, I use only free-tier-eligible resources  | No cost for compute within 720 hrs/month e2-micro | Must     |
| D3  | As an admin, I optimize memory with swap/zram         | zram configured; OOM rare under normal load       | Must     |

### 3.2 Application

| ID  | User Story                                      | Acceptance Criteria                                      | Priority |
| --- | ----------------------------------------------- | -------------------------------------------------------- | -------- |
| A1  | As an operator, I open setup via browser        | Setup at https://kiosk1.iviewio.com/setup (or /)         | Must     |
| A2  | As an operator, I set one or more kiosk URLs    | URLs saved; single URL auto-redirects at startup         | Must     |
| A3  | As an operator, I reboot or shutdown the device | Reboot/shutdown work when triggered from setup           | Should   |
| A4  | As a user, I see a consistent, themed UI        | MudBlazor theme applied (colors, typography, components) | Must     |

### 3.3 Security & Access

| ID  | User Story                                             | Acceptance Criteria                                     | Priority |
| --- | ------------------------------------------------------ | ------------------------------------------------------- | -------- |
| S1  | As an admin, I serve over HTTPS                        | TLS on kiosk1.iviewio.com (e.g. Let’s Encrypt)          | Must     |
| S2  | As an operator, I (optionally) protect setup with auth | Future: user/password for /setup (per upstream roadmap) | Could    |

### 3.4 Operations

| ID  | User Story                                          | Acceptance Criteria                                 | Priority |
| --- | --------------------------------------------------- | --------------------------------------------------- | -------- |
| O1  | As an admin, I keep the app running after reboot    | systemd (or equivalent) starts kiosk-server on boot | Must     |
| O2  | As an admin, I deploy updates with minimal downtime | Documented deploy/restart procedure                 | Should   |
| O3  | As an admin, I monitor basic health                 | Option: simple health check or log inspection       | Could    |

---

## 4. Functional Requirements (Summary)

- **FR1.** Host mhwlng/kiosk-server (Blazor Server, .NET 8) on a Linux VM.
- **FR2.** Apply MudBlazor theme (default or custom) across setup and kiosk UI.
- **FR3.** Setup page: configure kiosk URL(s), reboot, shutdown.
- **FR4.** Single kiosk URL: redirect to that URL at startup.
- **FR5.** Public access via https://kiosk1.iviewio.com (DNS + TLS).
- **FR6.** Swap/zram configured so the app runs within 1 GB RAM without frequent OOM.

---

## 5. Non-Functional Requirements

| ID   | NFR                 | Target                                                |
| ---- | ------------------- | ----------------------------------------------------- |
| NFR1 | **Availability**    | Best effort 24/7 within free tier; single VM, no SLA. |
| NFR2 | **Memory**          | Stay within 1 GB RAM; use zram/swap to avoid OOM.     |
| NFR3 | **Cost**            | Zero ongoing cost for compute (free tier only).       |
| NFR4 | **Security**        | HTTPS only; optional setup auth later.                |
| NFR5 | **Maintainability** | Documented setup, theme change, and deploy steps.     |

---

## 6. Constraints

- **GCP Free Tier:** e2-micro only (e.g. 2 vCPU burst, 1 GB RAM), 720 hrs/month.
- **RAM:** 1 GB total; Blazor Server + Kestrel need careful tuning and zram/swap.
- **Upstream:** mhwlng/kiosk-server as base; MudBlazor added in our fork/codebase.
- **Domain:** kiosk1.iviewio.com (existing in info.txt).

---

## 7. Success Criteria

- Kiosk-server is reachable at https://kiosk1.iviewio.com with MudBlazor theme.
- Setup page allows configuring kiosk URL(s) and system actions.
- VM runs within GCP free tier with zram/swap enabled; no recurring charges.
- Single-command or scripted deploy/restart for updates.

---

## 8. References

- [mhwlng/kiosk-server](https://github.com/mhwlng/kiosk-server) — Blazor Server, .NET 8, touch kiosk + remote control.
- [MudBlazor](https://mudblazor.com/) — Blazor component library and theming.
- [GCP Free Tier](https://cloud.google.com/free) — e2-micro, 720 hrs/month.
- Project info: `info.txt` (project ID, domain, account).
