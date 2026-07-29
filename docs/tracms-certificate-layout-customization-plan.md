# TRACMS Certificate Layout Customization Plan

## Goal

Allow authorized training managers to customize certificate layout settings in a clean and practical way, with:

- admin-managed default certificate layout settings in `Account Settings`
- per-training certificate layout overrides inside the training workflow
- certificate rendering that automatically uses the training override first, then falls back to the saved default layout

## Best Supported MVP

Implement a structured certificate layout system instead of free-form HTML editing.

The first supported customization scope should include:

- certificate header title
- certificate subtitle
- body introduction text
- completion statement text
- signature label
- issuing office label
- accent color preset
- layout style preset
- optional certificate image or reference file upload

This keeps the feature safe, professional, and easy to manage for a government portal.

## Why This Is Better Than Raw Template Editing

- avoids broken certificate layouts
- keeps print/export output reliable
- preserves one professional certificate design system
- allows real customization without exposing risky arbitrary markup

## Data Model Direction

### System-Wide Default Settings

Store the official certificate layout defaults in a dedicated TRACMS settings record.

Recommended table:

- `certificate_layout_settings`

Purpose:

- gives the portal one official certificate layout baseline
- keeps participant, manager, print, and export views consistent
- avoids tying the official government layout to one admin account

### Training-Level Override Settings

Store training-specific certificate layout overrides directly on `training_activities`.

Recommended storage:

- nullable certificate layout fields on `training_activities`

Purpose:

- allows each training to customize the certificate anytime
- keeps certificate behavior tied to the training record

## Rendering Rule

Certificate output should resolve settings in this order:

1. training-level certificate layout overrides
2. saved TRACMS default certificate layout settings
3. built-in TRACMS default certificate layout

## Settings Page Scope

Add a new admin-visible section in `Account Settings`:

- `Certificate Layout Defaults`

Supported controls:

- layout style preset
- accent color preset
- certificate title
- certificate subtitle
- completion statement
- signature label

UI rules:

- simple form layout
- one live preview card
- one save button
- no advanced markup editing

## Training Page Scope

Add a new manager section on the training details page:

- `Certificate Layout`

Supported behavior:

- show whether the training uses default layout or custom override
- allow updating the training-specific certificate layout values
- allow reset back to default
- show a small preview using the training’s effective settings

## Certificate Component Scope

Update `certificate_sheet` so it accepts effective layout settings and applies:

- dynamic title
- dynamic subtitle
- dynamic completion wording
- dynamic signature label
- preset-based visual treatment

## Non-Goals For This MVP

- arbitrary drag-and-drop certificate builder
- image upload for custom backgrounds
- raw HTML or CSS editing by users
- multiple saved named templates
- per-certificate manual design editing

## Expected Result

After this MVP:

- admins can define a polished default certificate layout in Settings
- managers can customize the certificate layout for each training
- participant and manager certificate views both reflect the effective training layout
- print/export remains stable and professional
