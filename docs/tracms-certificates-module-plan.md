# TRACMS Certificates Module Plan

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

### Manager Certificates

Place manager certificate pages inside the existing `live_session :training_management` block because:

- they require authenticated manager access
- they belong with training operations
- they need the existing training-manager authorization and `@current_scope`

### Participant Certificates

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

The next certificate improvement should focus on controlled document output now that certificate access is already live.

Implement:

- a dedicated print-friendly certificate document page for participant and manager use
- export of the certificate document as a downloadable HTML file instead of premature PDF generation
- automatic acknowledgement of access when a participant opens either the certificate view or the print/export document route
- consistent action labels such as `Print certificate` and `Export document`
- document routes that stay inside authenticated participant and manager access boundaries

Do not implement yet:

- PDF file generation
- QR verification
- external email delivery
- digital signature workflow
