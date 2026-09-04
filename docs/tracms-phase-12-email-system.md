# TRACMS Phase 12 Email System

## Purpose

Add transactional email flows for participant and staff notifications.

## Notification Checklist

- [ ] registration confirmation
- [ ] training reminder
- [ ] certificate notification

## Recommended Stack

- `Swoosh`
- application mailer module
- background job processing for retries and bulk sends

## Suggested Email Events

- registration submitted
- registration approved or rejected
- upcoming training reminder
- attendance or evaluation follow-up
- certificate released

## Delivery Guidance

- render clear plain-text and HTML email variants
- queue non-blocking sends in jobs
- log delivery attempts for operational troubleshooting

## Phase Exit Criteria

Phase 12 is complete when:

- the core user journeys send the right emails
- failures can be retried safely
- email copy and timing are approved by stakeholders
