# TRACMS Participant Journey Plan

Date: July 24, 2026
Status: In progress

## Goal

Make the participant journey feel like a real DepEd employee workflow:

`discover training -> open participant training details -> submit registration -> track approval -> complete evaluation -> receive certificate`

## Best Supported Scope

Implement the strongest improvements that fit the current data model and the practical DepEd operating environment:

- a participant training details page
- a profile-backed registration request panel for TRACMS-native registration
- an external collection mode for trainings that use official Google Forms or other approved DepEd forms
- clearer catalog-to-details navigation
- clearer links from `My Registrations` back to the participant training record

## Implementation Rules

- place participant training details inside the authenticated participant routes because they require login and personal registration context
- do not invent fields such as contact number, district, school, or uploads that are not yet stored by TRACMS
- use the current account profile as the participant identity source
- keep the registration request real by supporting the existing `special_requirements` note field
- keep TRACMS as the source of truth for training records, approval, completion, certificates, and reports
- do not present automatic Google synchronization until there is a real import service and auditable sync workflow

## Hybrid Collection Model

Phase 1 should support two collection paths on the same training record:

- `Internal TRACMS registration` for trainings that should be handled directly inside the portal
- `External registration and attendance forms` for trainings managed through official coordinator-issued forms

When external links are configured:

- coordinators manage the form links from the training record
- participants see an official external registration call to action instead of the TRACMS submit form
- TRACMS still shows the training details, expectations, and later participation status once records exist inside the system

## Deferred Work

The following can be added in a later phase once there is a proper data integration design:

- automatic Google Sheet import
- synchronization logs and validation queues
- attachment import for endorsements or supporting documents
- attendance ingestion from external form responses

## Non-Goals

- no QR participant scanner yet
- no requirement upload workflow yet
- no public anonymous training browsing yet
- no separate professional-record module yet
