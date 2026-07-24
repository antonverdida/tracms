# TRACMS Training Record Enhancement Plan

Date: July 24, 2026
Status: In progress

## Goal

Strengthen the training record so it captures the core government-style information needed by TRACMS for:

- registration
- attendance monitoring
- evaluation
- reporting
- future certificate generation

## Best Supported Scope

Implement the most valuable record enhancements that fit the current TRACMS architecture without overreaching into certificate generation yet.

## Fields to Add

- training type
- training objectives
- total training hours
- venue address
- target participants
- participant qualification
- registration opening date
- attendance monitoring method
- certificate type

## Why This Scope

- These fields are directly useful to the current training form and detail page.
- They improve data quality for attendance, completion, and reports immediately.
- They lay clean groundwork for later certificate and history modules.
- They avoid prematurely building complex speaker schedules, templates, or document-generation flows before the core record is ready.

## UI Direction

- keep the form simple and professional
- group the form into clear sections
- use select inputs for controlled government-style fields where appropriate
- make the training details page read more like an official training record

## Implementation Rule

Add the new fields to the schema, migration, fixtures, tests, training form, and training details page together so the record stays internally consistent.
