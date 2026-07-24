# TRACMS Training Approval Audit Plan

Date: July 24, 2026
Status: In progress

## Goal

Add a real approval history for training workflow transitions so the training details page can show who created, submitted, reviewed, and published a training record.

## Scope

- create an append-only `training_approvals` table
- record the initial training creation event
- record each workflow transition event
- expose approval history on the training details page

## Data To Capture

- training activity
- acting user
- acting role
- workflow action
- previous status
- new status
- event timestamp

## Implementation Rule

The audit trail must be written by the backend during the same transaction as the training record change. The UI should only display real events already stored in the database.

## Non-Goals

- no editable approval comments yet
- no rejection or rollback workflow yet
- no generic global audit log yet
