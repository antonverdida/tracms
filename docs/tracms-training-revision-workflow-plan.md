# TRACMS Training Revision Workflow Plan

## Goal

Add a real return-for-revision workflow for training approvals so managers can send a training record back for correction with an auditable reason.

## Best Supported Scope

- allow division or regional reviewers to return approval-stage trainings to `draft`
- require a revision note
- store the note in the training approval audit trail
- expose the return action directly on the training details page

## Workflow Rule

- `pending_division_approval -> draft`
- `pending_region_approval -> draft`

The return action does not delete history. It creates a new audit entry that explains why the record was sent back.

## Non-Goals

- no separate rejected terminal training status yet
- no multi-step reviewer comment threads yet
- no file attachments on approval notes yet
