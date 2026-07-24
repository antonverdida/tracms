# TRACMS Google Workspace Integration Plan

Date: July 24, 2026
Status: In progress

## Goal

Refocus TRACMS so Google Workspace handles participant-facing data collection while TRACMS remains the official training governance, validation, monitoring, completion, and certification system.

## Product Direction

The target architecture is:

`TRACMS training record -> Google registration/attendance forms -> Google response sheets -> TRACMS sync and review -> completion validation -> certificate processing`

## Current Phase

This release now implements the integration control model plus direct Google Form generation for the core external workflow:

- a dedicated Google Workspace Integration page exists per training
- managers can generate official registration and attendance Google Forms directly from TRACMS
- generated form URLs are stored on the training record and edit access is shared to the current manager account
- response-sheet configuration and latest sync status are visible in one module
- registration intake remains synchronized into the external review queue
- attendance intake remains synchronized into open attendance sessions

## Why This Phase First

- it matches the existing TRACMS data model and approval workflow
- it gives coordinators one official integration control center now
- it avoids promising direct Google Forms automation before the Forms API flow is fully wired and verified
- it keeps the rollout safe for DepEd Region IX while reducing scattered setup across pages

## Next Phase

Planned after this foundation:

- automatic response-sheet linkage and guided range setup
- richer standardized registration and attendance templates
- optional Google Drive folder automation for certificate delivery artifacts
- eventual evaluation form generation for workflows that should remain outside TRACMS
