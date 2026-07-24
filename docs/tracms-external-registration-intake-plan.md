# TRACMS External Registration Intake Plan

Date: July 24, 2026
Status: In progress

## Goal

Implement the next accurate phase after external registration links:

`external form response -> TRACMS intake queue -> manager review -> TRACMS registration record`

## Why This Phase

The current hybrid workflow already supports official external form links for participant-facing registration and attendance.

The next missing piece is the manager-side reconciliation workflow:

- coordinators need a place to encode or stage external responses inside TRACMS
- TRACMS needs to show whether the participant already has a matching account
- only validated records should become real TRACMS registrations

## Phase 2 Scope

Implement an internal intake queue for external registration submissions:

- manager-encoded external registration staging records
- automatic account matching by email when possible
- queue status for `pending review`, `needs account`, `imported`, and `rejected`
- manager import action that converts a staged record into a real TRACMS registration
- manager registrations page updates for external workflow trainings

## Rules

- keep the `registrations` table as the authoritative participant registration record
- do not create anonymous registrations without a real TRACMS user account
- treat the intake queue as a staging area, not the final participant record
- keep the workflow inside the existing authenticated training management routes because it requires manager permissions and scope-based access control

## Deferred Work

This phase does not yet include:

- direct Google Sheets API synchronization
- bulk CSV import
- attachment import from external forms
- automatic creation of participant accounts
- background synchronization logs
