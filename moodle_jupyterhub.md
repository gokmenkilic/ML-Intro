# Moodle + JupyterHub Integration
## Progress Report — 4-6 March 2026

> **Platform:** Azimuth &nbsp;|&nbsp; **Cluster:** ml-intro (Kubernetes) &nbsp;|&nbsp;

---

## Table of Contents

1. [Objective](#1-objective)
2. [Architecture Overview](#2-Architecture-overview)

---

## 1. Objective

> **The Goal:** Allow users to open and run Jupyter notebooks **directly inside Moodle** 

Currently students must visit JupyterHub separately and log in independently from Moodle. The target experience is:

```
Student clicks activity in Moodle  →  Notebook opens embedded  →  Already logged in
```


---

## 2. Architecture Overview

Azimuth, Keycloak and Moodle must work together. Understanding who controls what explains the current situation of the architecture.

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

*Report prepared: March 6, 2026 &nbsp;*

