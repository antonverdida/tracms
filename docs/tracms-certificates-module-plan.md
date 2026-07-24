# TRACMS Certificates Module Plan

Date: July 24, 2026
Status: Version 1 implementation in progress

## Goal

Implement the first real certificate record flow so TRACMS can move from completion readiness into actual issued certificate data.

## Why This Is Next

- The dashboard and reports already reference certificate outcomes conceptually.
- The training record now includes certificate-related metadata such as `certificate_type`.
- Completion logic already tells us which approved registrations are actually ready for certification.

## Version 1 Scope

Build a minimal but real certificate module with:

- a certificate record table linked to registrations
- manager issuance from completion-ready participant records
- manager review of issued certificates per training
- participant access to their issued certificates

## Data Model

Each certificate record should store:

- registration reference
- certificate number
- certificate title or type
- issued date
- delivery status fields that are useful now

## Route Placement

### Manager certificates

Place manager certificate pages inside the existing `live_session :training_management` block because:

- they require authenticated manager access
- they belong with training operations
- they need the existing training-manager authorization and `@current_scope`

### Participant certificates

Place participant certificate pages inside the existing authenticated user session because:

- they require login
- they should work for a participant without training-manager privileges

## Design Direction

- use the shared portal components
- keep the manager page operational and table-oriented
- keep the participant page simple and record-oriented
- do not overbuild PDF generation or email delivery yet

## Version 1 Limitations

- no PDF file generation yet
- no QR verification yet
- no external email sending yet
- status tracking should stay simple until the document pipeline exists

## Expected Result

TRACMS will have real certificate records that can be issued for completed participants and viewed later by both managers and participants.

## Implementation Notes

- certificate records use a dedicated `certificate_records` table linked one-to-one with registrations
- manager issuance is driven from the completion-ready roster instead of manual free-form encoding
- participant access is exposed through a dedicated `My Certificates` page in the authenticated dashboard
- training operations now include a direct certificates page beside attendance and completion
- PDF generation, QR verification, and email delivery stay out of scope for this version

## Next Implementation Slice

The next certificate improvement should focus on certificate access instead of export complexity.

Implement:

- a participant certificate view page that presents the issued record in a formal certificate-style layout
- automatic acknowledgement of access when the participant opens the certificate view for the first time
- a manager certificate preview page for operational verification
- consistent action labels such as `View certificate` instead of a raw status-update button
- dashboard and registration-page visibility for issued certificate records

Do not implement yet:

- PDF file generation
- QR verification
- external email delivery
- digital signature workflow
