# Moodle + JupyterHub Integration
## Progress Report — March 2026

> **Platform:** Azimuth / COSMA Durham &nbsp;|&nbsp; **Cluster:** ml-intro (Kubernetes) &nbsp;|&nbsp; **Status:** ⏳ 1 External Blocker Remaining

---

## Table of Contents

1. [Objective](#1-objective)
2. [Infrastructure Overview](#2-infrastructure-overview)
3. [Access Levels](#3-access-levels)
4. [SSO Authentication Flow](#4-sso-authentication-flow)
5. [Student Experience — End Goal](#5-student-experience--end-goal)
6. [What Was Achieved](#6-what-was-achieved)
7. [Attempts & Dead Ends](#7-attempts--dead-ends)
8. [The Single Remaining Blocker](#8-the-single-remaining-blocker)
9. [Next Steps & Roadmap](#9-next-steps--roadmap)
10. [Full Status Board](#10-full-status-board)

---

## 1. Objective

> **The Goal:** Allow students to open and run Jupyter notebooks **directly inside Moodle** — using a single university login, with no separate passwords or manual steps.

Currently students must visit JupyterHub separately and log in independently from Moodle. The target experience is:

```
Student clicks activity in Moodle  →  Notebook opens embedded  →  Already logged in
```

No separate tab. No second password. One click.

---

## 2. Infrastructure Overview

Three systems must work together. Understanding who controls what explains the current situation.

```mermaid
graph TD
    subgraph COSMA["☁️ COSMA / Durham  —  External (Not Under Our Control)"]
        KC["🔐 Keycloak 26<br/>portal.azimuth.cosma.dur.ac.uk<br/>Realm: az-diractraining"]
        AZ["🌐 Azimuth Identity Provider<br/>OpenID Connect / OIDC<br/>University SSO"]
        KC <-->|"OIDC federation"| AZ
    end

    subgraph OURS["🖥️ Our Control"]
        ML["📓 JupyterHub<br/>Kubernetes: ml-intro<br/>Helm chart: jupyterhub-4.2.0"]
        MO["🎓 Moodle LMS<br/>training-academy.dirac.ac.uk<br/>Admin access ✅"]
    end

    subgraph STUDENT["👩‍💻 Student Browser"]
        BR["Course page → notebook activity<br/>Opens embedded iFrame"]
    end

    KC <-->|"OAuth2 / JWT tokens"| ML
    KC <-->|"OAuth2 login"| MO
    MO <-->|"iFrame embed"| BR
    ML <-->|"notebook served"| BR

    style COSMA fill:#fff8f0,stroke:#f5a623
    style OURS fill:#f0f5fc,stroke:#1a4f8a
    style STUDENT fill:#f0faf5,stroke:#1e7a4a
```

### Who Controls What

| System | Controller | Access Level |
|---|---|---|
| **Keycloak 26** | COSMA / Durham | ❌ No server access |
| **Azimuth Identity Provider** | COSMA / Durham | ❌ No server access |
| **JupyterHub (ml-intro)** | Us | ✅ Full kubectl access |
| **Moodle LMS** | Us | ✅ Full admin panel |
| **Kubernetes cluster** | Us | ✅ Full kubectl access |
| **Keycloak admin panel** | Us | ✅ Full admin (realm only) |

---

## 3. Access Levels

```mermaid
graph LR
    subgraph have["✅ What We Have"]
        A["Keycloak Admin Panel<br/>az-diractraining realm"]
        B["kubectl Access<br/>ml-intro cluster"]
        C["Moodle Admin Panel<br/>training-academy.dirac.ac.uk"]
        D["Azimuth Portal<br/>OpenStack project level"]
    end

    subgraph need["❌ What We Cannot Access"]
        E["COSMA Platform Cluster<br/>Keycloak server SSH"]
        F["Keycloak jupyterhub_config<br/>Environment variables"]
    end

    style have fill:#f0faf5,stroke:#1e7a4a
    style need fill:#fff8f0,stroke:#f5a623
```

---

## 4. SSO Authentication Flow

This is the complete chain that runs when a student clicks a notebook activity in Moodle.

```mermaid
sequenceDiagram
    actor S as 👩‍💻 Student
    participant M as 🎓 Moodle
    participant J as 📓 JupyterHub
    participant K as 🔐 Keycloak
    participant Az as 🌐 Azimuth SSO

    S->>M: Clicks Jupyter notebook activity
    M->>J: Redirects with session info
    J->>K: "Who is this user?" (OAuth2)
    K->>K: Sets AUTH_SESSION_ID cookie ⚠️
    Note over K: Keycloak 26 bug:<br/>Sets SameSite=Lax<br/>instead of SameSite=None
    K->>Az: Redirects to university SSO
    Az-->>K: Returns — but cookie is lost ❌
    Note over K,Az: Cross-origin redirect drops<br/>SameSite=Lax cookie
    K->>K: cookie_not_found error ❌

    Note over S,Az: ── After COSMA applies KC_PROXY_HEADERS fix ──

    K->>K: Sets SameSite=None ✅
    K->>Az: Redirects to university SSO
    S->>Az: Enters university credentials (once)
    Az->>K: Confirms identity
    K->>J: Issues access token ✅
    J->>S: Starts notebook server
    J-->>M: Notebook loads in iFrame ✅
    Note over S,M: Student sees notebook<br/>embedded in Moodle page
```

### Simplified Flow Diagram

```mermaid
flowchart LR
    A["🎓 Moodle\ntraining-academy"] -->|"activity click"| B
    B["🔐 Keycloak\naz-diractraining"] -->|"redirects to"| C
    C["⚠️ Azimuth SSO\ncookie drops here"] -->|"should return token"| D
    D["📓 JupyterHub\nml-intro cluster"] -->|"serves notebook"| E
    E["👩‍💻 iFrame\nin Moodle page"]

    style A fill:#f0faf5,stroke:#1e7a4a
    style B fill:#f0faf5,stroke:#1e7a4a
    style C fill:#fff8f0,stroke:#f5a623
    style D fill:#f0faf5,stroke:#1e7a4a
    style E fill:#f0f5fc,stroke:#1a4f8a
```

### Cookie Problem Explained Simply

```mermaid
flowchart TD
    A["Keycloak sets session cookie"] --> B{{"Keycloak 26\nbehind proxy?"}}
    B -->|"No KC_PROXY_HEADERS"| C["SameSite = Lax ❌"]
    B -->|"KC_PROXY_HEADERS=xforwarded ✅"| D["SameSite = None ✅"]
    C --> E["Cookie dropped during\ncross-origin redirect"]
    D --> F["Cookie survives\ncross-origin redirect"]
    E --> G["cookie_not_found ❌\nLogin fails"]
    F --> H["Login succeeds ✅\nNotebook opens"]

    style C fill:#fff0f0,stroke:#b82020
    style D fill:#f0faf5,stroke:#1e7a4a
    style G fill:#fff0f0,stroke:#b82020
    style H fill:#f0faf5,stroke:#1e7a4a
```

---

## 5. Student Experience — End Goal

```mermaid
journey
    title Student Journey — Target Experience
    section Before (Current)
        Open Moodle: 5: Student
        Find JupyterHub URL separately: 2: Student
        Log into JupyterHub manually: 2: Student
        Navigate to correct notebook: 3: Student
        Start working: 4: Student
    section After (Target)
        Open Moodle: 5: Student
        Click notebook activity: 5: Student
        Notebook opens embedded: 5: Student
        Start working immediately: 5: Student
```

---

## 6. What Was Achieved

### Summary

| | Count |
|---|---|
| ✅ Tasks completed | **5** |
| ⚠️ External blockers | **1** |
| ⬜ Next steps queued | **4** |

### Completed Work

#### ✅ 1. Root Cause Identified

Diagnosed the exact error causing login failure by inspecting Keycloak Events:

```
Event:              IDENTITY_PROVIDER_LOGIN_ERROR
identity_provider:  azimuth
error:              cookie_not_found
```

Traced to **Keycloak 26** changing `SameSite=None` → `SameSite=Lax` on session cookies when running behind a reverse proxy without the `KC_PROXY_HEADERS` configuration.

#### ✅ 2. Keycloak Clients Verified

Both required clients confirmed as already existing and working in the `az-diractraining` realm:

| Client | Status | Evidence |
|---|---|---|
| `moodle-lms` | ✅ Working | `LOGIN` events in Keycloak |
| `kubeapp-ml-intro.ml-intro-jupyterhub-azimuth` | ✅ Working | `CODE_TO_TOKEN` events confirmed |

#### ✅ 3. JupyterHub iFrame Header Applied

Using `kubectl` access to the ml-intro Kubernetes cluster, patched the JupyterHub configmap to allow Moodle to embed JupyterHub in an iFrame:

```python
# Added to jupyterhub_config.py in Kubernetes configmap
c.JupyterHub.tornado_settings = {
    "slow_spawn_timeout": 0,
    "headers": {
        "Content-Security-Policy": "frame-ancestors 'self' https://training-academy.dirac.ac.uk",
    },
}
```

Deployed with:
```bash
kubectl rollout restart deployment/hub -n ml-intro
# Result: deployment "hub" successfully rolled out ✅
```

#### ✅ 4. Keycloak Security Headers Verified

Confirmed `Realm Settings → Security Defenses → Headers` already correctly set:

```
X-Frame-Options:         ALLOW-FROM https://training-academy.dirac.ac.uk
Content-Security-Policy: frame-src 'self'; object-src 'none';
                         frame-ancestors 'self' https://training-academy.dirac.ac.uk
```

No changes needed on the Keycloak side for this.

#### ✅ 5. kubectl Cluster Access Established

Full programmatic access to ml-intro Kubernetes cluster confirmed:

```
NAME                            STATUS   ROLES           VERSION
ml-intro-control-plane-4ng86   Ready    control-plane   v1.34.4
ml-intro-control-plane-j2vrb   Ready    control-plane   v1.34.4
ml-intro-control-plane-pd7lj   Ready    control-plane   v1.34.4
ml-intro-ml-intro-xcwt5-49b8r  Ready    worker          v1.34.4
```

---

## 7. Attempts & Dead Ends

```mermaid
flowchart TD
    START["🔍 Investigating cookie_not_found"] --> A

    A["Attempt: Keycloak Client Policies"] --> A1["❌ Dead end\nClient policies control tokens only\nCannot modify HTTP headers"]

    START --> B
    B["Attempt: Find Keycloak in ml-intro cluster"] --> B1["❌ Empty result\nKeycloak is on COSMA platform\nnot in our cluster"]

    START --> C
    C["Attempt: Python patch script v1\n8-space indentation"] --> C1["❌ Block not found\nActual indentation was 4 spaces"]
    C1 --> C2["✅ Fixed in v2\nPatch applied successfully"]

    START --> D
    D["Attempt: Azimuth namespace access\nkubectl get pods -n azimuth-system"] --> D1["❌ Empty\nPlatform components completely\nseparate from tenant cluster"]

    START --> E
    E["Attempt: Stack Overflow fix #79192647"] --> E1["❌ Same root cause\nAll cookie_not_found fixes\nlead to KC_PROXY_HEADERS"]

    START --> F
    F["Attempt: OpenStack external IP\nFirewall rules"] --> F1["❌ Not relevant\nCookie issue is auth logic\nnot network routing"]

    style A1 fill:#fff0f0,stroke:#b82020
    style B1 fill:#fff0f0,stroke:#b82020
    style C1 fill:#fff0f0,stroke:#b82020
    style C2 fill:#f0faf5,stroke:#1e7a4a
    style D1 fill:#fff0f0,stroke:#b82020
    style E1 fill:#fff0f0,stroke:#b82020
    style F1 fill:#fff0f0,stroke:#b82020
```

---

## 8. The Single Remaining Blocker

> ⚠️ **Everything on our side is complete.** The only remaining blocker is one environment variable on COSMA's Keycloak server — a server we do not control.

### What Needs to Change

```mermaid
flowchart LR
    subgraph cosma["COSMA Keycloak Server"]
        K["Keycloak 26\nDeployment"]
        FIX["Add environment variable:\nKC_PROXY_HEADERS=xforwarded\nKC_HTTP_ENABLED=true\nKC_HOSTNAME_STRICT=false"]
    end

    ACTION["📧 Email cosma-support@dur.ac.uk\nTechnical request ready to send"] --> cosma
    cosma --> RESULT["✅ SameSite=None restored\n✅ Login works\n✅ Notebooks open in Moodle"]

    style cosma fill:#fff8f0,stroke:#f5a623
    style RESULT fill:#f0faf5,stroke:#1e7a4a
```

### The Fix in Detail

```bash
# One environment variable on COSMA's Keycloak Kubernetes deployment
KC_PROXY_HEADERS=xforwarded
KC_HTTP_ENABLED=true
KC_HOSTNAME_STRICT=false
```

This tells Keycloak to trust the `X-Forwarded-Proto: https` header from the Kubernetes ingress, which restores the correct `SameSite=None; Secure` cookie behaviour.

**Time to apply:** ~5 minutes
**Risk:** Very low — only affects cookie flag, not authentication logic
**Affects other users:** No

**Action:** Email `cosma-support@dur.ac.uk` — technical request already drafted and ready to send.

---

## 9. Next Steps & Roadmap

```mermaid
gantt
    title Integration Roadmap
    dateFormat  YYYY-MM-DD
    section Immediate
        Email COSMA support            :crit, active, a1, 2026-03-06, 1d
        Await COSMA response           :crit, a2, after a1, 3d
    section After COSMA Fix
        Verify full login flow         :b1, after a2, 1d
        Set up Moodle External Tool    :b2, after b1, 1d
        Student acceptance testing     :b3, after b2, 3d
    section Future (PowerEdge R6715)
        Server arrival & setup         :c1, 2026-04-01, 7d
        Self-hosted JupyterHub deploy  :c2, after c1, 5d
        moodle-mod_jupyter plugin      :c3, after c2, 3d
        Auto-grading with Otter-Grader :c4, after c3, 3d
```

### Step-by-Step Actions

```mermaid
flowchart TD
    N1["1️⃣ URGENT NOW\nEmail cosma-support@dur.ac.uk\nRequest KC_PROXY_HEADERS fix"] --> N2

    N2["2️⃣ AFTER COSMA RESPONDS\nVerify login in incognito browser\nCheck Keycloak Events for clean LOGIN"] --> N3

    N3["3️⃣ Set up Moodle External Tool\nAdd JupyterHub as activity\nLink to specific .ipynb notebooks"] --> N4

    N4["4️⃣ Student acceptance testing\nSmall group test\nConfirm across browsers & devices"] --> N5

    N5["5️⃣ FUTURE — PowerEdge R6715\nSelf-hosted JupyterHub\nmoodle-mod_jupyter plugin\nAuto-grading with Otter-Grader"]

    style N1 fill:#fff8f0,stroke:#f5a623,stroke-width:2px
    style N2 fill:#f0f5fc,stroke:#1a4f8a
    style N3 fill:#f0f5fc,stroke:#1a4f8a
    style N4 fill:#f0f5fc,stroke:#1a4f8a
    style N5 fill:#f8f8f8,stroke:#ccc
```

---

## 10. Full Status Board

```mermaid
flowchart LR
    subgraph done["✅ DONE"]
        D1["Root cause identified\ncookie_not_found = Keycloak 26 bug"]
        D2["Keycloak clients confirmed\nmoodle-lms + jupyterhub exist"]
        D3["JupyterHub CSP header applied\nframe-ancestors set & deployed"]
        D4["Keycloak CSP headers verified\ntraining-academy.dirac.ac.uk allowed"]
        D5["kubectl access established\nml-intro cluster, all 4 nodes healthy"]
    end

    subgraph waiting["⏳ WAITING"]
        W1["COSMA: KC_PROXY_HEADERS\nEmail ready to send"]
    end

    subgraph todo["⬜ NEXT"]
        T1["Verify full login flow"]
        T2["Moodle External Tool setup"]
        T3["Student testing"]
        T4["PowerEdge R6715 deployment"]
    end

    done --> waiting --> todo

    style done fill:#f0faf5,stroke:#1e7a4a
    style waiting fill:#fff8f0,stroke:#f5a623
    style todo fill:#f8f8f8,stroke:#ccc
```

---

## Appendix — Files Produced

| File | Purpose |
|---|---|
| `JupyterHub_Moodle_Guide.md` | General integration overview |
| `Jupyter_Notebooks_Inside_Moodle_Complete_Guide.md` | All 4 plugin options |
| `Moodle_Azimuth_JupyterHub_Integration_Guide.md` | Azimuth-specific guide |
| `Moodle_Azimuth_Simple_Access_Guide.md` | LTI External Tool setup |
| `Moodle_JupyterHub_Keycloak_Full_Integration.md` | Full Keycloak OIDC wiring |
| `Current_State_Integration_Plan.md` | Realistic plan for current access |
| `Keycloak26_SameSite_Cookie_Fix.md` | KC_PROXY_HEADERS fix guide |
| `Fix_cookie_not_found_Keycloak26.md` | Exact fix for confirmed error |
| `Apply_KC_PROXY_HEADERS_Fix.md` | kubectl step-by-step guide |
| `Kubernetes_Step_By_Step_Fix.md` | kubectl setup from scratch |
| `patch_jupyterhub_csp.py` | Python script — patched JupyterHub configmap |
| `Moodle_JupyterHub_Progress_Report.html` | Visual HTML report for PIs |
| `Progress_Report_March_2026.md` | Full technical progress report |

---

*Report prepared: March 6, 2026 &nbsp;|&nbsp; Realm: az-diractraining &nbsp;|&nbsp; Cluster: ml-intro &nbsp;|&nbsp; COSMA Durham*
